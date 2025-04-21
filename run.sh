#!/bin/bash

set -e
set -o pipefail

# ==================================================
# 日志配置
# ==================================================
LOG_FILE="/app/webui/launch.log"
# 若日志文件存在则清空内容
if [[ -f "$LOG_FILE" ]]; then
  echo "" > "$LOG_FILE"
fi
# 确保日志目录存在
mkdir -p "$(dirname "$LOG_FILE")"
# 将所有标准输出和错误输出重定向到文件和控制台
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================================="
echo "🚀 [0] 启动脚本 Stable Diffusion WebUI"
echo "=================================================="

# ---------------------------------------------------
# 系统环境自检
# ---------------------------------------------------
echo "🛠️  [0.5] 系统环境自检..."

# Python 检查
if command -v python3 &>/dev/null; then
  echo "✅ Python3 版本: $(python3 --version)"
else
  echo "❌ 未找到 Python3，脚本将无法运行！"
  exit 1
fi

# pip 检查
if command -v pip3 &>/dev/null; then
  echo "✅ pip3 版本: $(pip3 --version)"
else
  echo "❌ pip3 未安装！请在 Dockerfile 中添加 python3-pip"
  exit 1
fi

# CUDA & GPU 检查（使用 nvidia-smi 原生输出）
if command -v nvidia-smi &>/dev/null; then
  echo "✅ nvidia-smi 检测成功，GPU 信息如下："
  echo "--------------------------------------------------"
  nvidia-smi
  echo "--------------------------------------------------"
else
  echo "⚠️ 未检测到 nvidia-smi（可能无 GPU 或驱动未安装）"
fi

# 容器检测
if [ -f "/.dockerenv" ]; then
  echo "📦 正在容器中运行"
else
  echo "🖥️ 非容器环境"
fi

echo "👤 当前用户: $(whoami)"

if [ -w "/app/webui" ]; then
  echo "✅ /app/webui 可写"
else
  echo "❌ /app/webui 不可写，可能会导致运行失败"
  exit 1
fi

echo "✅ 系统环境自检通过"

# ---------------------------------------------------
# 环境变量设置
# ---------------------------------------------------
echo "🔧 [1] 解析 UI 与 ARGS 环境变量..."
UI="${UI:-forge}"
ARGS="${ARGS:---xformers --api --listen --enable-insecure-extension-access --theme dark}"
echo "🧠 UI=${UI}"
echo "🧠 ARGS=${ARGS}"

echo "🔧 [2] 解析下载开关环境变量 (默认全部启用)..."
# 解析全局下载开关
ENABLE_DOWNLOAD_ALL="${ENABLE_DOWNLOAD:-true}"

