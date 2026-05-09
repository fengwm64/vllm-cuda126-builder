# vLLM CUDA 12.6 Docker Builder

从源码编译 vLLM wheel 并构建最小 OpenAI API server 镜像，基于 CUDA 12.6，兼容 CUDA 12.6 ~ 12.9 驱动。

## 为什么需要这个？

最新 vLLM (v0.20.1+) 的预编译二进制需要 **CUDA 12.9+**，但很多实验室服务器的 CUDA 驱动版本较低（如 12.7）。本项目从源码编译 vLLM，使用 CUDA 12.6 工具链，利用 NVIDIA 驱动的前向兼容性在 CUDA 12.7 上运行。

## 快速开始

### 方式一：一键构建（推荐）

```bash
git clone https://github.com/fengwm64/vllm-cuda126-builder.git
cd vllm-cuda126-builder

# 构建 wheel + 最小 runtime 镜像
./build.sh --version=v0.20.1 --arch="8.0 8.6" --jobs=$(nproc)
```

产物：
- `wheels/vllm-*.whl` — vLLM pip 包（可复用、可分发）
- `vllm-openai:v0.20.1` — 最小 OpenAI API server 镜像

### 方式二：分步构建

```bash
# 1. 只构建 wheel
./build.sh --wheel-only --version=v0.20.1

# 2. 用已有 wheel 构建 runtime 镜像
./build.sh --runtime-only --version=v0.20.1
```

### 方式三：手动构建

```bash
# 1. 编译并导出 wheel
DOCKER_BUILDKIT=1 docker build -f Dockerfile.builder \
  --build-arg VLLM_VERSION=v0.20.1 \
  --build-arg TORCH_CUDA_ARCH_LIST="8.0 8.6" \
  --build-arg MAX_JOBS=$(nproc) \
  --output type=local,dest=./wheels .

# 2. 构建最小 runtime 镜像
docker build -f Dockerfile.runtime \
  --build-arg VLLM_WHEEL=wheels/vllm-0.20.1-cp312-cp312-linux_x86_64.whl \
  -t vllm-openai:v0.20.1 .
```

## 运行

```bash
docker run --gpus all -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm-openai:v0.20.1 \
  --model meta-llama/Llama-3-8B-Instruct \
  --max-model-len 4096
```

## 推送到 ghcr.io（可选）

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <your-username> --password-stdin
docker tag vllm-openai:v0.20.1 ghcr.io/<your-username>/vllm-openai:v0.20.1-cu126
docker push ghcr.io/<your-username>/vllm-openai:v0.20.1-cu126
```

## GPU 架构参考

| GPU | SM 版本 | 架构 |
|-----|---------|------|
| RTX 2080, T4 | 7.5 | Turing |
| A100, A6000 | 8.0 | Ampere |
| RTX 3090, RTX 3080 | 8.6 | Ampere |
| RTX 4090, L40 | 8.9 | Ada Lovelace |

如果你有多代 GPU，可以设置 `--arch="7.5 8.0 8.6 8.9"`，但编译时间会更长。

## 项目结构

```
├── build.sh            # 一键构建脚本
├── Dockerfile.builder  # 编译阶段：从源码构建 vLLM wheel
├── Dockerfile.runtime  # 运行阶段：最小 OpenAI API server 镜像
└── wheels/             # 导出的 wheel 文件（构建后生成）
```

## 注意事项

- 镜像基于 `nvidia/cuda:12.6.0`，需要 NVIDIA Container Toolkit 支持
- 此镜像兼容 CUDA 12.6 ~ 12.9 的驱动版本
- `--jobs` 建议设为 CPU 核心数，加速编译
- wheel 文件可跨机器复用，只需在目标机器上构建 runtime 镜像
