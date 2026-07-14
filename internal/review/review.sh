#!/usr/bin/env bash
# review — sobe a stack de review com um ou mais serviços fixados na imagem do seu PR.
#
#   review <pr-url> [<pr-url> ...]
#
# Cada URL de PR (https://github.com/<org>/<repo>/pull/<N>) fixa o serviço daquele
# repo em :pr-<N>; todos os outros rodam :develop. Depois sobe a stack.
#
# Um card com vários PRs? Passe todos os links: o revisor copia do card.
# Sem argumentos = baseline (tudo em :develop).
#
# Flags:
#   -n, --dry-run   mostra o que rodaria (env + comando compose) sem subir nada.
#
# Exemplos:
#   ./review.sh https://github.com/evolution-foundation/evo-ai-crm-community/pull/140
#   ./review.sh <crm-pr-url> <auth-pr-url>
#   ./review.sh -n <crm-pr-url>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE="$SCRIPT_DIR/docker-compose.yml"

DRY_RUN=0
declare -a URLS=()
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) URLS+=("$arg") ;;
  esac
done

# repo do PR -> variável de tag do serviço no compose
repo_to_tagvar() {
  case "$1" in
    evo-ai-crm-community)          echo "CRM_TAG" ;;
    evo-auth-service-community)    echo "AUTH_TAG" ;;
    evo-ai-core-service-community) echo "CORE_TAG" ;;
    evo-ai-processor-community)    echo "PROCESSOR_TAG" ;;
    evo-bot-runtime)               echo "BOT_TAG" ;;
    evo-ai-frontend-community)     echo "FRONTEND_TAG" ;;
    *) echo "" ;;
  esac
}

declare -a TAG_ENVS=()
declare -a SUMMARY=()

for url in "${URLS[@]:-}"; do
  [ -z "$url" ] && continue
  if [[ "$url" =~ github\.com/[^/]+/([^/]+)/pull/([0-9]+) ]]; then
    repo="${BASH_REMATCH[1]}"; num="${BASH_REMATCH[2]}"
  else
    echo "erro: não é URL de PR do GitHub: $url" >&2; exit 1
  fi
  var="$(repo_to_tagvar "$repo")"
  if [ -z "$var" ]; then
    echo "erro: repo '$repo' não é um serviço da stack de review" >&2; exit 1
  fi
  tag="pr-${num}"
  img="evoapicloud/${repo}:${tag}"
  if ! docker manifest inspect "$img" >/dev/null 2>&1; then
    echo "aviso: imagem $img ainda não existe no registry — o build do PR já terminou?" >&2
  fi
  TAG_ENVS+=("${var}=${tag}")
  SUMMARY+=("${repo} → ${tag}")
done

# URLs de review (não-localhost — o CRM recusa boot em produção com localhost)
export BACKEND_URL="${BACKEND_URL:-http://host.docker.internal:3030}"
export FRONTEND_URL="${FRONTEND_URL:-http://host.docker.internal:5173}"

echo "Stack de review:"
if [ "${#SUMMARY[@]}" -eq 0 ]; then
  echo "  - (todos os serviços → develop)"
else
  for s in "${SUMMARY[@]}"; do echo "  - $s"; done
  echo "  - (demais serviços → develop)"
fi
echo

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] rodaria:"
  echo "  ${TAG_ENVS[*]} \\"
  echo "  BACKEND_URL=$BACKEND_URL FRONTEND_URL=$FRONTEND_URL \\"
  echo "  docker compose -f $COMPOSE up -d"
  exit 0
fi

if [ "${#TAG_ENVS[@]}" -eq 0 ]; then
  docker compose -f "$COMPOSE" up -d
else
  env "${TAG_ENVS[@]}" docker compose -f "$COMPOSE" up -d
fi

echo
echo "Gateway:  $BACKEND_URL"
echo "Frontend: $FRONTEND_URL"
echo "Derrubar: docker compose -f $COMPOSE down -v"
