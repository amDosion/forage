#!/bin/bash

# 确保脚本出错时立即退出
set -e
# 确保管道中的命令失败时也退出
set -o pipefail

# ==================================================
# [0] 加载 .env 配置并设置基础环境变量（无 TARGET_DIR 依赖）
# ==================================================
source .env 2>/dev/null || true

# 设置基本变量（先不使用 TARGET_DIR）
export PYTHON="${PYTHON:-python3.11}"
export TORCH_VERSION="${TORCH_VERSION:-2.7.0+cu128}"
export TORCHVISION_VERSION="${TORCHVISION_VERSION:-0.22.0+cu128}"
export TORCHAUDIO_VERSION="${TORCHAUDIO_VERSION:-2.7.0+cu128}"
export TORCH_INDEX_URL="https://download.pytorch.org/whl/cu128"
export PIP_EXTRA_INDEX_URL="$TORCH_INDEX_URL"
export NO_TCMALLOC=1
export UI="${UI:-forge}"
export COMMANDLINE_ARGS="${COMMANDLINE_ARGS:---xformers --api --listen --enable-insecure-extension-access --theme dark --cuda-malloc --loglevel DEBUG --ui-debug-mode --gradio-debug}"

# 控制台确认
echo "✅ 已加载 .env 并初始化基本环境变量："
echo "  - PYTHON:              $PYTHON"
echo "  - TORCH_VERSION:       $TORCH_VERSION"
echo "  - COMMANDLINE_ARGS:    $COMMANDLINE_ARGS"
echo "  - PIP_EXTRA_INDEX_URL: $PIP_EXTRA_INDEX_URL"
echo "  - NO_TCMALLOC:         $NO_TCMALLOC"
echo "  - UI:                  $UI"

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
echo "🚀 [0] 启动脚本 - Stable Diffusion WebUI (CUDA 12.8 / PyTorch)"
echo "=================================================="
echo "⏳ 开始时间: $(date)"

# ==================================================
# 🔒 [6.2] sudo 安装检查（确保 root 可切换为 webui 用户）
# ==================================================
# pip 检查 (通过 python -m pip 调用)
if python3.11 -m pip --version &>/dev/null; then
  echo "✅ pip for Python 3.11 版本: $(python3.11 -m pip --version)"
else
  echo "❌ 未找到 pip for Python 3.11！"
  exit 1
fi

# 容器检测
if [ -f "/.dockerenv" ]; then
  echo "📦 正在 Docker 容器中运行"
else
  echo "🖥️ 非 Docker 容器环境"
fi

# 用户检查 (应为 webui)
echo "👤 当前用户: $(whoami) (应为 webui)"

# 工作目录写入权限检查
if [ -w "/app/webui" ]; then
  echo "✅ /app/webui 目录可写"
else
  echo "❌ /app/webui 目录不可写，启动可能会失败！请检查 Dockerfile 中的权限设置。"
  # 允许继续，以便在具体步骤中捕获错误
fi
echo "✅ 系统环境自检完成"

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
# 进入目标目录
cd "$TARGET_DIR" || { echo "❌ 进入目标目录失败"; exit 1; }
# 设置工作目录为当前目录
export WORK_DIR="$PWD"
# 设置日志文件路径
export LOG_FILE="$WORK_DIR/launch.log"
   
# 设置派生路径变量（基于工作目录 /app/webui）
export VENV_DIR="venv"
export VENV_PY="$VENV_DIR/bin/python"
export VENV_PIP="$VENV_DIR/bin/pip"
export PYTHON="$VENV_PY"
export WEBUI_USER_SH="webui-user.sh"

echo "✅ 派生路径设定完成："
echo "  - VENV_DIR:     $VENV_DIR"
echo "  - VENV_PY:      $VENV_PY"
echo "  - VENV_PIP:     $VENV_PIP"
echo "  - PYTHON (使用虚拟环境): $PYTHON"
echo "  - WEBUI_USER_SH: $WEBUI_USER_SH"

# ==================================================
# 克隆/更新 WebUI 仓库
# ==================================================
# 如果目录中存在.git文件，说明已经克隆过仓库，尝试更新
if [ -d ".git" ]; then
  echo "  - 仓库已存在，尝试更新 (git pull)..."
  git pull --ff-only || echo "⚠️ Git pull 失败，可能是本地有修改或网络问题。将继续使用当前版本。"
else
  echo "  - 仓库不存在，开始完整克隆 $REPO 到当前目录 ..."
  # 使用完整克隆（非浅克隆），并初始化子模块（推荐）
  git clone --recursive "$REPO" . || { echo "❌ 克隆仓库失败"; exit 1; }

  # 赋予启动脚本执行权限
  if [ -f "$WEBUI_EXECUTABLE" ]; then
    chmod +x "$WEBUI_EXECUTABLE"
    echo "  - 已赋予 $WEBUI_EXECUTABLE 执行权限"
  else
    echo "⚠️ 未在克隆的仓库中找到预期的启动脚本 $WEBUI_EXECUTABLE"
    exit 1
  fi
fi
echo "✅ 仓库操作完成"

# 赋予启动脚本执行权限
if [ -f "webui.sh" ]; then
  chmod +x "webui.sh"
  echo "  - 已赋予 webui.sh 执行权限"
else
  echo "⚠️ 未在克隆的仓库中找到预期的启动脚本 webui.sh"
  exit 1  # 如果找不到启动脚本，可以选择退出
fi

# 赋予启动脚本执行权限
if [ -f "webui-user.sh" ]; then
  chmod +x "webui-user.sh"
  echo "  - 已赋予 webui-user.sh 执行权限"
else
  echo "⚠️ 未在克隆的仓库中找到预期的启动脚本 webui-user.sh"
  exit 1  # 如果找不到启动脚本，可以选择退出
