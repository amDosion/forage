FROM pytorch/pytorch:2.6.0-cuda12.6-cudnn9-devel

# ===============================
# 🚩 设置时区（上海）
# ===============================
ENV TZ=Asia/Shanghai
RUN echo "🔧 正在设置时区为 $TZ..." && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    echo "✅ 时区已成功设置：$(date)"

# ===============================
# 🚩 安装系统依赖 & CUDA 工具链
# ===============================
RUN echo -e "🔧 开始安装系统依赖和 CUDA 开发工具...\n" && \
    apt-get update && apt-get upgrade -y && \
    apt-get install -y jq && \
    apt-get install -y --no-install-recommends \
        wget git git-lfs curl procps \
        libgl1 libgl1-mesa-glx libglvnd0 \
        libglib2.0-0 libsm6 libxrender1 libxext6 \
        xvfb build-essential cmake bc \
        libgoogle-perftools-dev \
        apt-transport-https htop nano bsdmainutils bsdextrautils \
        lsb-release software-properties-common && \
    # 添加 jq（用于处理 JSON）
    apt-get install -y jq && \
    echo -e "✅ 基础系统依赖安装完成\n" && \
    echo -e "🔧 正在安装 CUDA 12.6 工具链和数学库...\n" && \
    apt-get install -y --no-install-recommends \
        cuda-compiler-12-6 libcublas-12-6 libcublas-dev-12-6 && \
    echo -e "✅ CUDA 工具链安装完成\n" && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ===============================
# 🚩 安装 TensorRT（匹配 CUDA 12.6）
# ===============================
RUN echo -e "🔧 配置 NVIDIA CUDA 仓库...\n" && \
    CODENAME="ubuntu2204" && \
    rm -f /etc/apt/sources.list.d/cuda-ubuntu2204-x86_64.list && \
    mkdir -p /usr/share/keyrings && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/${CODENAME}/x86_64/cuda-archive-keyring.gpg \
      | gpg --batch --yes --dearmor -o /usr/share/keyrings/cuda-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/${CODENAME}/x86_64/ /" \
      > /etc/apt/sources.list.d/cuda.list && \
    echo -e "📥 仓库配置完成，准备安装 TensorRT...\n" && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libnvinfer8 libnvinfer-plugin8 libnvparsers8 \
        libnvonnxparsers8 libnvinfer-bin python3-libnvinfer && \
    echo -e "✅ TensorRT 安装完成\n" && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ===============================
# ✅ 验证环境完整性
# ===============================
RUN echo "🔍 验证 CUDA 编译器版本：" && nvcc --version && \
    echo "🔍 检查 TensorRT 相关包：" && dpkg -l | grep -E "libnvinfer|libnvparsers" && \
    python3 -c "import torch; print('✔️ torch:', torch.__version__, '| CUDA:', torch.version.cuda)"

# ===============================
# 🚩 创建非 root 用户 webui
# ===============================
RUN echo "🔧 正在创建非 root 用户 webui..." && \
    useradd -m webui && \
    echo "✅ 用户 webui 创建完成"

# ===============================
# 🚩 设置工作目录 + 拷贝启动脚本
# ===============================
WORKDIR /app
COPY run.sh /app/run.sh
RUN echo "🔧 正在创建工作目录并设置权限..." && \
    chmod +x /app/run.sh && \
    mkdir -p /app/webui && \
    chown -R webui:webui /app/webui && \
    echo "✅ 工作目录设置完成"

# ===============================
# 🚩 切换至非 root 用户 webui
# ===============================
USER webui
WORKDIR /app/webui
RUN echo "✅ 已成功切换至用户：$(whoami)" && \
    echo "✅ 当前工作目录为：$(pwd)"

# ===============================
# 🚩 确保用户能够访问和执行 /app/run.sh
# ===============================
RUN echo "🔧 确保用户 webui 可以访问 /app/run.sh" && \
    chmod +x /app/run.sh && \
    chown webui:webui /app/run.sh

# ===============================
# 🚩 设置容器启动入口
# ===============================
ENTRYPOINT ["/app/run.sh"]
