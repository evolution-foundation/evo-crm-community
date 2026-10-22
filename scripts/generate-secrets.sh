#!/usr/bin/env bash
# =============================================================================
# Evo CRM Community — Secret generation
# =============================================================================
# Fills every secret in an env file that is still empty, CHANGE_ME or missing
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
# umask only covers files created here; .env usually comes from a plain `cp`.
chmod 600 "$ENV_FILE"

# NAME:FORMAT — to generate one more secret, add a line here.
#   hex32 / hex64  hex only, so no `$`, `#` or quotes reach compose interpolation
#   fernet         URL-safe base64 of 32 bytes; `openssl rand -hex 32` is not a
#                  valid Fernet key and the processor fails to save credentials
SECRETS="
SECRET_KEY_BASE:hex64
JWT_SECRET_KEY:hex64
DOORKEEPER_JWT_SECRET_KEY:hex64
ENCRYPTION_KEY:fernet
EVOAI_CRM_API_TOKEN:hex32
EVOAI_AUTH_API_TOKEN:hex32
BOT_RUNTIME_SECRET:hex32
AI_PROCESSOR_API_KEY:hex32
AUTH_APIKEY_INTEGRATION_LOCAL:hex32
"

# What .env.example shipped before CRM-828. An .env copied back then still holds
# these, and they are public. Not rotated here: ENCRYPTION_KEY and SECRET_KEY_BASE
# take saved credentials and sessions with them, so the operator decides.
PUBLISHED='a]i9F#k2$$Lm7Nq0R!sT4uW6xZ8bD1eG3hJ5oP7rV9yAcE2fH4jM6pS8vX0zB3dK5nQ7tU9wY1
a]i9F#k2$Lm7Nq0R!sT4uW6xZ8bD1eG3hJ5oP7rV9yAcE2fH4jM6pS8vX0zB3dK5nQ7tU9wY1
XoQPOBw2FrzjQS11utERG9qO2MsAnXFxlhIns_uUxRk=
6e10e689-58ce-4416-bf0d-f5818bf2dcf8
evoflow-dev-key
evo-bot-runtime-dev-secret
evo-processor-dev-api-key'

# Read like docker compose does: last occurrence wins, an inline ` # comment`
# and surrounding quotes are not part of the value.
current_value() {
  local value
  value=$({ grep -E "^$1=" "$ENV_FILE" || true; } | tail -n 1 | cut -d= -f2- | tr -d '\r')
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%%[[:space:]]#*}"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value#\"}"; value="${value%\"}"
  value="${value#\'}"; value="${value%\'}"
  printf '%s' "$value"
}

is_placeholder() {
  [ -z "$1" ] || [ "$1" = "CHANGE_ME" ]
}

is_published() {
  grep -qxF -- "$1" <<< "$PUBLISHED"
}

editable() {
  grep -qE "^$1=" "$ENV_FILE"
}

# Declared as `export NAME=` or `NAME = `: compose reads it, this script does not edit it.
in_other_form() {
  ! editable "$1" && grep -qE "^[[:space:]]*(export[[:space:]]+)?$1[[:space:]]*=" "$ENV_FILE"
}

generate() {
  local value
  case "$1" in
    hex32)  value=$(openssl rand -hex 32) || true ;;
    hex64)  value=$(openssl rand -hex 64) || true ;;
    fernet) value=$(openssl rand -base64 32 | tr '+/' '-_') || true ;;
  esac
  [ -n "$value" ] || fail "could not generate a value for $2."
  printf '%s' "$value"
}

generated=""
published=""
for entry in $SECRETS; do
  name="${entry%%:*}"
  format="${entry#*:}"

  if editable "$name"; then
    current=$(current_value "$name")
    if ! is_placeholder "$current"; then
      if is_published "$current"; then published="$published $name"; fi
      continue
    fi
    value=$(generate "$format" "$name")
    NAME="$name" VALUE="$value" awk '
      index($0, ENVIRON["NAME"] "=") == 1 { print ENVIRON["NAME"] "=" ENVIRON["VALUE"]; next }
      { print }
    ' "$ENV_FILE" > "$TMP_FILE"
    cat "$TMP_FILE" > "$ENV_FILE"
  elif in_other_form "$name"; then
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

if [ -n "$published" ]; then
  warn "These secrets in $ENV_FILE still hold a value published in this repository:$published"
  warn "Rotate them as CHANGELOG.md describes. Rotating ENCRYPTION_KEY makes saved AI credentials unreadable."
fi