fi

# 赋予启动脚本执行权限
if [ -f "launch.py" ]; then
  chmod +x "launch.py"
  echo "  - 已赋予 launch.py 执行权限"
else
  echo "⚠️ 未在克隆的仓库中找到预期的启动脚本 launch.py"
  exit 1  # 如果找不到启动脚本，可以选择退出
fi

# =========================================
# 补丁修正 launch_utils.py 强制 torch 版本
# =========================================
PATCH_URL="https://raw.githubusercontent.com/amDosion/forage/main/force_torch_version.patch"
PATCH_FILE="force_torch_version.patch"

echo "🔧 下载补丁文件..."
curl -fsSL -o "$PATCH_FILE" "$PATCH_URL" || { echo "❌ 补丁文件下载失败"; exit 1; }

# 检查 patch 是否已经打过，防止重复 patch
if patch --dry-run -p1 < "$PATCH_FILE" > /dev/null 2>&1; then
    echo "🩹 应用补丁到 modules/launch_utils.py ..."
    patch -p1 < "$PATCH_FILE" || { echo "❌ 应用补丁失败"; exit 1; }
    echo "✅ 补丁应用完成！"
else
    echo "✅ 补丁已经应用过，跳过。"
fi

# 设置环境变量，强制使用固定 Torch 版本
export TORCH_COMMAND="pip install torch==2.7.0+cu128 --extra-index-url https://download.pytorch.org/whl/cu128"
export FORCE_CUDA="128"

# 创建 repositories 目录（在 $PWD 内）
REPOSITORIES_DIR="$PWD/repositories"
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
REQ_FILE="$PWD/requirements_versions.txt"
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

# 设置 Python 命令
python_cmd="${PYTHON_CMD:-python3.11}"

# 定义虚拟环境目录
VENV_DIR="$PWD/venv"

echo "🐍 [6] 设置 Python 虚拟环境 ($VENV_DIR)..."

# 检查虚拟环境是否已存在
if [[ ! -d "${VENV_DIR}" ]]; then
  echo "  - 虚拟环境不存在，正在创建..."
  "${python_cmd}" -m venv "${VENV_DIR}" || { echo "❌ 创建虚拟环境失败，请检查 python3-venv 是否安装"; exit 1; }
  echo "  - 虚拟环境创建成功。"

  # 用 venv 内的 Python 升级 pip
  "${VENV_DIR}/bin/python" -m pip install --upgrade pip
else
  echo "  - 虚拟环境已存在于 $VENV_DIR。"
fi

# 激活虚拟环境
if [[ -f "${VENV_DIR}/bin/activate" ]]; then
  echo "  - 激活虚拟环境..."
  source "${VENV_DIR}/bin/activate"

  # 激活后，强制更新 python_cmd 指向 venv
  python_cmd="${VENV_DIR}/bin/python"
else
  echo "❌ 无法激活虚拟环境，终止执行"
  exit 1
fi

# 确认当前 Python 环境
echo "  - 当前 Python: $(which python) (应指向 $VENV_DIR/bin/python)"
echo "  - 当前 pip: $(which pip) (应指向 $VENV_DIR/bin/pip)"
echo "  - 当前 Python 版本: $(${python_cmd} --version)"
echo "  - 当前 pip 版本: $(${python_cmd} -m pip --version)"
echo "  - 当前工作目录: $PWD"
echo "  - 当前虚拟环境目录: $VENV_DIR"

# ---------------------------------------------------
# 升级 pip
# ---------------------------------------------------
echo "📥 升级 pip..."
"${python_cmd}" -m pip install --upgrade pip | tee -a "$LOG_FILE"

# ---------------------------------------------------
# 安装 huggingface-cli 工具
# ---------------------------------------------------
echo "🔍 检查 huggingface_hub[cli] 是否已安装..."
if "${python_cmd}" -m pip show huggingface-hub | grep -q "Version"; then
  echo "✅ huggingface_hub[cli] 已安装，跳过安装"
else
  echo "📦 安装 huggingface_hub[cli]..."
  "${python_cmd}" -m pip install --upgrade "huggingface_hub[cli]" | tee -a "$LOG_FILE"
fi

deactivate
# 定义要创建的完整路径列表
DIRECTORIES=(
  "$PWD/embeddings"
  "$PWD/models/Stable-diffusion"
  "$PWD/models/VAE"
  "$PWD/models/Lora"
  "$PWD/models/LyCORIS"
  "$PWD/models/ControlNet"
  "$PWD/outputs"
  "$PWD/extensions"
)

# 遍历检查每个目录是否存在，如果不存在则创建
for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "📁 目录创建成功：$dir"
    else
        echo "✅ 目录已存在：$dir"
    fi
done

echo "  - 所有 WebUI 相关目录已检查/创建完成。"

# ==================================================
# 网络测试 (可选)
# ==================================================
echo "🌐 [8] 网络连通性测试 (尝试访问 huggingface.co)..."
NET_OK=false # 默认网络不通
# 使用 curl 测试连接，设置超时时间
if curl -fsS --connect-timeout 5 https://huggingface.co > /dev/null; then
  NET_OK=true
  echo "  - ✅ 网络连通 (huggingface.co 可访问)"
else
  # 如果 Hugging Face 不通，尝试 GitHub 作为备选检查
  if curl -fsS --connect-timeout 5 https://github.com > /dev/null; then
      NET_OK=true # 至少 Git 相关操作可能成功
      echo "  - ⚠️ huggingface.co 无法访问，但 github.com 可访问。部分模型下载可能受影响。"
  else
      echo "  - ❌ 网络不通 (无法访问 huggingface.co 和 github.com)。资源下载和插件更新将失败！"
  fi
