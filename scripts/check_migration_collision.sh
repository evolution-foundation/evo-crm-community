#!/usr/bin/env bash
set -euo pipefail

CRM_DIR="evo-ai-crm-community/db/migrate"
AUTH_DIR="evo-auth-service-community/db/migrate"

if [[ ! -d "$CRM_DIR" || ! -d "$AUTH_DIR" ]]; then
  echo "ERROR: expected migration dirs not found. Run from umbrella root." >&2
  exit 2
fi

crm_versions=$(ls "$CRM_DIR" | grep -E '^[0-9]{14}_' | sed -E 's/^([0-9]{14})_.*$/\1/' | sort -u)
auth_versions=$(ls "$AUTH_DIR" | grep -E '^[0-9]{14}_' | sed -E 's/^([0-9]{14})_.*$/\1/' | sort -u)

collisions=$(comm -12 <(echo "$crm_versions") <(echo "$auth_versions") || true)

if [[ -n "$collisions" ]]; then
  echo "Migration version collision(s) between CRM and auth:" >&2
  while IFS= read -r v; do
    crm_file=$(ls "$CRM_DIR" | grep "^${v}_" || true)
    auth_file=$(ls "$AUTH_DIR" | grep "^${v}_" || true)
    echo "  version=$v" >&2
    echo "    CRM : $crm_file" >&2
    echo "    auth: $auth_file" >&2
  done <<< "$collisions"
  echo "" >&2
  echo "Renumber one side by 1 second (see scripts/README-migration-guard.md)." >&2
  exit 1
fi

crm_count=$([[ -z "$crm_versions" ]] && echo 0 || echo "$crm_versions" | wc -l)
auth_count=$([[ -z "$auth_versions" ]] && echo 0 || echo "$auth_versions" | wc -l)
echo "No migration version collisions between CRM (${crm_count} versions) and auth (${auth_count} versions)."
