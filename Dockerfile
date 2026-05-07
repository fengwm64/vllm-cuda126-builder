# ==============================================================================
# vLLM Docker image built from source with CUDA 12.6
#
# Compatible with NVIDIA driver >= 530 (CUDA 12.x forward compatibility)
# Target GPUs: Ampere (SM 8.0/8.6) - A100, RTX 3090, etc.
#
# Build:
#   docker build \
#     --build-arg VLLM_VERSION=v0.20.1 \
#     --build-arg TORCH_CUDA_ARCH_LIST="8.0 8.6" \
#     -t vllm-cu126:v0.20.1 .
# ==============================================================================

# -------- Stage 1: Build vLLM from source --------
FROM nvidia/cuda:12.6.0-devel-ubuntu22.04 AS builder

ARG VLLM_VERSION=v0.20.1
ARG TORCH_CUDA_ARCH_LIST="8.0 8.6"
ARG MAX_JOBS=4
ARG NVCC_THREADS=4

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
RUN python3.12 -m pip install --no-cache-dir \
    torch==2.11.0 \
    torchvision==0.26.0 \
    torchaudio==2.11.0 \
    --index-url https://download.pytorch.org/whl/cu126

RUN python3.12 -m pip install --no-cache-dir \
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
RUN python3.12 -m pip install --no-cache-dir -r requirements/build/cuda.txt \
    && python3.12 -m pip install --no-cache-dir setuptools_scm

# Build and install vLLM
RUN python3.12 -m pip install --no-cache-dir --no-build-isolation .

# -------- Stage 2: Runtime image --------
FROM nvidia/cuda:12.6.0-base-ubuntu22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH="/usr/local/cuda/compat:${LD_LIBRARY_PATH}"

# Install Python, CUDA runtime components for JIT, and basic system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3-pip \
    git \
    cuda-nvcc-12-6 \
    cuda-cudart-12-6 \
    cuda-nvrtc-12-6 \
    libcublas-dev-12-6 \
    libcurand-dev-12-6 \
    && ln -sf /usr/bin/python3.12 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && python3.12 -m ensurepip --upgrade \
    && python3.12 -m pip install --upgrade pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.12/dist-packages /usr/local/lib/python3.12/dist-packages
COPY --from=builder /usr/local/bin/vllm /usr/local/bin/vllm
COPY --from=builder /usr/local/bin/vllm-serve /usr/local/bin/vllm-serve

# Install FlashInfer runtime (cu126 index)
RUN python3.12 -m pip install --no-cache-dir \
    flashinfer-python==0.6.8.post1 \
    --extra-index-url https://flashinfer.ai/whl/cu126

WORKDIR /workspace

EXPOSE 8000

ENTRYPOINT ["python3", "-m", "vllm.entrypoints.openai.api_server"]
