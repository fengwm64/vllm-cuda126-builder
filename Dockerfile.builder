# ==============================================================================
# vLLM wheel builder from source with CUDA 12.6
#
# Build and export wheel:
#   docker build -f Dockerfile.builder \
#     --build-arg VLLM_VERSION=v0.20.1 \
#     --build-arg TORCH_CUDA_ARCH_LIST="8.0 8.6" \
#     --output type=local,dest=./wheels .
# ==============================================================================

FROM nvidia/cuda:12.6.0-devel-ubuntu22.04 AS builder

ARG VLLM_VERSION=v0.20.1
ARG TORCH_CUDA_ARCH_LIST="8.0 8.6"
ARG MAX_JOBS=32
ARG NVCC_THREADS=1

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_HOME=/usr/local/cuda
ENV PATH="${CUDA_HOME}/bin:${PATH}"
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}
ENV MAX_JOBS=${MAX_JOBS}
ENV NVCC_THREADS=${NVCC_THREADS}
ENV VLLM_TARGET_DEVICE=cuda

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    git \
    cmake \
    ninja-build \
    build-essential \
    curl \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-dev \
    python3.12-venv \
    python3-pip \
    && ln -sf /usr/bin/python3.12 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && python3.12 -m ensurepip --upgrade \
    && python3.12 -m pip install --upgrade pip setuptools wheel \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install PyTorch cu126 + FlashInfer cu126
RUN --mount=type=cache,target=/root/.cache/pip \
    python3.12 -m pip install \
    torch==2.11.0 \
    torchvision==0.26.0 \
    torchaudio==2.11.0 \
    --index-url https://download.pytorch.org/whl/cu126

RUN --mount=type=cache,target=/root/.cache/pip \
    python3.12 -m pip install \
    flashinfer-python==0.6.8.post1 \
    --extra-index-url https://flashinfer.ai/whl/cu126

# Clone vLLM source
WORKDIR /build
RUN git clone --depth 1 --branch ${VLLM_VERSION} \
    https://github.com/vllm-project/vllm.git

WORKDIR /build/vllm

# Use the already-installed PyTorch (skip re-downloading)
RUN python use_existing_torch.py

# Install build dependencies
RUN --mount=type=cache,target=/root/.cache/pip \
    python3.12 -m pip install -r requirements/build/cuda.txt \
    && python3.12 -m pip install setuptools_scm build

# Build wheel only (no install)
RUN --mount=type=cache,target=/root/.cache/pip \
    python3.12 -m pip wheel --no-build-isolation --no-deps --wheel-dir /wheels .

# Output stage: export wheel to host via BuildKit --output
FROM scratch AS output
COPY --from=builder /wheels/vllm-*.whl /
