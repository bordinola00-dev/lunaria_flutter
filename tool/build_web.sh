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

if [[ "$SUPABASE_ANON_KEY" == sb_publishable_?* ]]; then
  :
elif [[ "$SUPABASE_ANON_KEY" == eyJ*.*.* ]]; then
  jwt_payload="${SUPABASE_ANON_KEY#*.}"
  jwt_payload="${jwt_payload%%.*}"
  jwt_payload="${jwt_payload//-/+}"
  jwt_payload="${jwt_payload//_/\/}"
  case $((${#jwt_payload} % 4)) in
    2) jwt_payload+='==' ;;
    3) jwt_payload+='=' ;;
  esac
  if ! decoded_payload="$(printf '%s' "$jwt_payload" | base64 --decode 2>/dev/null)"; then
    printf 'SUPABASE_ANON_KEY is not a valid public anon/publishable key.\n' >&2
    exit 1
  fi
  if [[ ! "$decoded_payload" =~ \"role\"[[:space:]]*:[[:space:]]*\"anon\" ]]; then
    printf 'SUPABASE_ANON_KEY must be an anon/publishable key, not a privileged key.\n' >&2
    exit 1
  fi
else
  printf 'SUPABASE_ANON_KEY must be a public anon/publishable key.\n' >&2
  exit 1
fi

if [[ "$SPOTIFY_REDIRECT_URI" != \
  "https://bordinola00-dev.github.io/lunaria_flutter/auth.html" ]]; then
  printf 'SPOTIFY_REDIRECT_URI must match the GitHub Pages auth.html URL.\n' >&2
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

"$flutter_command" build web --release --web-content-hash \
  --base-href /lunaria_flutter/ --pwa-strategy=none --no-pub \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
  --dart-define="SPOTIFY_CLIENT_ID=$SPOTIFY_CLIENT_ID" \
  --dart-define="SPOTIFY_REDIRECT_URI=$SPOTIFY_REDIRECT_URI"

find build/web -type f -name '.env*' -delete

remaining_env="$(find build/web -type f -name '.env*' -print -quit)"
if [[ -n "$remaining_env" ]]; then
  printf 'A .env file remains in build/web; refusing to publish it.\n' >&2
  exit 1
fi

if [[ ! -f build/web/index.html || ! -f build/web/manifest.json || \
  ! -f build/web/auth.html ]]; then
  printf 'Flutter did not produce the expected web release files.\n' >&2
  exit 1
fi