fi


# ==================================================
# 安装 WebUI 核心依赖 (基于 UI 类型)
# ==================================================
echo "📥 [6.2] 安装 WebUI 核心依赖 (基于 UI 类型)..."

# ==================================================
# 根据 UI 类型决定依赖处理方式
# ==================================================
if [ "$UI" = "forge" ]; then
    echo "  - (Forge UI) 使用 run.sh 控制依赖安装流程"

    INSTALL_TORCH="${INSTALL_TORCH:-true}"
    if [[ "$INSTALL_TORCH" == "true" ]]; then
        TORCH_COMMAND="pip install torch=="$TORCH_VERSION" torchvision=="$TORCHVISION_VERSION" torchaudio=="$TORCHAUDIO_VERSION" --extra-index-url "$TORCH_INDEX_URL"
        echo "  - 安装 PyTorch Nightly: $TORCH_COMMAND"
        $TORCH_COMMAND && echo "    ✅ PyTorch 安装成功" || echo "    ❌ PyTorch 安装失败"
    else
        echo "  - ⏭️ 跳过 PyTorch 安装 (INSTALL_TORCH=false)"
    fi

    # 🔧 安装其他核心依赖（升级主依赖，跳过 xformers + tensorflow）
    REQ_FILE="$PWD/requirements_versions.txt"
    if [ -f "$REQ_FILE" ]; then
        echo "  - 使用 $REQ_FILE 安装其他依赖（升级主依赖，跳过 xformers + tensorflow）..."
        sed -i 's/\r$//' "$REQ_FILE"

        while IFS= read -r line || [[ -n "$line" ]]; do
            # 去除注释和空白
            clean_line=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            [[ -z "$clean_line" ]] && continue

            # 提取包名（支持 ==、>=、<=、~= 形式）
            pkg_name=$(echo "$clean_line" | cut -d '=' -f1 | cut -d '<' -f1 | cut -d '>' -f1 | cut -d '~' -f1)

            # 跳过已从源码构建的依赖
            if [[ "$pkg_name" == *xformers* ]]; then
                echo "    - ⏭️ 跳过 xformers（已从源码编译）"
                continue
            fi

            if [[ "$pkg_name" == "tensorflow" || "$pkg_name" == "tf-nightly" ]]; then
                echo "    - ⏭️ 跳过 TensorFlow（已从源码构建）"
                continue
            fi

            # 已安装则跳过（避免覆盖 auto 安装的依赖）
            if pip show "$pkg_name" > /dev/null 2>&1; then
                echo "    - ⏩ 已安装: $pkg_name，跳过版本指定安装"
                continue
            fi

            # 安装主包（不锁版本）
            echo "    - 安装主包: $pkg_name（忽略版本限制）"
            pip install --upgrade --no-cache-dir "$pkg_name" --extra-index-url "$PIP_EXTRA_INDEX_URL" 2>&1 \
                | tee -a "$LOG_FILE" \
                | sed 's/^Successfully installed/      ✅ 成功安装/' \
                | sed 's/^Requirement already satisfied/      ⏩ 已是最新版本/'

            if [ ${PIPESTATUS[0]} -ne 0 ]; then
                echo "❌ 安装失败: $pkg_name"
            fi
        done < "$REQ_FILE"

        echo "  - 其他依赖处理完成。"
    else
        echo "⚠️ 未找到 $REQ_FILE，跳过依赖安装。"
    fi

else
    echo "  - (非 Forge UI) 全量安装 requirements_versions.txt 中依赖..."
    REQ_FILE="$PWD/requirements_versions.txt"
    if [ -f "$REQ_FILE" ]; then
        sed -i 's/\r$//' "$REQ_FILE"

        while IFS= read -r line || [[ -n "$line" ]]; do
            clean_line=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            [[ -z "$clean_line" ]] && continue

            echo "    - 安装: $clean_line"
            pip install "$clean_line" --no-cache-dir --extra-index-url "$PIP_EXTRA_INDEX_URL" 2>&1 \
                | tee -a "$LOG_FILE" \
                | sed 's/^Successfully installed/      ✅ 成功安装/' \
                | sed 's/^Requirement already satisfied/      ⏩ 需求已满足/'

            if [ ${PIPESTATUS[0]} -ne 0 ]; then
                echo "❌ 安装失败: $clean_line"
            fi
        done < "$REQ_FILE"

        echo "  - requirements_versions.txt 中的依赖处理完成。"
    else
        echo "⚠️ 未找到 $REQ_FILE，跳过依赖安装。"
    fi
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
check_and_install_package "onnx"
check_and_install_package "onnxruntime"
check_and_install_package "send2trash"
check_and_install_package "ZipUnicode"
check_and_install_package "timm"
check_and_install_package "dill"
check_and_install_package "controlnet-aux"

# ==================================================
# 🔧 [6.3] Ninja + xformers 编译安装（适配 CUDA 12.8）
# ==================================================
# --- 配置 ---
INSTALL_XFORMERS="${INSTALL_XFORMERS:-true}" # 设置为 false 以显式禁用
MAIN_REPO_DIR="/app/webui/sd-webui-forge"    # 如果你的主仓库位置不同，请调整
XFORMERS_SRC_DIR="${MAIN_REPO_DIR}/xformers-src"
XFORMERS_REPO_URL="https://github.com/amDosion/xformers.git" # 官方仓库 - 如果使用 fork，请更改

