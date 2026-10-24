#!/usr/bin/env bash
#
# Every secret scripts/generate-secrets.sh generates must stop docker compose when
# it is missing. Compose names only the first missing variable, so each
# one is removed on its own. Needs docker and an .env in the repository root
# (env_file); runs in CI after the .env is seeded.
#
# Usage:
#   test-compose-guards.sh

set -euo pipefail

GENERATOR=scripts/generate-secrets.sh
# No service in docker-compose.yml reads it, so there is nothing to guard.
UNGUARDED="AI_PROCESSOR_API_KEY"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp .env.example "$WORK/full.env"
bash "$GENERATOR" "$WORK/full.env" > /dev/null
docker compose --env-file "$WORK/full.env" config --quiet \
  || { echo "::error::docker compose rejects a generated .env"; exit 1; }

failures=0

# No published value may survive as a fallback or a literal anywhere in the rendered stack,
# nor ClickHouse's old fixed password or a RabbitMQ URL without credentials.
published=$(tr -d '\r' < "$(dirname "$0")/published-values.txt")
docker compose --env-file "$WORK/full.env" config > "$WORK/rendered.yml"
leaks=$({ grep -oF -- "$published" "$WORK/rendered.yml"; grep -nE '(: |- )password$|amqp://[^@]+$' "$WORK/rendered.yml"; } || true)
if [ -n "$leaks" ]; then
  echo "::error::FAIL the rendered compose still holds a published or default credential:"
  echo "$leaks"
  failures=$((failures + 1))
else
  echo "ok   no published or default credential in the rendered compose"
fi

names=$(sed -n '/^SECRETS="/,/^"/p' "$GENERATOR" | grep : | cut -d: -f1)
for name in $names; do
  case " $UNGUARDED " in *" $name "*) continue ;; esac
  grep -v "^$name=" "$WORK/full.env" > "$WORK/one.env"
  if docker compose --env-file "$WORK/one.env" config --quiet 2> "$WORK/err"; then
    echo "::error::FAIL docker compose starts without $name"
    failures=$((failures + 1))
  elif ! grep -q "$name must be set in .env" "$WORK/err"; then
    echo "::error::FAIL docker compose failed without $name, but not on its guard:"
    cat "$WORK/err"
    failures=$((failures + 1))
  else
    echo "ok   $name"
  fi
done

[ "$failures" -eq 0 ] || { echo "$failures check(s) failed"; exit 1; }
echo "all checks passed"