# 解析独立的模型和资源类别开关
ENABLE_DOWNLOAD_EXTS="${ENABLE_DOWNLOAD_EXTS:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_MODEL_SD15="${ENABLE_DOWNLOAD_MODEL_SD15:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_MODEL_SDXL="${ENABLE_DOWNLOAD_MODEL_SDXL:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_MODEL_FLUX="${ENABLE_DOWNLOAD_MODEL_FLUX:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_VAE_FLUX="${ENABLE_DOWNLOAD_VAE_FLUX:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_TE_FLUX="${ENABLE_DOWNLOAD_TE_FLUX:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_CNET_SD15="${ENABLE_DOWNLOAD_CNET_SD15:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_CNET_SDXL="${ENABLE_DOWNLOAD_CNET_SDXL:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_CNET_FLUX="${ENABLE_DOWNLOAD_CNET_FLUX:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_VAE="${ENABLE_DOWNLOAD_VAE:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_LORAS="${ENABLE_DOWNLOAD_LORAS:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_EMBEDDINGS="${ENABLE_DOWNLOAD_EMBEDDINGS:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_UPSCALERS="${ENABLE_DOWNLOAD_UPSCALERS:-$ENABLE_DOWNLOAD_ALL}"
ENABLE_DOWNLOAD_TE="${ENABLE_DOWNLOAD_TE:-$ENABLE_DOWNLOAD_ALL}"  # 为 text_encoder 添加独立的开关
# 解析独立的镜像使用开关
USE_HF_MIRROR="${USE_HF_MIRROR:-false}" # 控制是否使用 hf-mirror.com
USE_GIT_MIRROR="${USE_GIT_MIRROR:-false}" # 控制是否使用 gitcode.net

echo "  - 下载总开关        (ENABLE_DOWNLOAD_ALL): ${ENABLE_DOWNLOAD_ALL}"
echo "  - 下载 Extensions   (ENABLE_DOWNLOAD_EXTS): ${ENABLE_DOWNLOAD_EXTS}"
echo "  - 下载 Checkpoint SD1.5 (ENABLE_DOWNLOAD_MODEL_SD15): ${ENABLE_DOWNLOAD_MODEL_SD15}"
echo "  - 下载 Checkpoint SDXL  (ENABLE_DOWNLOAD_MODEL_SDXL): ${ENABLE_DOWNLOAD_MODEL_SDXL}"
echo "  - 下载 Checkpoint FLUX (ENABLE_DOWNLOAD_MODEL_FLUX): ${ENABLE_DOWNLOAD_MODEL_FLUX}"
echo "  - 下载 VAE FLUX       (ENABLE_DOWNLOAD_VAE_FLUX): ${ENABLE_DOWNLOAD_VAE_FLUX}"
echo "  - 下载 TE FLUX        (ENABLE_DOWNLOAD_TE_FLUX): ${ENABLE_DOWNLOAD_TE_FLUX}"
echo "  - 下载 ControlNet SD1.5 (ENABLE_DOWNLOAD_CNET_SD15): ${ENABLE_DOWNLOAD_CNET_SD15}"
echo "  - 下载 ControlNet SDXL  (ENABLE_DOWNLOAD_CNET_SDXL): ${ENABLE_DOWNLOAD_CNET_SDXL}"
echo "  - 下载 ControlNet FLUX  (ENABLE_DOWNLOAD_CNET_FLUX): ${ENABLE_DOWNLOAD_CNET_FLUX}"
echo "  - 下载 通用 VAE     (ENABLE_DOWNLOAD_VAE): ${ENABLE_DOWNLOAD_VAE}"
echo "  - 下载 LoRAs/LyCORIS (ENABLE_DOWNLOAD_LORAS): ${ENABLE_DOWNLOAD_LORAS}"
echo "  - 下载 Embeddings   (ENABLE_DOWNLOAD_EMBEDDINGS): ${ENABLE_DOWNLOAD_EMBEDDINGS}"
echo "  - 下载 Upscalers    (ENABLE_DOWNLOAD_UPSCALERS): ${ENABLE_DOWNLOAD_UPSCALERS}"
echo "  - 下载 Text Encoders   (ENABLE_DOWNLOAD_TE): ${ENABLE_DOWNLOAD_TE}"  # 输出 Text Encoder 的下载开关
echo "  - 是否使用 HF 镜像  (USE_HF_MIRROR): ${USE_HF_MIRROR}" # (hf-mirror.com)
echo "  - 是否使用 Git 镜像 (USE_GIT_MIRROR): ${USE_GIT_MIRROR}" # (gitcode.net)


# 预定义镜像地址 (如果需要可以从环境变量读取，但简单起见先硬编码)
HF_MIRROR_URL="https://hf-mirror.com"
GIT_MIRROR_URL="https://gitcode.net" # 使用 https

export NO_TCMALLOC=1
export PIP_EXTRA_INDEX_URL="https://download.pytorch.org/whl/cu126"

# ---------------------------------------------------
# 设置 Git 源路径
# ---------------------------------------------------
echo "🔧 [3] 设置仓库路径与 Git 源..."
if [ "$UI" = "auto" ]; then
  TARGET_DIR="/app/webui/sd-webui"
  REPO="https://github.com/AUTOMATIC1111/stable-diffusion-webui.git"
elif [ "$UI" = "forge" ]; then
  TARGET_DIR="/app/webui/sd-webui-forge"
  REPO="https://github.com/amDosion/stable-diffusion-webui-fastforge.git"
else
  echo "❌ Unknown UI: $UI"
  exit 1
fi
echo "📁 目标目录: $TARGET_DIR"
echo "🌐 GIT 源: $REPO"

# ---------------------------------------------------
# 克隆/更新仓库
# ---------------------------------------------------
if [ -d "$TARGET_DIR/.git" ]; then
  echo "🔁 仓库已存在，执行 git pull..."
  git -C "$TARGET_DIR" pull --ff-only || echo "⚠️ Git pull failed"
else
  echo "📥 Clone 仓库..."
  git clone "$REPO" "$TARGET_DIR"
  chmod +x "$TARGET_DIR/webui.sh"
fi

# 创建 repositories 目录（在 $TARGET_DIR 内）
REPOSITORIES_DIR="$TARGET_DIR/repositories"
mkdir -p "$REPOSITORIES_DIR" || echo "⚠️ 创建 repositories 目录失败，请检查权限。"

# 克隆 stable-diffusion-webui-assets 仓库（如果尚未克隆）
REPO_ASSETS_DIR="$REPOSITORIES_DIR/stable-diffusion-webui-assets"
if [ ! -d "$REPO_ASSETS_DIR" ]; then
  echo "🚀 克隆 stable-diffusion-webui-assets 仓库..."
  git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui-assets.git "$REPO_ASSETS_DIR" || echo "❌ 克隆 stable-diffusion-webui-assets 仓库失败"
else
  echo "✅ stable-diffusion-webui-assets 仓库已经存在，跳过克隆。"
fi

# 克隆 huggingface_guess 仓库（如果尚未克隆）
REPO_HUGGINGFACE_GUESS_DIR="$REPOSITORIES_DIR/huggingface_guess"
if [ ! -d "$REPO_HUGGINGFACE_GUESS_DIR" ]; then
  echo "🚀 克隆 huggingface_guess 仓库..."
  git clone https://github.com/lllyasviel/huggingface_guess.git "$REPO_HUGGINGFACE_GUESS_DIR" || echo "❌ 克隆 huggingface_guess 仓库失败"
else
  echo "✅ huggingface_guess 仓库已经存在，跳过克隆。"
fi

# 克隆 BLIP 仓库（如果尚未克隆）
REPO_BLIP_DIR="$REPOSITORIES_DIR/BLIP"
if [ ! -d "$REPO_BLIP_DIR" ]; then
  echo "🚀 克隆 BLIP 仓库..."
  git clone https://github.com/salesforce/BLIP.git "$REPO_BLIP_DIR" || echo "❌ 克隆 BLIP 仓库失败"
else
  echo "✅ BLIP 仓库已经存在，跳过克隆。"
fi

# 克隆 google_blockly_prototypes 仓库（如果尚未克隆）
REPO_GOOGLE_BLOCKLY_DIR="$REPOSITORIES_DIR/google_blockly_prototypes"
if [ ! -d "$REPO_GOOGLE_BLOCKLY_DIR" ]; then
  echo "🚀 克隆 google_blockly_prototypes 仓库..."
  git clone https://github.com/lllyasviel/google_blockly_prototypes.git "$REPO_GOOGLE_BLOCKLY_DIR" || echo "❌ 克隆 google_blockly_prototypes 仓库失败"
else
  echo "✅ google_blockly_prototypes 仓库已经存在，跳过克隆。"
fi

# ---------------------------------------------------
# requirements_versions.txt 修复
# ---------------------------------------------------
echo "🔧 [5] 补丁修正 requirements_versions.txt..."
REQ_FILE="$TARGET_DIR/requirements_versions.txt"
touch "$REQ_FILE"

# 添加或替换某个依赖版本
add_or_replace_requirement() {
  local package="$1"
  local version="$2"
  if grep -q "^$package==" "$REQ_FILE"; then
    echo "🔁 替换: $package==... → $package==$version"
    sed -i "s|^$package==.*|$package==$version|" "$REQ_FILE"
  else
    echo "➕ 追加: $package==$version"
    echo "$package==$version" >> "$REQ_FILE"
  fi
}

# 推荐依赖版本（将统一写入或替换）
add_or_replace_requirement "xformers" "0.0.29.post3"
add_or_replace_requirement "diffusers" "0.31.0"
add_or_replace_requirement "transformers" "4.46.1"
add_or_replace_requirement "torchdiffeq" "0.2.3"
add_or_replace_requirement "torchsde" "0.2.6"
add_or_replace_requirement "protobuf" "4.25.3"
add_or_replace_requirement "pydantic" "2.6.4"
add_or_replace_requirement "open-clip-torch" "2.24.0"
add_or_replace_requirement "GitPython" "3.1.41"

# 🧹 清理注释和空行，保持纯净格式
echo "🧹 清理注释内容..."
CLEANED_REQ_FILE="${REQ_FILE}.cleaned"
sed 's/#.*//' "$REQ_FILE" | sed '/^\s*$/d' > "$CLEANED_REQ_FILE"
mv "$CLEANED_REQ_FILE" "$REQ_FILE"

# ✅ 输出最终依赖列表
echo "📄 最终依赖列表如下："
cat "$REQ_FILE"

# ---------------------------------------------------
# Python 虚拟环境设置与依赖安装
# ---------------------------------------------------
VENV_DIR="$TARGET_DIR/venv" # 定义虚拟环境目录

echo "🐍 [6] 设置 Python 虚拟环境 ($VENV_DIR)..."

# 检查虚拟环境是否已正确创建
if [ ! -d "$VENV_DIR" ]; then
  echo "  - 虚拟环境不存在，正在创建..."
  # 使用 Python 创建虚拟环境
  python3.11 -m venv "$VENV_DIR" || { echo "❌ 创建虚拟环境失败，请检查 python3-venv 是否安装"; exit 1; }
  echo "  - 虚拟环境创建成功。"
else
  echo "  - 虚拟环境已存在于 $VENV_DIR。"
fi

echo "  - 激活虚拟环境..."
source "$VENV_DIR/bin/activate" || { echo "❌ 激活虚拟环境失败"; exit 1; }

# 确认 venv 内的 Python 和 pip
echo "  - 当前 Python: $(which python) (应指向 $VENV_DIR/bin/python)"
echo "  - 当前 pip: $(which pip) (应指向 $VENV_DIR/bin/pip)"

# 升级 pip
echo "📥 升级 pip..."
pip install --upgrade pip | tee -a "$LOG_FILE"

# 安装依赖
echo "📥 安装主依赖 requirements_versions.txt ..."
DEPENDENCIES_INFO_URL="https://raw.githubusercontent.com/amDosion/forage/main/dependencies_info.json"
DEPENDENCIES_INFO=$(curl -s "$DEPENDENCIES_INFO_URL")
INSTALLED_DEPENDENCIES_FILE="$TARGET_DIR/installed_dependencies.json"  # 安装记录存放路径

# 修复 Windows 格式行尾
sed -i 's/\r//' "$REQ_FILE"

# 如果安装依赖的记录文件不存在，创建一个空的 JSON 文件
if [[ ! -f "$INSTALLED_DEPENDENCIES_FILE" ]]; then
  echo "{}" > "$INSTALLED_DEPENDENCIES_FILE"
  echo "✅ 创建了空的 installed_dependencies.json 文件"
fi

# 确保 JSON 文件格式正确
if ! jq empty "$INSTALLED_DEPENDENCIES_FILE" > /dev/null 2>&1; then
  echo "❌ installed_dependencies.json 格式错误，修复 JSON 格式"
  echo "{}" > "$INSTALLED_DEPENDENCIES_FILE"
fi

# 安装依赖
while IFS= read -r line || [[ -n "$line" ]]; do
  line=$(echo "$line" | sed 's/#.*//' | xargs)
  [[ -z "$line" ]] && continue

  # 判断是否包含版本
  if [[ "$line" == *"=="* ]]; then
    package_name=$(echo "$line" | cut -d'=' -f1 | xargs)
    package_version=$(echo "$line" | cut -d'=' -f3 | xargs)
  else
    package_name=$(echo "$line" | xargs)
    package_version=$(echo "$DEPENDENCIES_INFO" | jq -r --arg pkg "$package_name" '.[$pkg].version // empty')

    if [[ -z "$package_version" || "$package_version" == "null" ]]; then
      echo "⚠️ 警告: 未指定 $package_name 的版本，且 JSON 中也未找到版本信息，跳过"
      continue
    else
      echo "ℹ️ 来自 JSON 的版本补全：$package_name==$package_version"
    fi
  fi

  # 检查是否已安装该包及版本，首先检查 JSON 文件记录
  installed_version=$(jq -r --arg pkg "$package_name" '.[$pkg].version // empty' "$INSTALLED_DEPENDENCIES_FILE")

  if [[ "$installed_version" == "$package_version" ]]; then
    echo "✅ $package_name==$package_version 已安装，跳过安装"
  else
    # 获取描述信息
    description=$(echo "$DEPENDENCIES_INFO" | jq -r --arg pkg "$package_name" '.[$pkg].description // empty')
    [[ -n "$description" ]] && echo "📘 说明: $description" || echo "⚠️ 警告: 未找到 $package_name 的描述信息，继续执行..."

    echo "📦 安装 ${package_name}==${package_version}"
    pip install "${package_name}==${package_version}" --extra-index-url "$PIP_EXTRA_INDEX_URL" 2>&1 >> "$LOG_FILE"

    # 记录安装成功，并将新记录追加到 JSON 文件
    jq --arg pkg "$package_name" --arg version "$package_version" \
      '. + {($pkg): {"version": $version, "installed": true}}' "$INSTALLED_DEPENDENCIES_FILE" > "$INSTALLED_DEPENDENCIES_FILE.tmp" && mv "$INSTALLED_DEPENDENCIES_FILE.tmp" "$INSTALLED_DEPENDENCIES_FILE" \
      || echo "❌ 安装失败: $package_name==$package_version"
  fi
done < "$REQ_FILE"

# 更新额外依赖的记录方式

update_installed_dependencies() {
  package_name=$1
  package_version=$2

  # 检查依赖是否已存在
  if jq -e ".[$package_name] == null" "$INSTALLED_DEPENDENCIES_FILE"; then
    jq --arg pkg "$package_name" --arg version "$package_version" \
      '. + {($pkg): {"version": $version, "installed": true}}' "$INSTALLED_DEPENDENCIES_FILE" > "$INSTALLED_DEPENDENCIES_FILE.tmp" && mv "$INSTALLED_DEPENDENCIES_FILE.tmp" "$INSTALLED_DEPENDENCIES_FILE"
  else
    echo "✅ 依赖 $package_name 已记录，跳过安装"
  fi
}

# 安装 huggingface-cli 工具
if pip show huggingface-hub | grep -q "Version"; then
  echo "✅ huggingface_hub[cli] 已安装，跳过安装"
else
  echo "📦 安装 huggingface_hub[cli]"
  pip install --upgrade "huggingface_hub[cli]" | tee -a "$LOG_FILE"
fi

# 自动检查并安装缺失的库
check_and_install_package() {
    local package=$1
    local version=$2

    # 检查库是否已经安装
    if ! python -c "import $package" >/dev/null 2>&1; then
        echo "❌ 缺少库: $package，尝试安装..."
        
        # 对于 pillow，确保它的版本不会被卸载
        if [[ "$package" == "pillow" ]]; then
            # 如果指定了版本号，安装指定版本的 Pillow
            if [[ -n "$version" ]]; then
                # 安装指定版本的 pillow，并确保其他版本不被安装
                pip install "$package==$version" --no-cache-dir && echo "✅ 库安装成功: $package==$version" || echo "❌ 库安装失败: $package==$version"
            else
                # 如果没有指定版本，则只安装 pillow 并跳过升级
                pip install "$package" --no-cache-dir && echo "✅ 库安装成功: $package" || echo "❌ 库安装失败: $package"
            fi
        else
            # 对于其他包，正常安装
            if [[ -n "$version" ]]; then
                pip install "$package==$version" --no-cache-dir && echo "✅ 库安装成功: $package==$version" || echo "❌ 库安装失败: $package==$version"
            else
                pip install "$package" --no-cache-dir && echo "✅ 库安装成功: $package" || echo "❌ 库安装失败: $package"
            fi
        fi
    else
        echo "✅ 库已安装: $package"
    fi
}

# 安装 Pillow 确保版本与 blendmodes 和 gradio 兼容
check_and_install_package "pillow" "9.5.0"  # 安装 Pillow 9.5.0，兼容 blendmodes 和 gradio

# 安装缺失的依赖
check_and_install_package "sentencepiece"
check_and_install_package "insightface"
check_and_install_package "onnx"
check_and_install_package "onnxruntime"
check_and_install_package "send2trash"
check_and_install_package "beautifulsoup4"
check_and_install_package "ZipUnicode"
check_and_install_package "timm"
check_and_install_package "fastapi"
check_and_install_package "huggingface_guess"
check_and_install_package "python-dotenv"
check_and_install_package "open_clip_torch"

# ---------------------------------------------------
# 安装 TensorFlow
# ---------------------------------------------------
echo "🔍 正在检测 CPU 支持情况..."

CPU_VENDOR=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
AVX2_SUPPORTED=$(grep -m 1 avx2 /proc/cpuinfo || true)

echo "🧠 检测到 CPU: ${CPU_VENDOR}"

if [[ -n "$AVX2_SUPPORTED" ]]; then
  echo "✅ 检测到 AVX2 指令集"

  echo "🔍 检测并安装 TensorFlow（GPU 优先）..."
  pip uninstall -y tensorflow tensorflow-cpu || true

  if command -v nvidia-smi &>/dev/null; then
    echo "🧠 检测到 GPU，尝试安装 TensorFlow GPU 版本（支持 Python 3.11）"
    pip install tf-nightly | tee -a "$LOG_FILE"  # 使用 tf-nightly 替代 tensorflow==2.19.0

  else
    echo "🧠 未检测到 GPU，安装 tf-nightly（兼容 Python 3.11）"
    pip install tf-nightly | tee -a "$LOG_FILE"  # 使用 tf-nightly 替代 tensorflow-cpu==2.19.0
  fi

  echo "🧪 验证 TensorFlow 是否识别 GPU："
  python3 -c "
import tensorflow as tf
gpus = tf.config.list_physical_devices('GPU')
if gpus:
    print('✅ 可用 GPU:', gpus)
else:
    print('⚠️ 没有检测到可用的 GPU')
exit(0)" || echo "⚠️ TensorFlow 未能识别 GPU，请确认驱动与 CUDA 库完整"

else
  echo "⚠️ 未检测到 AVX2 → fallback 到安装 tf-nightly（兼容 Python 3.11）"
  pip install tf-nightly  # 使用 tf-nightly 替代 tensorflow-cpu==2.19.0
fi

# ---------------------------------------------------
# 安装完成日志
# ---------------------------------------------------
echo "📦 venv 安装完成 ✅"

# ---------------------------------------------------
# 创建目录
# ---------------------------------------------------
echo "📁 [7] 初始化项目目录结构..."

# 检查目录是否存在，如果不存在则创建
for dir in "$TARGET_DIR/extensions" "$TARGET_DIR/models" "$TARGET_DIR/models/ControlNet" "$TARGET_DIR/outputs"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "目录创建成功：$dir"
    else
        echo "目录已存在：$dir"
    fi
done

echo "目录结构已初始化：$TARGET_DIR"

# ---------------------------------------------------
# 网络测试
# ---------------------------------------------------
echo "🌐 [8] 网络连通性测试..."
if curl -s --connect-timeout 3 https://www.google.com > /dev/null; then
  NET_OK=true
  echo "✅ 网络连通 (Google 可访问)"
else
  NET_OK=false
  echo "⚠️ 无法访问 Google，部分资源或插件可能无法下载"
fi

# ---------------------------------------------------
# 插件黑名单
# ---------------------------------------------------
SKIP_LIST=(
  "extensions/stable-diffusion-aws-extension"
  "extensions/sd_dreambooth_extension"
  "extensions/stable-diffusion-webui-aesthetic-image-scorer"
)

should_skip() {
  local dir="$1"
  for skip in "${SKIP_LIST[@]}"; do
    [[ "$dir" == "$skip" ]] && return 0
  done
  return 1
}

# ==================================================
# 资源下载 (使用 resources.txt)
# ==================================================
echo "📦 [9] 处理资源下载 (基于 /app/webui/resources.txt 和下载开关)..."
RESOURCE_PATH="/app/webui/resources.txt" # 定义资源列表文件路径

# 检查资源文件是否存在，如果不存在则尝试下载默认版本
if [ ! -f "$RESOURCE_PATH" ]; then
  # 指定默认资源文件的 URL
  DEFAULT_RESOURCE_URL="https://raw.githubusercontent.com/chuan1127/SD-webui-forge/main/resources.txt"
  echo "  - 未找到本地 resources.txt，尝试从 ${DEFAULT_RESOURCE_URL} 下载..."
  # 使用 curl 下载，确保失败时不输出错误页面 (-f)，静默 (-s)，跟随重定向 (-L)
  curl -fsSL -o "$RESOURCE_PATH" "$DEFAULT_RESOURCE_URL"
  if [ $? -eq 0 ]; then
      echo "  - ✅ 默认 resources.txt 下载成功。"
  else
      echo "  - ❌ 下载默认 resources.txt 失败。请手动将资源文件放在 ${RESOURCE_PATH} 或检查网络/URL。"
      # 创建一个空文件以避免后续读取错误，但不会下载任何内容
      touch "$RESOURCE_PATH"
      echo "  - 已创建空的 resources.txt 文件以继续，但不会下载任何资源。"
  fi
else
  echo "  - ✅ 使用本地已存在的 resources.txt: ${RESOURCE_PATH}"
fi

# 定义函数：克隆或更新 Git 仓库 (支持独立 Git 镜像开关)
clone_or_update_repo() {
    # $1: 目标目录, $2: 原始仓库 URL
    local dir="$1" repo_original="$2"
    local dirname
    local repo_url # URL to be used for cloning/pulling

    dirname=$(basename "$dir")

    # 检查是否启用了 Git 镜像以及是否是 GitHub URL
    if [[ "$USE_GIT_MIRROR" == "true" && "$repo_original" == "https://github.com/"* ]]; then
        local git_mirror_host
        git_mirror_host=$(echo "$GIT_MIRROR_URL" | sed 's|https://||; s|http://||; s|/.*||')
        repo_url=$(echo "$repo_original" | sed "s|github.com|$git_mirror_host|")
        echo "    - 使用镜像转换 (Git): $repo_original -> $repo_url"
    else
        repo_url="$repo_original"
    fi

    # 检查扩展下载开关
    if [[ "$ENABLE_DOWNLOAD_EXTS" != "true" ]]; then
        if [ -d "$dir" ]; then
            echo "    - ⏭️ 跳过更新扩展/仓库 (ENABLE_DOWNLOAD_EXTS=false): $dirname"
        else
            echo "    - ⏭️ 跳过克隆扩展/仓库 (ENABLE_DOWNLOAD_EXTS=false): $dirname"
        fi
        return
    fi

    # 尝试更新或克隆
    if [ -d "$dir/.git" ]; then
        echo "    - 🔄 更新扩展/仓库: $dirname (from $repo_url)"
        (cd "$dir" && git pull --ff-only) || echo "      ⚠️ Git pull 失败: $dirname (可能存在本地修改或网络问题)"
    elif [ ! -d "$dir" ]; then
        echo "    - 📥 克隆扩展/仓库: $repo_url -> $dirname (完整克隆)"
        git clone --recursive "$repo_url" "$dir" || echo "      ❌ Git clone 失败: $dirname (检查 URL: $repo_url 和网络)"
    else
        echo "    - ✅ 目录已存在但非 Git 仓库，跳过 Git 操作: $dirname"
    fi  # ✅ 这里是必须的
}

# 定义函数：下载文件 (支持独立 HF 镜像开关)
download_with_progress() {
    # $1: 输出路径, $2: 原始 URL, $3: 资源类型描述, $4: 对应的下载开关变量值
    local output_path="$1" url_original="$2" type="$3" enabled_flag="$4"
    local filename
    local download_url # URL to be used for downloading

    filename=$(basename "$output_path")

    # 检查下载开关
    if [[ "$enabled_flag" != "true" ]]; then
        echo "    - ⏭️ 跳过下载 ${type} (开关 '$enabled_flag' != 'true'): $filename"
        return
    fi
    # 检查网络
    if [[ "$NET_OK" != "true" ]]; then
        echo "    - ❌ 跳过下载 ${type} (网络不通): $filename"
        return
    fi

    # 检查是否启用了 HF 镜像以及是否是 Hugging Face URL
    # 使用步骤 [2] 中定义的 HF_MIRROR_URL
    if [[ "$USE_HF_MIRROR" == "true" && "$url_original" == "https://huggingface.co/"* ]]; then
        # 替换 huggingface.co 为镜像地址
        download_url=$(echo "$url_original" | sed "s|https://huggingface.co|$HF_MIRROR_URL|")
        echo "    - 使用镜像转换 (HF): $url_original -> $download_url"
    else
        # 使用原始 URL
        download_url="$url_original"
    fi

    # 检查文件是否已存在
    if [ ! -f "$output_path" ]; then
        echo "    - ⬇️ 下载 ${type}: $filename (from $download_url)"
        mkdir -p "$(dirname "$output_path")"
        # 执行下载
        wget --progress=bar:force:noscroll --timeout=120 -O "$output_path" "$download_url"
        # 检查结果
        if [ $? -ne 0 ]; then
            echo "      ❌ 下载失败: $filename from $download_url (检查 URL 或网络)"
            rm -f "$output_path"
        else
            echo "      ✅ 下载完成: $filename"
        fi
    else
        echo "    - ✅ 文件已存在，跳过下载 ${type}: $filename"
    fi
}

# ---------------------------------------------------
# 插件黑名单
# ---------------------------------------------------
SKIP_LIST=(
  "$TARGET_DIR/extensions/stable-diffusion-aws-extension"
  "$TARGET_DIR/extensions/sd_dreambooth_extension"
  "$TARGET_DIR/extensions/stable-diffusion-webui-aesthetic-image-scorer"
)

should_skip() {
  local dir="$1"
  for skip in "${SKIP_LIST[@]}"; do
    [[ "$dir" == "$skip" ]] && return 0
  done
  return 1
}

# ==================================================
# 资源下载 (使用 resources.txt)
# ==================================================
echo "📦 [9] 处理资源下载 (基于 $TARGET_DIR/resources.txt 和下载开关)..."
RESOURCE_PATH="$TARGET_DIR/resources.txt"  # 资源列表文件路径现在使用 $TARGET_DIR

# 检查资源文件是否存在，如果不存在则尝试下载默认版本
if [ ! -f "$RESOURCE_PATH" ]; then
  # 指定默认资源文件的 URL
  DEFAULT_RESOURCE_URL="https://raw.githubusercontent.com/chuan1127/SD-webui-forge/main/resources.txt"
  echo "  - 未找到本地 resources.txt，尝试从 ${DEFAULT_RESOURCE_URL} 下载..."
  # 使用 curl 下载，确保失败时不输出错误页面 (-f)，静默 (-s)，跟随重定向 (-L)
  curl -fsSL -o "$RESOURCE_PATH" "$DEFAULT_RESOURCE_URL"
  if [ $? -eq 0 ]; then
      echo "  - ✅ 默认 resources.txt 下载成功。"
  else
      echo "  - ❌ 下载默认 resources.txt 失败。请手动将资源文件放在 ${RESOURCE_PATH} 或检查网络/URL。"
      # 创建一个空文件以避免后续读取错误，但不会下载任何内容
      touch "$RESOURCE_PATH"
      echo "  - 已创建空的 resources.txt 文件以继续，但不会下载任何资源。"
  fi
else
  echo "  - ✅ 使用本地已存在的 resources.txt: ${RESOURCE_PATH}"
fi

# 定义函数：克隆或更新 Git 仓库 (支持独立 Git 镜像开关)
clone_or_update_repo() {
    # $1: 目标目录, $2: 原始仓库 URL
    local dir="$TARGET_DIR/$1" repo_original="$2"  # 使用 $TARGET_DIR 来创建正确的目录路径
    local dirname
    local repo_url # URL to be used for cloning/pulling

    dirname=$(basename "$dir")

    # 检查是否启用了 Git 镜像以及是否是 GitHub URL
    if [[ "$USE_GIT_MIRROR" == "true" && "$repo_original" == "https://github.com/"* ]]; then
        local git_mirror_host
        git_mirror_host=$(echo "$GIT_MIRROR_URL" | sed 's|https://||; s|http://||; s|/.*||')
        repo_url=$(echo "$repo_original" | sed "s|github.com|$git_mirror_host|")
        echo "    - 使用镜像转换 (Git): $repo_original -> $repo_url"
    else
        repo_url="$repo_original"
    fi

    # 检查扩展下载开关
    if [[ "$ENABLE_DOWNLOAD_EXTS" != "true" ]]; then
        if [ -d "$dir" ]; then
            echo "    - ⏭️ 跳过更新扩展/仓库 (ENABLE_DOWNLOAD_EXTS=false): $dirname"
        else
            echo "    - ⏭️ 跳过克隆扩展/仓库 (ENABLE_DOWNLOAD_EXTS=false): $dirname"
        fi
        return
    fi

    # 尝试更新或克隆
    if [ -d "$dir/.git" ]; then
        echo "    - 🔄 更新扩展/仓库: $dirname (from $repo_url)"
        (cd "$dir" && git pull --ff-only) || echo "      ⚠️ Git pull 失败: $dirname (可能存在本地修改或网络问题)"
    elif [ ! -d "$dir" ]; then
        echo "    - 📥 克隆扩展/仓库: $repo_url -> $dirname (完整克隆)"
        git clone --recursive "$repo_url" "$dir" || echo "      ❌ Git clone 失败: $dirname (检查 URL: $repo_url 和网络)"
    else
        echo "    - ✅ 目录已存在但非 Git 仓库，跳过 Git 操作: $dirname"
    fi  # ✅ 这里是必须的
}

# 定义函数：下载文件 (支持独立 HF 镜像开关)
download_with_progress() {
    # $1: 输出路径, $2: 原始 URL, $3: 资源类型描述, $4: 对应的下载开关变量值
    local output_path="$TARGET_DIR/$1" url_original="$2" type="$3" enabled_flag="$4"  # 使用 $TARGET_DIR 来创建正确的路径
    local filename
    local download_url # URL to be used for downloading

    filename=$(basename "$output_path")

    # 检查下载开关
    if [[ "$enabled_flag" != "true" ]]; then
        echo "    - ⏭️ 跳过下载 ${type} (开关 '$enabled_flag' != 'true'): $filename"
        return
    fi
    # 检查网络
    if [[ "$NET_OK" != "true" ]]; then
        echo "    - ❌ 跳过下载 ${type} (网络不通): $filename"
        return
    fi

    # 检查是否启用了 HF 镜像以及是否是 Hugging Face URL
    # 使用步骤 [2] 中定义的 HF_MIRROR_URL
    if [[ "$USE_HF_MIRROR" == "true" && "$url_original" == "https://huggingface.co/"* ]]; then
        # 替换 huggingface.co 为镜像地址
        download_url=$(echo "$url_original" | sed "s|https://huggingface.co|$HF_MIRROR_URL|")
        echo "    - 使用镜像转换 (HF): $url_original -> $download_url"
    else
        # 使用原始 URL
        download_url="$url_original"
    fi

    # 检查文件是否已存在
    if [ ! -f "$output_path" ]; then
        echo "    - ⬇️ 下载 ${type}: $filename (from $download_url)"
        mkdir -p "$(dirname "$output_path")"
        # 执行下载
        wget --progress=bar:force:noscroll --timeout=120 -O "$output_path" "$download_url"
        # 检查结果
        if [ $? -ne 0 ]; then
            echo "      ❌ 下载失败: $filename from $download_url (检查 URL 或网络)"
            rm -f "$output_path"
        else
            echo "      ✅ 下载完成: $filename"
        fi
    else
        echo "    - ✅ 文件已存在，跳过下载 ${type}: $filename"
    fi
}

# 定义插件/目录黑名单 (示例)
SKIP_DIRS=(
  "$TARGET_DIR/extensions/stable-diffusion-aws-extension" # 示例：跳过 AWS 插件
  "$TARGET_DIR/extensions/sd_dreambooth_extension"     # 示例：跳过 Dreambooth (如果需要单独管理)
)
# 函数：检查目标路径是否应跳过
should_skip() {
  local dir_to_check="$1"
  for skip_dir in "${SKIP_DIRS[@]}"; do
    # 完全匹配路径
    if [[ "$dir_to_check" == "$skip_dir" ]]; then
      return 0 # 0 表示应该跳过 (Bash true)
    fi
  done
  return 1 # 1 表示不应该跳过 (Bash false)
}

echo "  - 开始处理 resources.txt 中的条目..."

# 逐行读取 resources.txt 文件 (逗号分隔: 目标路径,源URL)
while IFS=, read -r target_path source_url || [[ -n "$target_path" ]]; do
  # 清理路径和 URL 的前后空格
  target_path=$(echo "$target_path" | xargs)
  source_url=$(echo "$source_url" | xargs)

  # 跳过注释行 (# 开头) 或空行 (路径或 URL 为空)
  [[ "$target_path" =~ ^#.*$ || -z "$target_path" || -z "$source_url" ]] && continue

  # 在目标路径前加上 $TARGET_DIR
  full_target_path="$TARGET_DIR/$target_path"

  # 检查是否在黑名单中
  if should_skip "$full_target_path"; then
    echo "    - ⛔ 跳过黑名单条目: $full_target_path"
    continue # 处理下一行
  fi

  # 根据目标路径判断资源类型并调用相应下载函数及正确的独立开关
  case "$full_target_path" in
    # 1. Extensions
    "$TARGET_DIR/extensions/"*)
        clone_or_update_repo "$target_path" "$source_url" # Uses ENABLE_DOWNLOAD_EXTS internally
        ;;

    # 2. Stable Diffusion Checkpoints
    "$TARGET_DIR/models/Stable-diffusion/SD1.5/"*)
        download_with_progress "$target_path" "$source_url" "SD 1.5 Checkpoint" "$ENABLE_DOWNLOAD_MODEL_SD15"
        ;;

    "$TARGET_DIR/models/Stable-diffusion/XL/"*)
        download_with_progress "$target_path" "$source_url" "SDXL Checkpoint" "$ENABLE_DOWNLOAD_MODEL_SDXL"
        ;;

    "$TARGET_DIR/models/Stable-diffusion/flux/"*)
        download_with_progress "$target_path" "$source_url" "FLUX Checkpoint" "$ENABLE_DOWNLOAD_MODEL_FLUX"
        ;;

    "$TARGET_DIR/models/Stable-diffusion/*") # Fallback
        echo "    - ❓ 处理未分类 Stable Diffusion 模型: $full_target_path (默认使用 SD1.5 开关)"
        download_with_progress "$target_path" "$source_url" "SD 1.5 Checkpoint (Fallback)" "$ENABLE_DOWNLOAD_MODEL_SD15"
        ;;

    # 3. VAEs
    "$TARGET_DIR/models/VAE/flux-*.safetensors") # FLUX Specific VAE
        download_with_progress "$target_path" "$source_url" "FLUX VAE" "$ENABLE_DOWNLOAD_VAE_FLUX" # Use specific FLUX VAE switch
        ;;

    "$TARGET_DIR/models/VAE/*") # Other VAEs
        download_with_progress "$target_path" "$source_url" "VAE Model" "$ENABLE_DOWNLOAD_VAE"
        ;;

    # 4. Text Encoders (Currently FLUX specific)
    "$TARGET_DIR/models/text_encoder/*")
        download_with_progress "$target_path" "$source_url" "Text Encoder (FLUX)" "$ENABLE_DOWNLOAD_TE_FLUX" # Use specific FLUX TE switch
        ;;

    # 5. ControlNet Models
    "$TARGET_DIR/models/ControlNet/"*)
    filename=$(basename "$target_path")
    if [[ "$filename" == control_v11* ]]; then
        # 属于 SD 1.5 的 ControlNet 模型
        download_with_progress "$target_path" "$source_url" "ControlNet SD 1.5" "$ENABLE_DOWNLOAD_CNET_SD15"
    elif [[ "$filename" == *sdxl* || "$filename" == *SDXL* ]]; then
        # 属于 SDXL 的 ControlNet 模型
        download_with_progress "$target_path" "$source_url" "ControlNet SDXL" "$ENABLE_DOWNLOAD_CNET_SDXL"
    elif [[ "$filename" == flux-* || "$filename" == *flux* ]]; then
        # 属于 FLUX 的 ControlNet 模型
        download_with_progress "$target_path" "$source_url" "ControlNet FLUX" "$ENABLE_DOWNLOAD_CNET_FLUX"
    else
        echo "    - ❓ 未识别 ControlNet 模型类别: $filename，默认作为 SD1.5 处理"
        download_with_progress "$target_path" "$source_url" "ControlNet SD 1.5 (Fallback)" "$ENABLE_DOWNLOAD_CNET_SD15"
    fi
    ;;


    # 6. LoRA and related models
    "$TARGET_DIR/models/Lora/*" | "$TARGET_DIR/models/LyCORIS/*" | "$TARGET_DIR/models/LoCon/*")
        download_with_progress "$target_path" "$source_url" "LoRA/LyCORIS" "$ENABLE_DOWNLOAD_LORAS"
        ;;

    # 7. Embeddings / Textual Inversion
    "$TARGET_DIR/models/TextualInversion/*" | "$TARGET_DIR/embeddings/*")
       download_with_progress "$target_path" "$source_url" "Embedding/Textual Inversion" "$ENABLE_DOWNLOAD_EMBEDDINGS"
       ;;

    # 8. Upscalers
    "$TARGET_DIR/models/Upscaler/*" | "$TARGET_DIR/models/ESRGAN/*")
       download_with_progress "$target_path" "$source_url" "Upscaler Model" "$ENABLE_DOWNLOAD_UPSCALERS"
       ;;

    # 9. Fallback for any other paths
    *)
        if [[ "$source_url" == *.git ]]; then
             echo "    - ❓ 处理未分类 Git 仓库: $full_target_path (默认使用 Extension 开关)"
             clone_or_update_repo "$target_path" "$source_url" # Uses ENABLE_DOWNLOAD_EXTS internally
        elif [[ "$source_url" == http* ]]; then
             echo "    - ❓ 处理未分类文件下载: $full_target_path (默认使用 SD1.5 Model 开关)"
             download_with_progress "$target_path" "$source_url" "Unknown Model/File" "$ENABLE_DOWNLOAD_MODEL_SD15"
        else
             echo "    - ❓ 无法识别的资源类型或无效 URL: target='$target_path', source='$source_url'"
        fi
        ;;
  esac # 结束 case
