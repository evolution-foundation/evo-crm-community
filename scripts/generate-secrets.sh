#!/usr/bin/env bash
# =============================================================================
# Evo CRM Community — Secret generation
# =============================================================================
# Fills every secret in an env file that is still CHANGE_ME, empty or missing
# with a freshly generated value. Secrets that already hold a value are kept,
# so running it again never rotates anything.
#
# Used by setup.sh and `make setup`. Run it yourself after a manual
# `cp .env.example .env`.
#
# Usage:
#   bash scripts/generate-secrets.sh [env-file]   (default: .env)
#
# Depends only on openssl. Portable across Linux and macOS (no `sed -i`).
# =============================================================================

set -eo pipefail
umask 077

ENV_FILE="${1:-.env}"
TMP_FILE="$ENV_FILE.tmp.$$"
trap 'rm -f "$TMP_FILE"' EXIT

fail() { echo "[ERROR] $1" >&2; exit 1; }
warn() { echo "[WARN]  $1" >&2; }

command -v openssl > /dev/null 2>&1 || fail "openssl is required to generate secrets."
[ -f "$ENV_FILE" ] || fail "$ENV_FILE not found."

# NAME:FORMAT — to generate one more secret, add a line here.
#   hex32 / hex64  hex only, so no `$`, `#` or quotes reach compose interpolation
#   fernet         URL-safe base64 of 32 bytes; `openssl rand -hex 32` is not a
#                  valid Fernet key and the processor fails to save credentials
#   jwt            one value shared by SECRET_KEY_BASE and JWT_SECRET_KEY: auth
#                  signs with the first, core-service validates with the second
SECRETS="
SECRET_KEY_BASE:jwt
JWT_SECRET_KEY:jwt
DOORKEEPER_JWT_SECRET_KEY:hex64
ENCRYPTION_KEY:fernet
EVOAI_CRM_API_TOKEN:hex32
BOT_RUNTIME_SECRET:hex32
AI_PROCESSOR_API_KEY:hex32
AUTH_APIKEY_INTEGRATION_LOCAL:hex32
"

# Read like docker compose does: last occurrence wins, an inline ` # comment`
# and surrounding quotes are not part of the value.
current_value() {
  local value
  value=$({ grep -E "^$1=" "$ENV_FILE" || true; } | tail -n 1 | cut -d= -f2- | tr -d '\r')
  value="${value%%[[:space:]]#*}"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value#\"}"; value="${value%\"}"
  value="${value#\'}"; value="${value%\'}"
  printf '%s' "$value"
}

is_placeholder() {
  [ -z "$1" ] || [ "$1" = "CHANGE_ME" ]
}

generate() {
  local value
  case "$1" in
    hex32)  value=$(openssl rand -hex 32) || true ;;
    hex64)  value=$(openssl rand -hex 64) || true ;;
    fernet) value=$(openssl rand -base64 32 | tr '+/' '-_') || true ;;
    jwt)    value="$JWT_VALUE" ;;
  esac
  [ -n "$value" ] || fail "could not generate a value for $2."
  printf '%s' "$value"
}

SKB_VALUE=$(current_value SECRET_KEY_BASE)
JWT_CURRENT=$(current_value JWT_SECRET_KEY)
if is_placeholder "$SKB_VALUE" && is_placeholder "$JWT_CURRENT"; then
  JWT_VALUE=$(generate hex64 SECRET_KEY_BASE)
elif is_placeholder "$SKB_VALUE" || is_placeholder "$JWT_CURRENT"; then
  # The pair must stay equal, so the half that is set wins. That does not rotate it.
  if is_placeholder "$SKB_VALUE"; then JWT_VALUE="$JWT_CURRENT"; else JWT_VALUE="$SKB_VALUE"; fi
  warn "SECRET_KEY_BASE and JWT_SECRET_KEY must match: copying the one already set."
  warn "To rotate them, set BOTH to CHANGE_ME and run this script again."
fi

generated=""
for entry in $SECRETS; do
  name="${entry%%:*}"
  format="${entry#*:}"

  if grep -qE "^$name=" "$ENV_FILE"; then
    is_placeholder "$(current_value "$name")" || continue
    value=$(generate "$format" "$name")
    NAME="$name" VALUE="$value" awk '
      index($0, ENVIRON["NAME"] "=") == 1 { print ENVIRON["NAME"] "=" ENVIRON["VALUE"]; next }
      { print }
    ' "$ENV_FILE" > "$TMP_FILE"
    cat "$TMP_FILE" > "$ENV_FILE"
  elif grep -qE "^[[:space:]]*(export[[:space:]]+)?$name[[:space:]]*=" "$ENV_FILE"; then
    # Appending a second line would override the user's value in compose.
    warn "$name is in $ENV_FILE in a form this script does not edit; set it by hand."
    continue
  else
    value=$(generate "$format" "$name")
    if [ -n "$(tail -c 1 "$ENV_FILE")" ]; then echo >> "$ENV_FILE"; fi
    printf '%s=%s\n' "$name" "$value" >> "$ENV_FILE"
  fi

  generated="$generated $name"
done

if [ -n "$generated" ]; then
  echo "Generated secrets in $ENV_FILE:$generated"
else
  echo "All secrets in $ENV_FILE already set, nothing generated"
fi
