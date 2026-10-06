#!/usr/bin/env sh
# SessionStart hook: make sure the loop's three tools exist, start the
# Bifrost gateway the prose standards go through when Bedrock credentials
# are present, fetch the base branch, and tell Claude what is available.
# Idempotent and never fatal: a session must start even when offline.
# HUNK=0 skips hunk (CI has no TUI); BIFROST=0 skips the gateway.
# POLY_CRAP_VERSION and LAWBOOK_REF pin the installs; both default to latest.
set -u

BIN="$HOME/.local/bin"
mkdir -p "$BIN"
export PATH="$BIN:$HOME/.cargo/bin:$PATH"
log() { echo "verify-loop: $*" >&2; }

if ! command -v poly-crap >/dev/null 2>&1; then
  log "installing poly-crap${POLY_CRAP_VERSION:+ $POLY_CRAP_VERSION}"
  RELEASE=${POLY_CRAP_VERSION:+download/v$POLY_CRAP_VERSION}
  curl --proto '=https' --tlsv1.2 -LsSf \
    "https://github.com/drew-simmons/poly-crap/releases/${RELEASE:-latest/download}/poly-crap-installer.sh" \
    | sh -s -- --yes >/dev/null 2>&1 || true
fi
if ! command -v poly-crap >/dev/null 2>&1 && command -v gh >/dev/null 2>&1; then
  log "installer unavailable; fetching the release asset with gh"
  TMP=$(mktemp -d)
  gh release download --repo drew-simmons/poly-crap --pattern '*x86_64-unknown-linux-gnu.tar.xz' --dir "$TMP" >/dev/null 2>&1 \
    && tar -xJf "$TMP"/*.tar.xz -C "$TMP" \
    && find "$TMP" -type f -name poly-crap -exec install -m 755 {} "$BIN/poly-crap" \;
  rm -rf "$TMP"
fi

if ! command -v lawbook >/dev/null 2>&1; then
  log "installing lawbook from source (it is not on npm)"
  TMP=$(mktemp -d)
  git clone -q --depth 1 --branch "${LAWBOOK_REF:-main}" https://github.com/drew-simmons/lawbook "$TMP/lawbook" >"$TMP/build.log" 2>&1 \
    && (cd "$TMP/lawbook" \
        && corepack enable \
        && pnpm install --frozen-lockfile \
        && pnpm pack --pack-destination "$TMP" \
        && npm install --global "$TMP"/lawbook-*.tgz) >>"$TMP/build.log" 2>&1 \
    || { log "lawbook install failed; build it from https://github.com/drew-simmons/lawbook"; tail -n 20 "$TMP/build.log" >&2; }
  rm -rf "$TMP"
fi

if [ "${HUNK:-1}" != "0" ] && ! command -v hunk >/dev/null 2>&1; then
  log "installing hunk"
  npm install --global hunkdiff >/dev/null 2>&1 || true
fi

# The prose standards are judged through a Bifrost gateway in front of
# Bedrock: lawbook speaks Chat Completions to it, and it holds the AWS
# credentials. Start one when credentials are present and none answers.
BIFROST_URL=${BIFROST_URL:-http://localhost:8080}
gateway_up() { curl -fsS -m 2 -o /dev/null "$BIFROST_URL/health" 2>/dev/null; }
aws_region() { echo "${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"; }
aws_credentials() {
  [ -n "${AWS_BEARER_TOKEN_BEDROCK:-}${AWS_ACCESS_KEY_ID:-}${AWS_PROFILE:-}" ] || [ -f "$HOME/.aws/credentials" ]
}
# The gateway's config: one Bedrock key on the default AWS credential chain,
# or the bearer token when one is set, and cache markers injected so the
# standard is read from Bedrock's prompt cache after the first file.
write_bifrost_config() {
  mkdir -p .bifrost
  if [ -n "${AWS_BEARER_TOKEN_BEDROCK:-}" ]; then
    key='"name": "bedrock-api-key", "value": "env.AWS_BEARER_TOKEN_BEDROCK",'
  else
    key='"name": "aws-credential-chain",'
  fi
  cat >.bifrost/config.json <<EOF
{
  "providers": {
    "bedrock": {
      "keys": [
        {
          $key
          "models": ["*"],
          "weight": 1.0,
          "bedrock_key_config": { "region": "$(aws_region)" }
        }
      ],
      "prompt_cache": { "auto_inject": true }
    }
  }
}
EOF
}
start_bifrost() {
  write_bifrost_config
  if command -v setsid >/dev/null 2>&1; then
    setsid npx -y @maximhq/bifrost -app-dir .bifrost -log-style json >.bifrost/bifrost.log 2>&1 </dev/null &
  else
    nohup npx -y @maximhq/bifrost -app-dir .bifrost -log-style json >.bifrost/bifrost.log 2>&1 </dev/null &
  fi
  tries=0
  until gateway_up || [ "$tries" -ge 120 ]; do tries=$((tries + 1)); sleep 0.5; done
}
if [ "${BIFROST:-1}" != "0" ] && [ -n "$(aws_region)" ] && aws_credentials && ! gateway_up; then
  log "starting a Bifrost gateway at $BIFROST_URL for the prose standards"
  start_bifrost
fi

git fetch -q origin main >/dev/null 2>&1 || true

# Later Bash calls in this session inherit PATH through CLAUDE_ENV_FILE.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$BIN:\$HOME/.cargo/bin:\$PATH\"" >>"$CLAUDE_ENV_FILE"
fi

version() { command -v "$1" >/dev/null 2>&1 && "$1" --version 2>/dev/null | head -n 1 | sed 's/^[^0-9]*//' || echo absent; }
bifrost() {
  if gateway_up; then echo "up ($BIFROST_URL${AWS_REGION:+, $AWS_REGION})"
  elif [ -z "$(aws_region)" ]; then echo "off (set AWS_REGION and Bedrock credentials to judge the prose standards)"
  elif ! aws_credentials; then echo "off (region $(aws_region) set but no credentials found)"
  else echo "down (credentials found but nothing answers at $BIFROST_URL; see .bifrost/bifrost.log)"
  fi
}
echo "verify-loop: poly-crap $(version poly-crap), lawbook $(version lawbook), hunk $(version hunk), BASE=origin/main, bifrost $(bifrost). Run /verify before committing."
