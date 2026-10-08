#!/usr/bin/env sh
# SessionStart hook: make sure the loop's three tools exist, fetch the base
# branch, and tell Claude what is available. Idempotent and never fatal: a
# session must start even when offline. HUNK=0 skips hunk (CI has no TUI).
# POLY_CRAP_VERSION and LAWBOOK_VERSION pin the installs; both default to latest.
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
  log "installing lawbook${LAWBOOK_VERSION:+ $LAWBOOK_VERSION}"
  npm install --global "lawbook@${LAWBOOK_VERSION:-latest}" >/dev/null 2>&1 \
    || log "lawbook install failed; run: npm install --global lawbook"
fi

if [ "${HUNK:-1}" != "0" ] && ! command -v hunk >/dev/null 2>&1; then
  log "installing hunk"
  npm install --global hunkdiff >/dev/null 2>&1 || true
fi

git fetch -q origin main >/dev/null 2>&1 || true

# Later Bash calls in this session inherit PATH through CLAUDE_ENV_FILE.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$BIN:\$HOME/.cargo/bin:\$PATH\"" >>"$CLAUDE_ENV_FILE"
fi

version() { command -v "$1" >/dev/null 2>&1 && "$1" --version 2>/dev/null | head -n 1 | sed 's/^[^0-9]*//' || echo absent; }
bedrock() {
  region=${AWS_REGION:-${AWS_DEFAULT_REGION:-}}
  if [ -z "$region" ]; then echo "off (set AWS_REGION and Bedrock credentials to judge the prose standards)"
  elif [ -n "${AWS_BEARER_TOKEN_BEDROCK:-}${AWS_ACCESS_KEY_ID:-}${AWS_PROFILE:-}" ] || [ -f "$HOME/.aws/credentials" ]; then echo "ready ($region)"
  else echo "region $region set but no credentials found"
  fi
}
echo "verify-loop: poly-crap $(version poly-crap), lawbook $(version lawbook), hunk $(version hunk), BASE=origin/main, bedrock $(bedrock). Run /verify before committing."
