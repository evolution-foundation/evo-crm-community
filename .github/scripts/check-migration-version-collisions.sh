#!/usr/bin/env bash
#
# EVO-2090 (follow-up EVO-1911) — Guard de colisão de version de migration.
#
# evo-ai-crm-community e evo-auth-service-community compartilham o mesmo banco e a
# mesma tabela `schema_migrations`. O Rails registra cada version (timestamp de 14
# dígitos) nessa tabela; se um serviço registra uma version, uma migration do OUTRO
# serviço com a MESMA version é considerada "já executada" e pulada para sempre ->
# a DDL dela nunca roda -> coluna/tabela ausente -> o app quebra no boot
# (ex.: `messages.source` -> "Undeclared attribute type for enum 'source'").
#
# Este script falha (exit 1) se os dois serviços tiverem qualquer version em comum
# em db/migrate. Rodável no CI (submódulos checkout) e localmente.
#
# Uso:
#   check-migration-version-collisions.sh [CRM_MIGRATE_DIR] [AUTH_MIGRATE_DIR]
# Defaults assumem a raiz do monorepo (submódulos).

set -euo pipefail

CRM_DIR="${1:-evo-ai-crm-community/db/migrate}"
AUTH_DIR="${2:-evo-auth-service-community/db/migrate}"

for d in "$CRM_DIR" "$AUTH_DIR"; do
  if [ ! -d "$d" ]; then
    echo "::error::diretório de migrations não encontrado: $d (submódulos inicializados?)"
    exit 2
  fi
done

# Extrai a version (14 dígitos iniciais) de cada arquivo de migration, únicas e ordenadas.
# `|| true`: grep sai 1 quando o dir não tem nenhum arquivo de 14 dígitos, o que sob
# `pipefail` abortaria a atribuição `crm_versions="$(...)"` com falha espúria.
versions() { ls "$1" 2>/dev/null | grep -oE '^[0-9]{14}' | sort -u || true; }

crm_versions="$(versions "$CRM_DIR")"
auth_versions="$(versions "$AUTH_DIR")"

dup="$(comm -12 <(printf '%s\n' "$crm_versions") <(printf '%s\n' "$auth_versions"))"

if [ -n "$dup" ]; then
  echo "::error::Colisão de version de migration entre CRM e auth (schema_migrations compartilhado):"
  while IFS= read -r v; do
    [ -z "$v" ] && continue
    echo "  version $v"
    echo "    CRM:  $(ls "$CRM_DIR"  | grep "^$v" || echo '(?)')"
    echo "    AUTH: $(ls "$AUTH_DIR" | grep "^$v" || echo '(?)')"
  done <<< "$dup"
  echo ""
  echo "Renomeie uma das migrations para um timestamp livre (segundos distintos por"
  echo "serviço) — ver convenção em CONTRIBUTING. Nunca reutilize a mesma version"
  echo "entre CRM e auth enquanto compartilharem schema_migrations."
  exit 1
fi

crm_count="$(printf '%s\n' "$crm_versions" | grep -c . || true)"
auth_count="$(printf '%s\n' "$auth_versions" | grep -c . || true)"
echo "OK: nenhuma version compartilhada entre CRM ($crm_count) e auth ($auth_count)."
