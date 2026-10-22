#!/usr/bin/env bash
#
# Regression tests for scripts/generate-secrets.sh (CRM-828). Runs in CI and locally.
#
# Usage:
#   test-generate-secrets.sh [SCRIPT] [ENV_EXAMPLE]

set -euo pipefail

abs() { (cd "$(dirname "$1")" && echo "$PWD/$(basename "$1")"); }
SCRIPT=$(abs "${1:-scripts/generate-secrets.sh}")
EXAMPLE=$(abs "${2:-.env.example}")

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
AUTH_APIKEY_INTEGRATION_LOCAL"

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
mode_600() { [ "$(stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1")" = 600 ]; }

# Fresh install: every secret filled, JWT key independent, valid Fernet, private file.
cp "$EXAMPLE" a.env
bash "$SCRIPT" a.env > /dev/null
check "fresh install fills every secret" all_filled a.env
check "JWT_SECRET_KEY differs from SECRET_KEY_BASE" differ "$(value SECRET_KEY_BASE a.env)" "$(value JWT_SECRET_KEY a.env)"
check "EVOAI_AUTH_API_TOKEN differs from EVOAI_CRM_API_TOKEN" differ "$(value EVOAI_CRM_API_TOKEN a.env)" "$(value EVOAI_AUTH_API_TOKEN a.env)"
check "ENCRYPTION_KEY is a Fernet key" fernet_ok "$(value ENCRYPTION_KEY a.env)"
check ".env is mode 600" mode_600 a.env

# Re-running never rotates anything.
cp a.env a.first
bash "$SCRIPT" a.env > /dev/null
check "second run leaves the file unchanged" cmp -s a.env a.first

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

[ "$failures" -eq 0 ] || { echo "$failures check(s) failed"; exit 1; }
echo "all checks passed"