done < "$RESOURCE_PATH" # 从资源文件读取

# ==================================================
# Token 处理 (Hugging Face, Civitai)
# ==================================================
# 步骤号顺延为 [10]
echo "🔐 [10] 处理 API Tokens (如果已提供)..."

# 处理 Hugging Face Token (如果环境变量已设置)
if [[ -n "$HUGGINGFACE_TOKEN" ]]; then
  echo "  - 检测到 HUGGINGFACE_TOKEN，尝试使用 huggingface-cli 登录..."
  # 检查 huggingface-cli 命令是否存在 (应由 huggingface_hub[cli] 提供)
  if command -v huggingface-cli &>/dev/null; then
      # 正确用法：将 token 作为参数传递给 --token
      huggingface-cli login --token "$HUGGINGFACE_TOKEN" --add-to-git-credential
      # 检查命令执行是否成功
      if [ $? -eq 0 ]; then
          echo "  - ✅ Hugging Face CLI 登录成功。"
      else
          # 登录失败通常不会是致命错误，只记录警告
          echo "  - ⚠️ Hugging Face CLI 登录失败。请检查 Token 是否有效、是否过期或 huggingface-cli 是否工作正常。"
      fi
  else
      echo "  - ⚠️ 未找到 huggingface-cli 命令，无法登录。请确保依赖 'huggingface_hub[cli]' 已正确安装在 venv 中。"
  fi
