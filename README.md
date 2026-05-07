# vLLM CUDA 12.6 Docker Builder

通过 GitHub Actions 自动编译 vLLM Docker 镜像，基于 CUDA 12.6，兼容 CUDA 12.7 驱动。

## 为什么需要这个？

最新 vLLM (v0.20.1+) 的预编译二进制需要 **CUDA 12.9+**，但很多实验室服务器的 CUDA 驱动版本较低（如 12.7）。本项目通过 GitHub Actions 从源码编译 vLLM，使用 CUDA 12.6 工具链，利用 NVIDIA 驱动的前向兼容性在 CUDA 12.7 上运行。

## 快速开始

### 1. Fork 或 clone 本仓库

### 2. 触发构建

在 GitHub 仓库页面，进入 **Actions** → **Build vLLM Docker Image (CUDA 12.6)** → **Run workflow**，填写参数：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `vllm_version` | `v0.20.1` | vLLM 版本标签 |
| `torch_cuda_arch_list` | `8.0 8.6` | GPU 架构（SM 8.0=A100, SM 8.6=RTX 3090） |
| `max_jobs` | `4` | 并行编译任务数 |

### 3. 拉取镜像

构建完成后（约 1-3 小时），在服务器上拉取：

```bash
docker pull ghcr.io/<your-username>/vllm:v0.20.1-cu126
```

### 4. 运行

```bash
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

如果你有多代 GPU，可以设置 `torch_cuda_arch_list="7.5 8.0 8.6 8.9"`，但编译时间会更长。

## 本地构建（不使用 GitHub Actions）

```bash
docker build \
  --build-arg VLLM_VERSION=v0.20.1 \
  --build-arg TORCH_CUDA_ARCH_LIST="8.0 8.6" \
  --build-arg MAX_JOBS=4 \
  -t vllm-cu126:v0.20.1 .
```

## 注意事项

- 首次构建需要 1-3 小时（vLLM 包含大量 CUDA 内核需要编译）
- GitHub Actions 使用 Docker layer cache，后续构建会快很多
- 镜像基于 `nvidia/cuda:12.6.0`，需要 NVIDIA Container Toolkit 支持
- 此镜像兼容 CUDA 12.6 ~ 12.9 的驱动版本
