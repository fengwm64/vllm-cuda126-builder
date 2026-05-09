# vLLM CUDA 12.6 Docker Builder

从源码编译 vLLM Docker 镜像，基于 CUDA 12.6，兼容 CUDA 12.6 ~ 12.9 驱动。

## 为什么需要这个？

最新 vLLM (v0.20.1+) 的预编译二进制需要 **CUDA 12.9+**，但很多实验室服务器的 CUDA 驱动版本较低（如 12.7）。本项目从源码编译 vLLM，使用 CUDA 12.6 工具链，利用 NVIDIA 驱动的前向兼容性在 CUDA 12.7 上运行。

## 快速开始（推荐：本地构建 + push 到 ghcr.io）

### 1. 在服务器上构建镜像

```bash
git clone https://github.com/fengwm64/vllm-cuda126-builder.git
cd vllm-cuda126-builder

docker build \
  --build-arg VLLM_VERSION=v0.20.1 \
  --build-arg TORCH_CUDA_ARCH_LIST="8.0 8.6" \
  --build-arg MAX_JOBS=$(nproc) \
  -t vllm-cu126:v0.20.1 .
```

首次构建约 1-3 小时（取决于 CPU 核心数）。

### 2. 推送到 ghcr.io（可选，方便其他机器拉取）

```bash
# 登录 GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u <your-username> --password-stdin

# 打标签
docker tag vllm-cu126:v0.20.1 ghcr.io/<your-username>/vllm:v0.20.1-cu126

# 推送
docker push ghcr.io/<your-username>/vllm:v0.20.1-cu126
```

### 3. 其他机器拉取运行

```bash
docker pull ghcr.io/<your-username>/vllm:v0.20.1-cu126

docker run --gpus all -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  ghcr.io/<your-username>/vllm:v0.20.1-cu126 \
  --model meta-llama/Llama-3-8B-Instruct \
  --max-model-len 4096
```

## GPU 架构参考

| GPU | SM 版本 | 架构 |
|-----|---------|------|
| RTX 2080, T4 | 7.5 | Turing |
| A100, A6000 | 8.0 | Ampere |
| RTX 3090, RTX 3080 | 8.6 | Ampere |
| RTX 4090, L40 | 8.9 | Ada Lovelace |

如果你有多代 GPU，可以设置 `TORCH_CUDA_ARCH_LIST="7.5 8.0 8.6 8.9"`，但编译时间会更长。

## GitHub Actions（可选）

`.github/workflows/build-vllm-cuda126.yml` 提供了 GitHub Actions 自动构建。

**注意：** GitHub Actions 免费 runner 仅有 2 vCPU，编译 vLLM 需要 5-6 小时，接近平台 6 小时超时限制。建议优先使用本地构建。

## 为什么用 CUDA 12.6 而不是 12.7？

PyTorch 2.11.0 只发布 cu126/cu128/cu130 的预编译 wheel，没有 cu127。CUDA 12.6 的 wheel 在 CUDA 12.7 驱动上可以正常运行（NVIDIA 驱动前向兼容）。

## 注意事项

- 镜像基于 `nvidia/cuda:12.6.0`，需要 NVIDIA Container Toolkit 支持
- 此镜像兼容 CUDA 12.6 ~ 12.9 的驱动版本
- `MAX_JOBS` 建议设为 CPU 核心数，加速编译
