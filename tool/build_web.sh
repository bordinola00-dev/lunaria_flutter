#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL to the official Lunaria project URL}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY to the public anon/publishable key}"
: "${SPOTIFY_CLIENT_ID:?Set SPOTIFY_CLIENT_ID to the public Spotify client ID}"
: "${SPOTIFY_REDIRECT_URI:?Set SPOTIFY_REDIRECT_URI to the registered HTTPS /auth.html URL}"

flutter_command="${FLUTTER_BIN:-flutter}"
if ! command -v "$flutter_command" >/dev/null 2>&1; then
  if [[ -x "$HOME/flutter/bin/flutter" ]]; then
    flutter_command="$HOME/flutter/bin/flutter"
  else
    printf 'Flutter was not found. Add it to PATH or set FLUTTER_BIN.\n' >&2
    exit 1
  fi
fi

if [[ "$SUPABASE_URL" != "https://gtzzvklqnmndqfzgbmpd.supabase.co" ]]; then
  printf 'SUPABASE_URL must be the official Lunaria project URL.\n' >&2
  exit 1
fi

if [[ ! "$SPOTIFY_REDIRECT_URI" =~ ^https://[^/]+/auth\.html$ ]]; then
  printf 'SPOTIFY_REDIRECT_URI must be an HTTPS URL ending in /auth.html.\n' >&2
  exit 1
fi

created_env=false
if [[ ! -f .env ]]; then
  printf 'SUPABASE_URL=%s\nSUPABASE_ANON_KEY=%s\n' \
    "$SUPABASE_URL" "$SUPABASE_ANON_KEY" > .env
  created_env=true
fi

cleanup() {
  if [[ "$created_env" == true ]]; then
    rm -- .env
  fi
}
trap cleanup EXIT

"$flutter_command" build web --release --web-content-hash --base-href / --no-pub \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
  --dart-define="SPOTIFY_CLIENT_ID=$SPOTIFY_CLIENT_ID" \
  --dart-define="SPOTIFY_REDIRECT_URI=$SPOTIFY_REDIRECT_URI"

if [[ -d build/web/assets ]]; then
  find build/web/assets -maxdepth 1 -type f -name '.env*' -delete
fi

if [[ ! -f build/web/index.html || ! -f build/web/manifest.json ]]; then
  printf 'Flutter did not produce the expected web release files.\n' >&2
  exit 1
fi