# 构建配置
TARGET_CUDA_ARCH="${TORCH_CUDA_ARCH_LIST:-8.9}" # 默认为 8.9 (例如，RTX 3090/4090)，如果外部未设置
MAX_BUILD_JOBS="${MAX_JOBS:-$(nproc)}"         # 默认使用所有可用核心，如果需要，稍后限制
# 如果需要，限制 MAX_JOBS (例如，限制为 8)
# MAX_BUILD_JOBS=$((${MAX_BUILD_JOBS} > 8 ? 8 : ${MAX_BUILD_JOBS}))

# --- 辅助函数 ---
log_info() { echo "✅ INFO: $1"; }
log_warn() { echo "⚠️ WARN: $1"; }
log_error() { echo "❌ ERROR: $1"; }
log_step() { echo -e "\n🚀 STEP: $1"; }
log_detail() { echo "  ➤ $1"; }

check_command() {
  command -v "$1" >/dev/null 2>&1
}

# --- 依赖检查和安装函数 ---
check_and_install_dependencies() {
    log_step "检查和安装依赖..."

    # Pip 依赖
    log_detail "检查 Pip 构建依赖 (wheel, setuptools, cmake, ninja)..."
    MISSING_PIP_DEPS=()
    for pkg in wheel setuptools cmake ninja; do
      if ! pip show "$pkg" > /dev/null 2>&1; then
        log_warn "$pkg 未安装。"
        MISSING_PIP_DEPS+=("$pkg")
      else
         log_detail "$pkg 找到: $(pip show "$pkg" | awk '/^Version:/{print $2}')"
      fi
    done

    if [ ${#MISSING_PIP_DEPS[@]} -ne 0 ]; then
      log_info "安装缺失的 pip 依赖: ${MISSING_PIP_DEPS[*]}"
      if ! pip install --upgrade "${MISSING_PIP_DEPS[@]}" --no-cache-dir; then
          log_error "未能安装 pip 依赖: ${MISSING_PIP_DEPS[*]}。正在中止。"
          exit 1
      fi
      log_info "Pip 依赖安装成功。"
    else
      log_info "所有必需的 pip 构建依赖都已存在。"
    fi

    # 确保 pip 本身是最新的
    log_detail "升级 pip..."
    pip install --upgrade pip --no-cache-dir

    # 系统依赖
    log_detail "检查系统构建依赖 (g++, zip, unzip)..."
    MISSING_SYSTEM_DEPS=()
    check_command g++ || MISSING_SYSTEM_DEPS+=("g++")
    check_command zip || MISSING_SYSTEM_DEPS+=("zip")
    check_command unzip || MISSING_SYSTEM_DEPS+=("unzip")

    # 通过 g++ 间接检查 build-essential
    if [[ ! " ${MISSING_SYSTEM_DEPS[@]} " =~ " g++ " ]]; then
        log_detail "g++ 找到: $(g++ --version | head -n 1)"
    else
        log_warn "g++ 未找到。可能缺少 build-essential 包。"
    fi
    if [[ ! " ${MISSING_SYSTEM_DEPS[@]} " =~ " zip " ]]; then
        log_detail "zip 找到。" # Zip 版本输出很详细
    else
        log_warn "zip 未找到。"
    fi
    if [[ ! " ${MISSING_SYSTEM_DEPS[@]} " =~ " unzip " ]]; then
        log_detail "unzip 找到。" # unzip 版本输出很详细
    else
        log_warn "unzip 未找到。"
    fi

    if [ ${#MISSING_SYSTEM_DEPS[@]} -ne 0 ]; then
      log_warn "缺失的系统依赖: ${MISSING_SYSTEM_DEPS[*]}"
      if [ "$(id -u)" -eq 0 ]; then
        log_info "尝试以 root 用户安装缺失的系统依赖..."
        export DEBIAN_FRONTEND=noninteractive
        if apt-get update && apt-get install -y --no-install-recommends "${MISSING_SYSTEM_DEPS[@]}"; then
           log_info "系统依赖安装成功。"
        else
           log_error "未能通过 apt-get 安装系统依赖。请手动安装它们。正在中止。"
           exit 1
        fi
      else
        log_error "以非 root 用户身份运行。请手动安装以下系统包: ${MISSING_SYSTEM_DEPS[*]}。正在中止。"
        log_detail "示例命令 (Debian/Ubuntu): sudo apt-get install -y ${MISSING_SYSTEM_DEPS[*]}"
        exit 1
      fi
    else
      log_info "所有必需的系统构建依赖都已存在。"
    fi
}

# --- 主脚本逻辑 ---
NEED_INSTALL_XFORMERS=false
if [[ "$INSTALL_XFORMERS" == "true" ]]; then
    log_info "[6.3] 检查 xformers 是否需要安装..."
    # --- 预先检查: xformers 是否已经安装且功能正常？ ---
    log_step "检查是否存在可用的 xformers 安装..."
    XFORMERS_CHECK_PASS=false
    XFORMERS_VERSION_INFO="N/A"
    if python -c "import xformers" >/dev/null 2>&1; then
        log_detail "xformers 模块可导入。"
        XFORMERS_VERSION_INFO=$(python -c "import xformers; print(xformers.__version__)" 2>/dev/null || echo "unknown")

        # 检查 xformers.info 是否可以成功执行
        if python -m xformers.info >/dev/null 2>&1; then
            log_info "现有 xformers 安装 (v${XFORMERS_VERSION_INFO}) 且 xformers.info 可执行，跳过构建。"
            XFORMERS_CHECK_PASS=true
        else
            log_warn "xformers 可导入 (v${XFORMERS_VERSION_INFO})，但 xformers.info 执行失败，可能存在问题，需要重新安装。"
            NEED_INSTALL_XFORMERS=true
        fi
    else
        log_warn "未找到 xformers 模块，需要安装。"
        NEED_INSTALL_XFORMERS=true
    fi

    if [[ "$XFORMERS_CHECK_PASS" == "true" ]]; then
        log_info "[6.3] 跳过构建过程，因为已存在可用的 xformers (v${XFORMERS_VERSION_INFO})。"
    fi
else
   log_info "[6.3] 跳过 xformers 安装，因为 INSTALL_XFORMERS 不是 'true'。"
fi

# 只有 NEED_INSTALL_XFORMERS 为 true 时，才执行以下代码块
if [[ "$NEED_INSTALL_XFORMERS" == "true" ]]; then
    log_info "[6.3] 启动 xformers 构建/安装过程 (目标 CUDA: ${TARGET_CUDA_ARCH})"
    log_detail "主仓库目录: ${MAIN_REPO_DIR}"
    log_detail "xformers 源码目录: ${XFORMERS_SRC_DIR}"
    log_detail "目标 PyTorch 版本: ${TORCH_VER}"
    log_detail "当前 Python: $(which python)"

    # 1. PyTorch 检查
    log_step "检查 PyTorch 版本要求..."
    torch_ok=false
    vision_ok=false
    audio_ok=false
    current_torch_ver=$(pip show torch 2>/dev/null | awk '/^Version:/{print $2}')
    current_vision_ver=$(pip show torchvision 2>/dev/null | awk '/^Version:/{print $2}')
    current_audio_ver=$(pip show torchaudio 2>/dev/null | awk '/^Version:/{print $2}')

    [[ "$current_torch_ver" == "$TORCH_VER" ]] && torch_ok=true
    [[ "$current_vision_ver" == "$VISION_VER" ]] && vision_ok=true
    [[ "$current_audio_ver" == "$AUDIO_VER" ]] && audio_ok=true

    if [[ "$torch_ok" != "true" || "$vision_ok" != "true" || "$audio_ok" != "true" ]]; then
        log_warn "未满足所需的 PyTorch 组件版本。"
        log_detail "需要: torch==${TORCH_VER}, torchvision==${VISION_VER}, torchaudio==${AUDIO_VER}"
        log_detail "找到:    torch==${current_torch_ver:-Not Installed}, torchvision==${current_vision_ver:-Not Installed}, torchaudio==${current_audio_ver:-Not Installed}"
        log_detail "执行 PyTorch 安装命令:"
        log_detail "$TORCH_INSTALL_CMD"
        if ! $TORCH_INSTALL_CMD; then
            log_error "PyTorch 安装失败。正在中止。"
            exit 1
        fi
        log_info "PyTorch 安装/更新成功。"
    else
        log_info "已满足所需的 PyTorch 版本。"
    fi

    check_and_install_dependencies

    # --- 源码准备 ---
    log_step "准备 xformers 源码..."
    if [ ! -d "$XFORMERS_SRC_DIR/.git" ]; then
        log_detail "从 ${XFORMERS_REPO_URL} 克隆 xformers 仓库..."
        # 如果不需要历史记录，使用 --depth 1 可以加快克隆速度，但如果构建特定标签/提交需要历史记录，请删除它
        if ! git clone --recursive ${XFORMERS_REPO_URL} "$XFORMERS_SRC_DIR"; then
            log_error "未能克隆 xformers 仓库。检查 URL 和网络连接。正在中止。"
            exit 1
        fi
        log_info "仓库克隆成功。"
    else
        log_detail "找到现有源码目录。更新仓库和子模块..."
        cd "$XFORMERS_SRC_DIR" || { log_error "无法进入源码目录 ${XFORMERS_SRC_DIR}。正在中止。"; exit 1; }
        # 存储本地更改 (如果有)，以避免 pull 冲突 (可选，谨慎使用)
        # git stash push -m "Auto-stash before update"
        git fetch origin
        # 首先尝试快速 forward pull
        if ! git pull --ff-only origin main; then # 假设 'main' 分支，如果需要，请调整
            log_warn "快速 forward pull 失败。尝试合并 pull (可能出现冲突)。"
            if ! git pull origin main; then
                log_warn "Git pull 失败。构建将使用当前的本地版本继续。"
                # 如果始终想要最新版本，覆盖更改，考虑在此处添加 'git reset --hard origin/main'
            fi
        fi
        # 更新子模块
        log_detail "更新子模块 (包括 flash-attention)..."
        if ! git submodule update --init --recursive; then
            log_error "未能更新子模块。检查 '.gitmodules' 和网络连接。正在中止。"
            cd "$MAIN_REPO_DIR" # 确保在中止之前退出 src 目录
            exit 1
        fi
        # 应用存储 (如果使用)
        # git stash pop || log_warn "Could not pop stash"
        cd "$MAIN_REPO_DIR" || { log_error "无法返回主目录 ${MAIN_REPO_DIR}。"; exit 1; } # 返回到原始目录
        log_info "仓库和子模块已更新。"
    fi

    # --- 构建 xformers ---
    log_step "开始 xformers 构建过程..."
    cd "$XFORMERS_SRC_DIR" || { log_error "无法进入源码目录 ${XFORMERS_SRC_DIR} 进行构建。正在中止。"; exit 1; }

    # 设置构建环境变量
    export TORCH_CUDA_ARCH_LIST="${TARGET_CUDA_ARCH}"
    export MAX_BUILD_JOBS="${MAX_JOBS:-16}"  # 设置并行编译线程数为16，确保没有设置时默认使用16
    export XFORMERS_BUILD_CPP=1
    export XFORMERS_FORCE_CUDA=1         # 强制 CUDA 构建，即使在构建时未检测到 GPU
    export XFORMERS_BUILD_TYPE="Release" # 构建优化的发布版本
    export XFORMERS_ENABLE_DEBUG_ASSERTIONS=0 # 在发布版本中禁用调试断言

    # 启用 Flash Attention 和 Triton 组件 (确保你的环境支持它们)
    export USE_FLASH_ATTENTION=1
    # export USE_TRITON=1 # 如果你安装了 triton 并且想使用它，请取消注释

    # 如果需要，设置 CMAKE 参数，例如，用于特定的 CUDA 架构确认
    export CMAKE_ARGS="-DCMAKE_CUDA_ARCHITECTURES=${TARGET_CUDA_ARCH//./}" # 格式如 '89'

    log_detail "构建环境变量已设置:"
    log_detail "  TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}"
    log_detail "  MAX_JOBS=${MAX_JOBS}"
    log_detail "  XFORMERS_FORCE_CUDA=${XFORMERS_FORCE_CUDA}"
    log_detail "  XFORMERS_BUILD_TYPE=${XFORMERS_BUILD_TYPE}"
    log_detail "  USE_FLASH_ATTENTION=${USE_FLASH_ATTENTION}"
    # log_detail "  USE_TRITON=${USE_TRITON}" # 如果启用了 USE_TRITON，请取消注释
    log_detail "  CMAKE_ARGS=${CMAKE_ARGS}"

    # 清理之前的构建工件 (可选，但建议用于干净的构建)
    # log_detail "清理之前的构建工件..."
    # python setup.py clean || log_warn "未能清理之前的构建工件。"
    # find . -name "*.so" -type f -delete
    # rm -rf build dist *.egg-info

    log_info "执行构建命令: pip install -v -e . --no-build-isolation"
    if ! pip install -v -e . --no-build-isolation; then
        log_error "xformers 构建失败。"
        log_detail "检查上面的详细构建日志，查找特定的 C++/CUDA 编译错误。"
        log_detail "确保 CUDA 工具包、驱动程序和 PyTorch 版本与目标架构 (${TARGET_CUDA_ARCH}) 兼容。"
        python -m pip list | grep -E 'torch|xformers|ninja|wheel|cmake|setuptools' # 显示相关的包版本
        build_success=false
    else
        log_info "xformers 构建成功。"
        build_success=true
    fi

    # 取消设置构建环境变量
    unset TORCH_CUDA_ARCH_LIST
    unset MAX_JOBS
    unset XFORMERS_FORCE_CUDA
    unset XFORMERS_BUILD_TYPE
    unset XFORMERS_ENABLE_DEBUG_ASSERTIONS
    unset USE_FLASH_ATTENTION
    unset CMAKE_ARGS

    cd "$MAIN_REPO_DIR" || log_warn "无法返回主目录 ${MAIN_REPO_DIR}。"

    # --- 构建后验证 ---
    if [[ "$build_success" != "true" ]]; then
        log_error "[6.3] xformers 安装过程在构建期间失败。"
        exit 1
    fi

    log_step "验证安装..."
    log_detail "运行 torch.utils.collect_env..."
    python -m torch.utils.collect_env > "${MAIN_REPO_DIR}/torch_env_$(date +%Y%m%d_%H%M%S).txt" || log_warn "未能收集 torch 环境信息。"

    log_detail "运行 xformers.info..."
    XFORMERS_INFO_OUTPUT_FILE="${MAIN_REPO_DIR}/xformers_info_$(date +%Y%m%d_%H%M%S).txt"
    if python -m xformers.info > "$XFORMERS_INFO_OUTPUT_FILE"; then
      log_info "xformers.info 执行成功。输出保存到 ${XFORMERS_INFO_OUTPUT_FILE}"
      log_info "检测到的所有 xformers 组件，可用状态已被忽略" #简化提示
    else
      log_error "未能执行 'python -m xformers.info'。安装可能不完整或已损坏。"
      log_error "[6.3] xformers 安装过程完成，存在潜在问题。"
      exit 1
    fi

    log_info "[6.3] xformers 安装过程成功完成。"
    log_detail "最终 Python 可执行文件: $(which python)"
    log_detail "xformers 源码位置: $(realpath "$XFORMERS_SRC_DIR" 2>/dev/null || echo $XFORMERS_SRC_DIR)" # 如果目录被删除，realpath 可能会失败
fi # End of NEED_INSTALL_XFORMERS block

# ==================================================
# 🧠 [6.4] TensorFlow 编译（maludwig 分支 + CUDA 12.8.1 + clang）
# ==================================================
INSTALL_TENSORFLOW="${INSTALL_TENSORFLOW:-true}"

if [[ "$INSTALL_TENSORFLOW" == "true" ]]; then
  echo "🧠 [6.4] 编译 TensorFlow（maludwig/ml/attempting_build_rtx5090 分支）..."
  MAIN_REPO_DIR="/app/webui/sd-webui-forge"
  TF_SRC_DIR="${MAIN_REPO_DIR}/tensorflow-src"
  TF_SUCCESS_MARKER="${MAIN_REPO_DIR}/.tf_build_success_marker"
  TF_INSTALLED_VERSION=$(python -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null || echo "not_installed")
  SKIP_TF_BUILD=false

  if [[ "$TF_INSTALLED_VERSION" != "not_installed" ]]; then
    TF_IS_GPU=$(python -c "import tensorflow as tf; print(len(tf.config.list_physical_devices('GPU')) > 0)" 2>/dev/null)
    [[ "$TF_IS_GPU" == "True" ]] && echo "✅ 已检测到 TensorFlow: $TF_INSTALLED_VERSION（支持 GPU）" || echo "⚠️ 已检测到 TensorFlow: $TF_INSTALLED_VERSION（仅支持 CPU）"
    SKIP_TF_BUILD=true
  fi

  if [[ "$SKIP_TF_BUILD" != "true" && ! -f "$TF_SUCCESS_MARKER" ]]; then
    echo "🔧 未检测到 GPU 版 TensorFlow，开始源码构建..."

    if [[ ! -d "$TF_SRC_DIR/.git" ]]; then
      echo " - 克隆 TensorFlow 主仓库..."
      git clone https://github.com/tensorflow/tensorflow.git "$TF_SRC_DIR" || exit 1
      cd "$TF_SRC_DIR" || exit 1
      echo " - 添加 maludwig 分支并切换..."
      git remote add maludwig https://github.com/maludwig/tensorflow.git
      git fetch --all
      git checkout ml/attempting_build_rtx5090 || git checkout -b ml/attempting_build_rtx5090 maludwig/ml/attempting_build_rtx5090 || exit 1
      git pull maludwig ml/attempting_build_rtx5090
    else
      echo " - 已存在 TensorFlow 源码目录: $TF_SRC_DIR"
      cd "$TF_SRC_DIR" || exit 1
    fi

    git submodule update --init --recursive

    echo "🔍 构建前环境确认（Clang / CUDA / cuDNN / NCCL）"
    CLANG_PATH="$(which clang || echo '/usr/lib/llvm-20/bin/clang')"
    LLVM_CONFIG_PATH="$(which llvm-config || echo '/usr/lib/llvm-20/bin/llvm-config')"
    echo " - Clang 路径: $CLANG_PATH"; $CLANG_PATH --version | head -n 1 || echo "❌ 未找到 clang"
    echo " - LLVM Config 路径: $LLVM_CONFIG_PATH"; $LLVM_CONFIG_PATH --version || echo "❌ 未找到 llvm-config"
    echo " - Bazel 版本:"; bazel --version || echo "❌ 未找到 Bazel"

    echo "📦 CUDA:"; which nvcc; nvcc --version || echo "❌ 未找到 nvcc"
    echo "📁 CUDA 路径: ${CUDA_HOME:-/usr/local/cuda}"; ls -ld /usr/local/cuda* || echo "❌ 未找到 CUDA 安装目录"
    [[ -L /usr/local/cuda-12.8/lib/lib64 ]] && echo "⚠️ 检测到递归符号链接，建议修复: rm -r lib && ln -s lib64 lib"
    [[ ! -f /usr/local/cuda-12.8/lib64/libcudart_static.a ]] && echo "⚠️ 未找到 libcudart_static.a，建议：apt-get install --reinstall cuda-cudart-dev-12-8"

    echo "📦 cuDNN:"; find /usr -name "libcudnn.so*" | sort || echo "❌ 未找到 cuDNN"
    echo "📁 cuDNN 头文件:"; find /usr -name "cudnn.h" || echo "❌ 未找到 cudnn.h"

    echo "📦 NCCL:"; find /usr -name "libnccl.so*" | sort || echo "❌ 未找到 NCCL"
    echo "📁 NCCL 头文件:"; find /usr -name "nccl.h" || echo "❌ 未找到 nccl.h"

    echo "✅ 环境确认完成"

    cat > ../card_details.cu <<EOF
#include <cuda_runtime.h>
#include <cudnn.h>
#include <iostream>
int main() {
  cudaDeviceProp prop; int device;
  cudaGetDevice(&device); cudaGetDeviceProperties(&prop, device);
  size_t free_mem, total_mem; cudaMemGetInfo(&free_mem, &total_mem);
  std::cout << "> GPU: " << prop.name << "\\n> Compute: " << prop.major << "." << prop.minor << "\\n> VRAM: "
            << (total_mem - free_mem) / (1024 * 1024) << "/" << total_mem / (1024 * 1024) << " MB\\n";
  std::cout << "> cuDNN: " << CUDNN_MAJOR << "." << CUDNN_MINOR << "." << CUDNN_PATCHLEVEL << std::endl;
  return 0;
}
EOF

    echo "🧪 使用 nvcc 编译测试程序"; nvcc -o ../card_details_nvcc ../card_details.cu && ../card_details_nvcc || echo "❌ nvcc 编译失败"
    echo "🧪 使用 clang++ 编译测试程序"
    clang++ -std=c++17 --cuda-gpu-arch=sm_89 -x cuda ../card_details.cu -o ../card_details_clang \
      --cuda-path=/usr/local/cuda-12.8 \
      -I/usr/local/cuda-12.8/include \
      -L/usr/local/cuda-12.8/lib64 \
      -lcudart && ../card_details_clang || echo "❌ clang++ 编译失败"

    export LLVM_HOME="/usr/lib/llvm-20"
    export CUDA_HOME="/usr/local/cuda-12.8"
    export PATH="$LLVM_HOME/bin:$CUDA_HOME/bin:$PWD/../venv/bin:$PATH"
    export LD_LIBRARY_PATH="$CUDA_HOME/lib64:$LD_LIBRARY_PATH"
    export CPATH="$CUDA_HOME/include:$CPATH"
    export HERMETIC_CUDA_VERSION="12.8.1"
    export HERMETIC_CUDNN_VERSION="9.8.0"
    export HERMETIC_CUDA_COMPUTE_CAPABILITIES="compute_89"
    export LOCAL_CUDA_PATH="$CUDA_HOME"
    export LOCAL_NCCL_PATH="/usr/lib/x86_64-linux-gnu"
    export TF_NEED_CUDA=1
    export CLANG_CUDA_COMPILER_PATH="$CLANG_PATH"

    echo "⚙️ 执行 configure.py..."
    python configure.py 2>&1 | tee ../tf_configure_log.txt || { echo "❌ configure.py 执行失败"; exit 1; }

    echo "🧹 执行 bazel clean --expunge..."; bazel clean --expunge

    echo "🚀 构建 TensorFlow..."
    bazel build //tensorflow/tools/pip_package:wheel \
      --repo_env=WHEEL_NAME=tensorflow \
      --config=cuda \
      --config=cuda_clang \
      --config=cuda_wheel \
      --config=v2 \
      --jobs=$(nproc) \
      --copt=-Wno-error \
      --copt=-Wno-c23-extensions \
      --copt=-Wno-gnu-offsetof-extensions \
      --copt=-Wno-macro-redefined \
      --verbose_failures || {
        echo "❌ Bazel 构建失败，尝试 fallback 安装 tf-nightly..."
        pip install tf-nightly && echo "✅ fallback 安装成功，继续执行..." || { echo "❌ fallback 安装失败"; exit 1; }
      }

    if ls bazel-bin/tensorflow/tools/pip_package/wheel_house/tensorflow-*.whl 1>/dev/null 2>&1; then
      echo "📦 安装 TensorFlow pip 包..."
      pip install bazel-bin/tensorflow/tools/pip_package/wheel_house/tensorflow-*.whl || { echo "❌ 安装失败"; exit 1; }
      echo "✅ TensorFlow 构建并安装完成"
      touch "$TF_SUCCESS_MARKER"
    fi

    cd "$MAIN_REPO_DIR"
  else
    echo "✅ TensorFlow 已构建或安装，跳过源码构建"
  fi
fi

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

deactivate

# ==================================================
# 资源下载 (使用 resources.txt)
# ==================================================
echo "📦 [9] 处理资源下载 (基于 $PWD/resources.txt 和下载开关)..."
RESOURCE_PATH="$PWD/resources.txt"  # 资源列表文件路径现在使用 $PWD

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
  "$PWD/extensions/stable-diffusion-aws-extension"
  "$PWD/extensions/sd_dreambooth_extension"
  "$PWD/extensions/stable-diffusion-webui-aesthetic-image-scorer"
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

  # 在目标路径前加上 $PWD
  full_target_path="$PWD/$target_path"

  # 检查是否在黑名单中
  if should_skip "$full_target_path"; then
    echo "    - ⛔ 跳过黑名单条目: $full_target_path"
    continue # 处理下一行
  fi

  # 根据目标路径判断资源类型并调用相应下载函数及正确的独立开关
  case "$full_target_path" in
    # 1. Extensions
    "$PWD/extensions/"*)
        clone_or_update_repo "$target_path" "$source_url" # Uses ENABLE_DOWNLOAD_EXTS internally
        ;;

    # 2. Stable Diffusion Checkpoints
    "$PWD/models/Stable-diffusion/SD1.5/"*)
        download_with_progress "$target_path" "$source_url" "SD 1.5 Checkpoint" "$ENABLE_DOWNLOAD_MODEL_SD15"
        ;;

    "$PWD/models/Stable-diffusion/XL/"*)
        download_with_progress "$target_path" "$source_url" "SDXL Checkpoint" "$ENABLE_DOWNLOAD_MODEL_SDXL"
        ;;

    "$PWD/models/Stable-diffusion/flux/"*)
        download_with_progress "$target_path" "$source_url" "FLUX Checkpoint" "$ENABLE_DOWNLOAD_MODEL_FLUX"
        ;;

    "$PWD/models/Stable-diffusion/*") # Fallback
        echo "    - ❓ 处理未分类 Stable Diffusion 模型: $full_target_path (默认使用 SD1.5 开关)"
        download_with_progress "$target_path" "$source_url" "SD 1.5 Checkpoint (Fallback)" "$ENABLE_DOWNLOAD_MODEL_SD15"
        ;;

    # 3. VAEs
    "$PWD/models/VAE/flux-*.safetensors") # FLUX Specific VAE
        download_with_progress "$target_path" "$source_url" "FLUX VAE" "$ENABLE_DOWNLOAD_VAE_FLUX" # Use specific FLUX VAE switch
        ;;

    "$PWD/models/VAE/*") # Other VAEs
        download_with_progress "$target_path" "$source_url" "VAE Model" "$ENABLE_DOWNLOAD_VAE"
        ;;

    # 4. Text Encoders (Currently FLUX specific)
    "$PWD/models/text_encoder/"*)
    download_with_progress "$target_path" "$source_url" "Text Encoder" "$ENABLE_DOWNLOAD_TE"
    ;;

    # 5. ControlNet Models
    "$PWD/models/ControlNet/"*)
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
    "$PWD/models/Lora/*" | "$PWD/models/LyCORIS/*" | "$PWD/models/LoCon/*")
        download_with_progress "$target_path" "$source_url" "LoRA/LyCORIS" "$ENABLE_DOWNLOAD_LORAS"
        ;;

    # 7. Embeddings / Textual Inversion
    "$PWD/models/TextualInversion/*" | "$PWD/embeddings/*")
       download_with_progress "$target_path" "$source_url" "Embedding/Textual Inversion" "$ENABLE_DOWNLOAD_EMBEDDINGS"
       ;;

    # 8. Upscalers
    "$PWD/models/Upscaler/*" | "$PWD/models/ESRGAN/*")
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

echo "🚀 [11] 所有准备就绪，使用 venv 启动 webui.sh ..."

# 设置跳过 Forge 环境流程的参数，并合并用户自定义参数
echo "🧠 设置启动参数 COMMANDLINE_ARGS"
export COMMANDLINE_ARGS="--cuda-malloc --skip-python-version-check --skip-torch-cuda-test $ARGS"

# 验证启动参数
echo "🧠 启动参数: $COMMANDLINE_ARGS"

# 启动 WebUI 脚本，正确传递参数
echo "🚀 [11] 启动命令: exec \"$PWD/webui.sh\" $COMMANDLINE_ARGS"
set -- $COMMANDLINE_ARGS
exec "$PWD/webui.sh" "$@"
