#!/usr/bin/env bash
# =============================================================================
# docker-publish.sh — Build e push multi-arch (amd64 + arm64) para Docker Hub
# =============================================================================
# Uso:
#   ./scripts/docker-publish.sh                    # build + push latest + versão atual
#   ./scripts/docker-publish.sh --version 1.0.1    # tag explícita
#   ./scripts/docker-publish.sh --image evo-bot-runtime  # só uma imagem
#   ./scripts/docker-publish.sh --dry-run          # mostra comandos sem executar
#
# Pré-requisitos:
#   docker login -u lc1868
#   docker buildx inspect evo-multiarch --bootstrap  # builder multi-arch ativo
# =============================================================================

set -euo pipefail

REGISTRY="lc1868"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- defaults ----------------------------------------------------------------
VERSION=""
TARGET_IMAGE=""
DRY_RUN=false

# --- parse args --------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)   VERSION="$2"; shift 2 ;;
    --image)     TARGET_IMAGE="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    *) echo "Arg desconhecido: $1"; exit 1 ;;
  esac
done

# --- helpers -----------------------------------------------------------------
run() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

# Resolve versão: --version > tag git mais recente > "dev"
resolve_version() {
  local subdir="$1"
  if [[ -n "$VERSION" ]]; then
    echo "$VERSION"
    return
  fi
  local tag
  tag=$(git -C "$REPO_ROOT/$subdir" describe --tags --abbrev=0 2>/dev/null || true)
  if [[ -n "$tag" ]]; then
    # remove prefixo 'v' se houver
    echo "${tag#v}"
  else
    echo "dev"
  fi
}

build_and_push() {
  local name="$1"          # nome da imagem no Docker Hub (sem registry)
  local context="$2"       # caminho do contexto de build relativo ao REPO_ROOT
  local dockerfile="$3"    # caminho do Dockerfile relativo ao contexto
  local subdir="$4"        # submodule/pasta para resolver versão git
  shift 4
  local extra_args=("$@")  # build args extras opcionais

  local ver
  ver=$(resolve_version "$subdir")
  local full_name="${REGISTRY}/${name}"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  IMAGE : ${full_name}"
  echo "  VERSION: ${ver}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  run docker buildx build \
    --builder evo-multiarch \
    --platform linux/amd64,linux/arm64 \
    --push \
    -f "${REPO_ROOT}/${context}/${dockerfile}" \
    -t "${full_name}:${ver}" \
    -t "${full_name}:latest" \
    "${extra_args[@]}" \
    "${REPO_ROOT}/${context}"
}

# =============================================================================
# Mapa de imagens
# =============================================================================
# Formato: build_and_push <image-name> <context> <dockerfile> <subdir-para-versao> [build-args...]

declare -A IMAGES
# imagem|context|dockerfile|subdir
declare -a IMAGE_LIST=(
  "evo-auth-service-community|evo-auth-service-community|Dockerfile|evo-auth-service-community"
  "evo-ai-crm-community|evo-ai-crm-community|docker/Dockerfile|evo-ai-crm-community"
  "evo-ai-frontend-community|evo-ai-frontend-community|Dockerfile|evo-ai-frontend-community"
  "evo-ai-processor-community|evo-ai-processor-community|Dockerfile|evo-ai-processor-community"
  "evo-ai-core-service-community|evo-ai-core-service-community|Dockerfile|evo-ai-core-service-community"
  "evo-bot-runtime|evo-bot-runtime|Dockerfile|evo-bot-runtime"
  "evo-crm-gateway|nginx|Dockerfile|nginx"
  "evo-nexus-dashboard|evo-nexus/site|Dockerfile|evo-nexus"
  "evo-nexus-runtime|evo-nexus|Dockerfile|evo-nexus"
)

# =============================================================================
# Execução
# =============================================================================
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║   docker-publish.sh — Build & Push para lc1868    ║"
echo "╚════════════════════════════════════════════════════╝"
[[ "$DRY_RUN" == true ]] && echo "[MODO DRY-RUN — nenhum comando será executado]"

BUILT=()
SKIPPED=()
FAILED=()

for entry in "${IMAGE_LIST[@]}"; do
  IFS='|' read -r img_name context dockerfile subdir <<< "$entry"

  # filtro por --image
  if [[ -n "$TARGET_IMAGE" && "$img_name" != "$TARGET_IMAGE" ]]; then
    SKIPPED+=("$img_name")
    continue
  fi

  # verifica se contexto existe
  if [[ ! -d "${REPO_ROOT}/${context}" ]]; then
    echo "⚠  SKIP ${img_name} — contexto '${context}' não encontrado (submodule vazio?)"
    SKIPPED+=("$img_name")
    continue
  fi

  if build_and_push "$img_name" "$context" "$dockerfile" "$subdir"; then
    BUILT+=("$img_name")
  else
    echo "✗  ERRO ao buildar ${img_name}"
    FAILED+=("$img_name")
  fi
done

# --- resumo ------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RESUMO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[[ ${#BUILT[@]} -gt 0 ]]   && echo "  ✓ Publicados  : ${BUILT[*]}"
[[ ${#SKIPPED[@]} -gt 0 ]] && echo "  ○ Ignorados   : ${SKIPPED[*]}"
[[ ${#FAILED[@]} -gt 0 ]]  && echo "  ✗ Com erro    : ${FAILED[*]}"

[[ ${#FAILED[@]} -gt 0 ]] && exit 1
exit 0
