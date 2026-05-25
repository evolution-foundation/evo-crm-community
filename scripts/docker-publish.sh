#!/usr/bin/env bash
# =============================================================================
# docker-publish.sh — Build e push multi-arch (amd64 + arm64) para Docker Hub
# =============================================================================
# Uso:
#   ./scripts/docker-publish.sh                    # build + push latest + versão atual
#   ./scripts/docker-publish.sh --version 1.0.0-rc4  # tag explícita
#   ./scripts/docker-publish.sh --image evo-ai-crm-community  # só uma imagem
#   ./scripts/docker-publish.sh --dry-run          # mostra comandos sem executar
#
# Pré-requisitos:
#   docker login -u lc1868
#   docker buildx inspect evo-multiarch --bootstrap  # builder multi-arch ativo
#
# Saída:
#   Console: progresso em tempo real
#   Arquivo: logs/docker-publish-<timestamp>.log  (resumo + stderr de cada build)
# =============================================================================

set -euo pipefail

REGISTRY="lc1868"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="${REPO_ROOT}/logs"
LOG_FILE="${LOG_DIR}/docker-publish-${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"

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

# --- logging -----------------------------------------------------------------
log() {
  echo "$*" | tee -a "$LOG_FILE"
}

log_section() {
  log ""
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "  $*"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# --- helpers -----------------------------------------------------------------
run() {
  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] $*"
  else
    "$@"
  fi
}

resolve_version() {
  local subdir="$1"
  if [[ -n "$VERSION" ]]; then
    echo "$VERSION"
    return
  fi
  local tag
  tag=$(git -C "${REPO_ROOT}/${subdir}" describe --tags --abbrev=0 2>/dev/null || true)
  if [[ -n "$tag" ]]; then
    echo "${tag#v}"
  else
    echo "dev"
  fi
}

# Tracking arrays
BUILT=()
SKIPPED=()
FAILED=()
declare -A BUILD_DURATION
declare -A BUILD_TAGS

build_and_push() {
  local name="$1"
  local context="$2"
  local dockerfile="$3"
  local subdir="$4"

  local ver
  ver=$(resolve_version "$subdir")
  local full_name="${REGISTRY}/${name}"
  local tag_ver="${full_name}:${ver}"
  local tag_latest="${full_name}:latest"

  log_section "IMAGE: ${full_name}  |  VERSION: ${ver}"
  log "  Context   : ${REPO_ROOT}/${context}"
  log "  Dockerfile: ${context}/${dockerfile}"
  log "  Tags      : ${tag_ver}  ${tag_latest}"

  local t_start
  t_start=$(date +%s)

  if run docker buildx build \
    --builder evo-multiarch \
    --platform linux/amd64,linux/arm64 \
    --push \
    -f "${REPO_ROOT}/${context}/${dockerfile}" \
    -t "${tag_ver}" \
    -t "${tag_latest}" \
    "${REPO_ROOT}/${context}" 2>&1 | tee -a "$LOG_FILE"; then

    local t_end elapsed
    t_end=$(date +%s)
    elapsed=$(( t_end - t_start ))
    BUILD_DURATION["$name"]="${elapsed}s"
    BUILD_TAGS["$name"]="${ver}"
    BUILT+=("$name")
    log "  ✓ OK — ${elapsed}s"
  else
    FAILED+=("$name")
    log "  ✗ ERRO ao buildar ${name}"
  fi
}

# =============================================================================
# Mapa de imagens
# Formato: image-name|context|dockerfile|subdir-para-versao
# =============================================================================
declare -a IMAGE_LIST=(
  "evo-auth-service-community|evo-auth-service-community|Dockerfile|evo-auth-service-community"
  "evo-ai-crm-community|evo-ai-crm-community|docker/Dockerfile|evo-ai-crm-community"
  "evo-ai-frontend-community|evo-ai-frontend-community|Dockerfile|evo-ai-frontend-community"
  "evo-ai-processor-community|evo-ai-processor-community|Dockerfile|evo-ai-processor-community"
  "evo-ai-core-service-community|evo-ai-core-service-community|Dockerfile|evo-ai-core-service-community"
  "evo-bot-runtime|evo-bot-runtime|Dockerfile|evo-bot-runtime"
  "evolution-go|evolution-go|Dockerfile|evolution-go"
  "evo-crm-gateway|nginx|Dockerfile|nginx"
)
# evo-flow: build local via docker-compose.evo-flow.yml — não publicado no Docker Hub

# =============================================================================
# Header
# =============================================================================
log ""
log "╔════════════════════════════════════════════════════╗"
log "║   docker-publish.sh — Build & Push para lc1868    ║"
log "╚════════════════════════════════════════════════════╝"
log "  Início  : $(date '+%Y-%m-%d %H:%M:%S')"
log "  Log     : ${LOG_FILE}"
[[ "$DRY_RUN" == true ]] && log "  MODO    : DRY-RUN (nenhum comando será executado)"
[[ -n "$TARGET_IMAGE" ]]  && log "  Filtro  : --image ${TARGET_IMAGE}"
[[ -n "$VERSION" ]]        && log "  Versão  : --version ${VERSION}"

# =============================================================================
# Execução
# =============================================================================
for entry in "${IMAGE_LIST[@]}"; do
  IFS='|' read -r img_name context dockerfile subdir <<< "$entry"

  if [[ -n "$TARGET_IMAGE" && "$img_name" != "$TARGET_IMAGE" ]]; then
    SKIPPED+=("$img_name")
    continue
  fi

  if [[ ! -d "${REPO_ROOT}/${context}" ]]; then
    log ""
    log "  ⚠  SKIP ${img_name} — contexto '${context}' não encontrado (submodule vazio?)"
    SKIPPED+=("$img_name")
    continue
  fi

  build_and_push "$img_name" "$context" "$dockerfile" "$subdir"
done

# =============================================================================
# Resumo final
# =============================================================================
T_END_GLOBAL="$(date '+%Y-%m-%d %H:%M:%S')"

log ""
log "╔════════════════════════════════════════════════════╗"
log "║                    RESUMO FINAL                    ║"
log "╚════════════════════════════════════════════════════╝"
log "  Concluído: ${T_END_GLOBAL}"
log ""

if [[ ${#BUILT[@]} -gt 0 ]]; then
  log "  ✓ PUBLICADOS (${#BUILT[@]}):"
  for img in "${BUILT[@]}"; do
    log "      ${REGISTRY}/${img}:${BUILD_TAGS[$img]}  [${BUILD_DURATION[$img]}]"
    log "      ${REGISTRY}/${img}:latest"
  done
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  log ""
  log "  ○ IGNORADOS (${#SKIPPED[@]}): ${SKIPPED[*]}"
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  log ""
  log "  ✗ COM ERRO (${#FAILED[@]}): ${FAILED[*]}"
  log "    Ver log completo: ${LOG_FILE}"
fi

log ""
log "  Log completo: ${LOG_FILE}"
log ""

[[ ${#FAILED[@]} -gt 0 ]] && exit 1
exit 0
