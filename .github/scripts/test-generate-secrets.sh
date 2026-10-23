#!/usr/bin/env bash
#
# Regression tests for scripts/generate-secrets.sh. Runs in CI and locally.
#
# Usage:
#   test-generate-secrets.sh [SCRIPT] [ENV_EXAMPLE]

set -euo pipefail

abs() { (cd "$(dirname "$1")" && echo "$PWD/$(basename "$1")"); }
SCRIPT=$(abs "${1:-scripts/generate-secrets.sh}")
EXAMPLE=$(abs "${2:-.env.example}")
# Kept apart from the script's own list, so a value missing there still fails here.
PUBLISHED_VALUES=$(tr -d '\r' < "$(dirname "$0")/published-values.txt")

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

failures=0
check() {
  local label="$1"; shift
  if "$@"; then echo "ok   $label"; else echo "::error::FAIL $label"; failures=$((failures + 1)); fi
}

SECRET_NAMES="SECRET_KEY_BASE JWT_SECRET_KEY DOORKEEPER_JWT_SECRET_KEY ENCRYPTION_KEY
EVOAI_CRM_API_TOKEN EVOAI_AUTH_API_TOKEN BOT_RUNTIME_SECRET AI_PROCESSOR_API_KEY
AUTH_APIKEY_INTEGRATION_LOCAL POSTGRES_PASSWORD REDIS_PASSWORD CLICKHOUSE_PASSWORD
RABBITMQ_PASSWORD"

value() { grep "^$1=" "$2" | tail -n 1 | cut -d= -f2-; }
all_filled() {
  local name v
  for name in $SECRET_NAMES; do
    v=$(value "$name" "$1" | tr -d '\r')
    [ -n "$v" ] && [ "$v" != CHANGE_ME ] || { echo "     $name is not filled"; return 1; }
  done
}
same() { [ "$1" = "$2" ]; }
differ() { [ "$1" != "$2" ]; }
fernet_ok() { python3 -c 'import base64, sys; assert len(base64.urlsafe_b64decode(sys.argv[1])) == 32' "$1"; }
# Also catches a published value repeated inside another variable, such as a URL.
no_published() {
  local hit
  hit=$(tr -d '\r' < "$1" | grep -oF -- "$PUBLISHED_VALUES" | sort -u || true)
  [ -z "$hit" ] || { echo "     still holds: $hit"; return 1; }
}
mode_600() { [ "$(stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1")" = 600 ]; }

# Fresh install: every secret filled, JWT key independent, valid Fernet, private file.
cp "$EXAMPLE" a.env
bash "$SCRIPT" a.env > /dev/null
check "fresh install fills every secret" all_filled a.env
check "fresh install holds no published value" no_published a.env
check "JWT_SECRET_KEY differs from SECRET_KEY_BASE" differ "$(value SECRET_KEY_BASE a.env)" "$(value JWT_SECRET_KEY a.env)"
check "EVOAI_AUTH_API_TOKEN differs from EVOAI_CRM_API_TOKEN" differ "$(value EVOAI_CRM_API_TOKEN a.env)" "$(value EVOAI_AUTH_API_TOKEN a.env)"
check "ENCRYPTION_KEY is a Fernet key" fernet_ok "$(value ENCRYPTION_KEY a.env)"
check ".env is mode 600" mode_600 a.env

# Re-running never rotates anything.
cp a.env a.first
bash "$SCRIPT" a.env > /dev/null
check "second run leaves the file unchanged" cmp -s a.env a.first

# An .env from before EVOAI_AUTH_API_TOKEN existed gains only that line.
grep -v '^EVOAI_AUTH_API_TOKEN=' a.first > e.env
cp e.env e.before
bash "$SCRIPT" e.env > /dev/null
check "old .env gains EVOAI_AUTH_API_TOKEN" all_filled e.env
check "old .env keeps its other values" cmp -s e.before <(grep -v '^EVOAI_AUTH_API_TOKEN=' e.env)

# Two installations do not share values.
cp "$EXAMPLE" b.env
bash "$SCRIPT" b.env > /dev/null
check "installations get different tokens" differ "$(value EVOAI_CRM_API_TOKEN a.env)" "$(value EVOAI_CRM_API_TOKEN b.env)"

# A value the script cannot edit is not overridden by an appended line.
printf 'export JWT_SECRET_KEY=abc\n' > c.env
bash "$SCRIPT" c.env > /dev/null 2>&1
check "export-form value is not overridden" same "$(grep -c '^JWT_SECRET_KEY=' c.env)" 0

# Compose trims the value, so a padded placeholder is still a placeholder.
printf 'EVOAI_CRM_API_TOKEN= CHANGE_ME\n' > d.env
bash "$SCRIPT" d.env > /dev/null
check "padded CHANGE_ME is replaced" same "$(value EVOAI_CRM_API_TOKEN d.env | grep -c CHANGE_ME)" 0

# An .env from before per-install secrets keeps its values, but the script names the public ones.
printf '%s\n' 'SECRET_KEY_BASE=a]i9F#k2$$Lm7Nq0R!sT4uW6xZ8bD1eG3hJ5oP7rV9yAcE2fH4jM6pS8vX0zB3dK5nQ7tU9wY1' \
  'EVOAI_CRM_API_TOKEN=6e10e689-58ce-4416-bf0d-f5818bf2dcf8' \
  'POSTGRES_PASSWORD=evoai_dev_password' 'REDIS_PASSWORD=evoai_redis_pass' > f.env
cp f.env f.before
bash "$SCRIPT" f.env > /dev/null 2> f.err
check "published values are kept" cmp -s f.before <(head -n 4 f.env)
check "published values are reported" grep -q "published in this repository: SECRET_KEY_BASE EVOAI_CRM_API_TOKEN POSTGRES_PASSWORD REDIS_PASSWORD$" f.err
bash "$SCRIPT" a.env > /dev/null 2> a.err
check "generated values are not reported" same "$(grep -c published a.err)" 0

[ "$failures" -eq 0 ] || { echo "$failures check(s) failed"; exit 1; }
echo "all checks passed"
