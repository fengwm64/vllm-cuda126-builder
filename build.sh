#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# vLLM CUDA 12.6 build script
#
# Usage:
#   ./build.sh                          # Build wheel + runtime image
#   ./build.sh --wheel-only             # Only build and export the wheel
#   ./build.sh --runtime-only           # Only build runtime (wheel must exist)
#
# Options:
#   --version=VERSION       vLLM version (default: v0.20.1)
#   --arch="SM_LIST"        CUDA SM versions (default: "8.0 8.6")
#   --jobs=N                MAX_JOBS for compilation (default: 32)
#   --tag=TAG               Runtime image tag (default: vllm-openai:<version>)
# ==============================================================================

VLLM_VERSION="v0.20.1"
TORCH_CUDA_ARCH_LIST="8.0 8.6"
MAX_JOBS="32"
IMAGE_TAG=""
WHEEL_ONLY=false
RUNTIME_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --wheel-only)   WHEEL_ONLY=true ;;
        --runtime-only) RUNTIME_ONLY=true ;;
        --version=*)    VLLM_VERSION="${arg#*=}" ;;
        --arch=*)       TORCH_CUDA_ARCH_LIST="${arg#*=}" ;;
        --jobs=*)       MAX_JOBS="${arg#*=}" ;;
        --tag=*)        IMAGE_TAG="${arg#*=}" ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

[[ -z "$IMAGE_TAG" ]] && IMAGE_TAG="vllm-openai:${VLLM_VERSION}"

WHEELS_DIR="$(pwd)/wheels"

# ---- Step 1: Build wheel ----
if [[ "$RUNTIME_ONLY" == false ]]; then
    echo "========================================"
    echo " Step 1: Building vLLM wheel"
    echo " Version:  ${VLLM_VERSION}"
    echo " Arch:     ${TORCH_CUDA_ARCH_LIST}"
    echo " Jobs:     ${MAX_JOBS}"
    echo "========================================"

    DOCKER_BUILDKIT=1 docker build -f Dockerfile.builder \
        --build-arg VLLM_VERSION="${VLLM_VERSION}" \
        --build-arg TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST}" \
        --build-arg MAX_JOBS="${MAX_JOBS}" \
        --output type=local,dest="${WHEELS_DIR}" \
        .

    echo ""
    echo "Wheel exported to ${WHEELS_DIR}/"
    ls -lh "${WHEELS_DIR}"/vllm-*.whl
fi

if [[ "$WHEEL_ONLY" == true ]]; then
    echo ""
    echo "Done (--wheel-only). Wheel is at:"
    ls "${WHEELS_DIR}"/vllm-*.whl
    exit 0
fi

# ---- Step 2: Build minimal runtime image ----
WHEEL_FILE=$(ls "${WHEELS_DIR}"/vllm-*.whl | head -1)
WHEEL_BASENAME=$(basename "$WHEEL_FILE")

echo ""
echo "========================================"
echo " Step 2: Building runtime image"
echo " Tag:      ${IMAGE_TAG}"
echo " Wheel:    ${WHEEL_BASENAME}"
echo "========================================"

docker build -f Dockerfile.runtime \
    --build-arg VLLM_WHEEL="wheels/${WHEEL_BASENAME}" \
    --build-arg TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST}" \
    -t "${IMAGE_TAG}" \
    .

echo ""
echo "========================================"
echo " Done!"
echo "========================================"
echo ""
echo "Wheel:  ${WHEELS_DIR}/${WHEEL_BASENAME}"
echo "Image:  ${IMAGE_TAG}"
echo ""
echo "Run:"
echo "  docker run --gpus all -p 8000:8000 \\"
echo "    -v ~/.cache/huggingface:/root/.cache/huggingface \\"
echo "    ${IMAGE_TAG} \\"
echo "    --model meta-llama/Llama-3-8B-Instruct \\"
echo "    --max-model-len 4096"
