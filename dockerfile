# ================================================================
# 📦 0.1 基础镜像：pytorch:2.7.0-cuda12.8-cudnn9-devel
# ================================================================
FROM pytorch/pytorch:2.7.0-cuda12.8-cudnn9-devel

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
    apt-get install -y --no-install-recommends \
        wget git git-lfs curl procps \
        libgl1 libgl1-mesa-glx libglvnd0 \
        libglib2.0-0 libsm6 libxrender1 libxext6 \
        xvfb build-essential cmake bc \
        libgoogle-perftools-dev \
        apt-transport-https htop nano bsdmainutils \
        lsb-release software-properties-common && \
    echo -e "✅ 基础系统依赖安装完成\n" && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ===============================
# ✅ 验证环境完整性
# ===============================
RUN echo "🔍 验证 CUDA 编译器版本：" && nvcc --version && \
    python3 -c "import torch; print('✔️ torch:', torch.__version__, '| CUDA:', torch.version.cuda)"

# ===============================
# 🚩 使用 Conda 降级 SQLite 以保持兼容
# ===============================
RUN echo "🔧 降级 Conda 内 SQLite 到 3.42.0..." && \
    conda install -y sqlite=3.42 && \
    echo "✅ SQLite 版本：" && sqlite3 --version

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
# 🚩 检查 Python 环境完整性
# ===============================
RUN echo "🔎 Python 环境自检开始..." && \
    python3 --version && \
    pip3 --version && \
    python3 -m venv --help > /dev/null && \
    echo "✅ Python、pip 和 venv 已正确安装并通过检查" || \
    echo "⚠️ Python 环境完整性出现问题，请排查！"

# ===============================
# 🚩 容器启动入口
# ===============================
ENTRYPOINT ["/app/run.sh"]
