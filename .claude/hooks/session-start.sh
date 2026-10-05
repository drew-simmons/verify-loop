#!/usr/bin/env sh
# SessionStart hook: make sure the loop's three tools exist, fetch the base
# branch, and tell Claude what is available. Idempotent and never fatal: a
# session must start even when offline.
set -u

BIN="$HOME/.local/bin"
mkdir -p "$BIN"
export PATH="$BIN:$HOME/.cargo/bin:$PATH"
log() { echo "verify-loop: $*" >&2; }

if ! command -v poly-crap >/dev/null 2>&1; then
  log "installing poly-crap"
  curl --proto '=https' --tlsv1.2 -LsSf \
    https://github.com/drew-simmons/poly-crap/releases/latest/download/poly-crap-installer.sh \
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
  git clone -q --depth 1 https://github.com/drew-simmons/lawbook "$TMP/lawbook" >/dev/null 2>&1 \
    && (cd "$TMP/lawbook" \
        && corepack enable >/dev/null 2>&1 \
        && pnpm install --frozen-lockfile >/dev/null 2>&1 \
        && pnpm pack --pack-destination "$TMP" >/dev/null 2>&1 \
        && npm install --global "$TMP"/lawbook-*.tgz >/dev/null 2>&1) \
    || log "lawbook install failed; build it from https://github.com/drew-simmons/lawbook"
  rm -rf "$TMP"
fi

if ! command -v hunk >/dev/null 2>&1; then
  log "installing hunk"
  npm install --global hunkdiff >/dev/null 2>&1 || true
fi

git fetch -q origin main >/dev/null 2>&1 || true

# Later Bash calls in this session inherit PATH through CLAUDE_ENV_FILE.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$BIN:\$HOME/.cargo/bin:\$PATH\"" >>"$CLAUDE_ENV_FILE"
fi

version() { command -v "$1" >/dev/null 2>&1 && "$1" --version 2>/dev/null | head -n 1 | sed 's/^[^0-9]*//' || echo absent; }
echo "verify-loop: poly-crap $(version poly-crap), lawbook $(version lawbook), hunk $(version hunk), BASE=origin/main. Run /verify before committing."
