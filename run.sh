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
export COMMANDLINE_ARGS="${COMMANDLINE_ARGS:---xformers --precision autocast --cuda-malloc --cuda-stream --pin-shared-memory --opt-sdp-attention --no-half-vae --api --listen --enable-insecure-extension-access --skip-python-version-check --skip-torch-cuda-test --theme dark --loglevel DEBUG --ui-debug-mode --gradio-debug}"

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
# 🔒 [6.2] sudo 安装检查（确保 root 可换为 webui 用户）
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
  REPO="https://github.com/lllyasviel/stable-diffusion-webui-forge.git"
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
add_or_replace_requirement "xformers" "0.0.30"
add_or_replace_requirement "diffusers" "0.31.0"
add_or_replace_requirement "transformers" "4.46.1"
add_or_replace_requirement "torchdiffeq" "0.2.3"
add_or_replace_requirement "torchsde" "0.2.6"
add_or_replace_requirement "protobuf" "4.25.3"
add_or_replace_requirement "pydantic" "2.6.4"
add_or_replace_requirement "open-clip-torch" "2.24.0"
add_or_replace_requirement "GitPython" "3.1.41"
add_or_replace_requirement "insightface" "0.7.3"
add_or_replace_requirement "huggingface-hub" "0.30.2"

# 🧹 清理注释和空行，保持纯净格式
echo "🧹 清理注释内容..."
CLEANED_REQ_FILE="${REQ_FILE}.cleaned"
sed 's/#.*//' "$REQ_FILE" | sed '/^\s*$/d' > "$CLEANED_REQ_FILE"
mv "$CLEANED_REQ_FILE" "$REQ_FILE"

# ✅ 输出最终依赖列表
echo "📄 最终依赖列表如下："
cat "$REQ_FILE"

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


echo "🚀 [11] 所有准备就绪，使用 venv 启动 webui.sh ..."

# 设置跳过 Forge 环境流程的参数，并合并用户自定义参数
echo "🧠 启动参数: $COMMANDLINE_ARGS"

# 只传一次参数，避免重复
set -- $COMMANDLINE_ARGS
echo "🚀 [11] 启动命令: exec \"$PWD/webui.sh\" $@"
exec "$PWD/webui.sh" "$@"