else
  # 如果未提供 Token
  echo "  - ⏭️ 未设置 HUGGINGFACE_TOKEN 环境变量，跳过 Hugging Face 登录。"
fi

# 检查 Civitai API Token
if [[ -n "$CIVITAI_API_TOKEN" ]]; then
  echo "  - ✅ 检测到 CIVITAI_API_TOKEN (长度: ${#CIVITAI_API_TOKEN})。"
else
  echo "  - ⏭️ 未设置 CIVITAI_API_TOKEN 环境变量。"
fi

# ---------------------------------------------------
# 🔥 启动最终服务（使用方案 C：你的 venv + 跳过官方 prepare/install 流程）
# ---------------------------------------------------
echo "🚀 [11] 所有准备就绪，使用 venv 启动 webui.py ..."

# 激活虚拟环境（如果未激活）
if [[ -z "$VIRTUAL_ENV" ]]; then
  echo "⚠️ 虚拟环境未激活，正在激活... Logging virtual environment activation."
  echo "  - 激活虚拟环境: source $TARGET_DIR/venv/bin/activate"
  source "$TARGET_DIR/venv/bin/activate" || { echo "❌ 无法激活虚拟环境"; exit 1; }
  echo "✅ 虚拟环境成功激活"
else
  echo "✅ 虚拟环境已激活"
fi

# 设置跳过 Forge 环境流程的参数，并合并用户自定义参数
echo "🧠 设置启动参数 COMMANDLINE_ARGS"
export COMMANDLINE_ARGS="--cuda-malloc --skip-install --skip-prepare-environment --skip-python-version-check --skip-torch-cuda-test $ARGS"

# 验证启动参数
echo "🧠 启动参数: $COMMANDLINE_ARGS"

echo "🚀 [11] 所有准备就绪，启动 webui.sh ..."
exec bash "$TARGET_DIR/webui.sh"


# 日志记录启动过程
#echo "🚀 [11] 正在启动 webui.py ..."

# 启动 Python 3.11 脚本 webui.py
#echo "  - 执行命令: exec $TARGET_DIR/venv/bin/python $TARGET_DIR/launch.py"
#exec "$TARGET_DIR/venv/bin/python" "$TARGET_DIR/launch.py" || { echo "❌ 启动失败：无法执行 webui.py"; exit 1; }

#echo "🚀 Web UI 启动成功"
