#!/bin/bash

set -e
set -o pipefail

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

# CUDA & GPU 检查（使用 nvidia-smi 原始图表）
if command -v nvidia-smi &>/dev/null; then
  echo "✅ nvidia-smi 检测成功，GPU 原始信息如下："
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

export NO_TCMALLOC="${NO_TCMALLOC:-1}"
export PIP_EXTRA_INDEX_URL="${PIP_EXTRA_INDEX_URL:-https://download.pytorch.org/whl/cu128}"
export TORCH_COMMAND="${TORCH_COMMAND:-pip install torch==2.7.0+cu128 --extra-index-url https://download.pytorch.org/whl/cu128}"

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

# ---------------------------------------------------
# requirements_versions.txt 修复
# ---------------------------------------------------
echo "🔧 [5] 补丁修正 requirements_versions.txt..."
REQ_FILE="$PWD/requirements_versions.txt"
USER_PINS_FILE="$PWD/requirements_user_pins.txt"

# 如果用户未提供锁定文件，则自动下载一份默认模板
if [ ! -f "$USER_PINS_FILE" ]; then
  echo "🌐 未检测到 $USER_PINS_FILE，尝试从远程仓库下载..."
  if curl -fsSL -o "$USER_PINS_FILE" "https://raw.githubusercontent.com/amDosion/forage/main/requirements_user_pins.txt"; then
    echo "✅ 成功下载默认 user_pins 文件 → $USER_PINS_FILE"
  else
    echo "⚠️ 下载失败，创建空文件作为占位"
    touch "$USER_PINS_FILE"
  fi
else
  echo "✅ 已检测到本地 $USER_PINS_FILE，跳过远程下载"
fi

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

# 从文件读取用户锁定版本（支持增量覆盖）
echo "📥 读取用户自定义依赖版本..."
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  if [[ "$line" =~ ^([a-zA-Z0-9._+-]+)==([a-zA-Z0-9._+-]+)$ ]]; then
    package="${BASH_REMATCH[1]}"
    version="${BASH_REMATCH[2]}"
    add_or_replace_requirement "$package" "$version"
  else
    echo "⚠️ 跳过无效行: $line"
  fi
done < "$USER_PINS_FILE"

# 🧹 清理注释和空行
echo "🧹 清理注释内容..."
CLEANED_REQ_FILE="${REQ_FILE}.cleaned"
sed 's/#.*//' "$REQ_FILE" | sed '/^\s*$/d' > "$CLEANED_REQ_FILE"
mv "$CLEANED_REQ_FILE" "$REQ_FILE"

# ♻️ 去重（按包名保留最后一次）
echo "🧹 去重重复依赖项..."
DEDUPED_FILE="${REQ_FILE}.deduped"
tac "$REQ_FILE" | awk -F== '!seen[$1]++' | tac > "$DEDUPED_FILE"
mv "$DEDUPED_FILE" "$REQ_FILE"

# ✅ 输出最终依赖列表
echo "📄 最终依赖列表如下："
cat "$REQ_FILE"

# ---------------------------------------------------
# Python 虚拟环境
# ---------------------------------------------------
cd "$TARGET_DIR"
chmod -R 777 .

echo "🐍 [6] 虚拟环境检查..."

if [ ! -x "venv/bin/activate" ]; then
  echo "📦 创建 venv..."
  python3 -m venv venv

  echo "🔧 激活 venv..."
  # shellcheck source=/dev/null
  source venv/bin/activate

  echo "🔧 [6.1.1] 安装工具包：insightface, huggingface_hub[cli]..."

  # ---------------------------------------------------
  # 安装工具包（insightface 和 huggingface-cli）
  # ---------------------------------------------------
echo "🔍 检查 insightface 是否已安装..."
if python -m pip show insightface | grep -q "Version"; then
  echo "✅ insightface 已安装，跳过安装"
else
  echo "📦 安装 insightface..."
  python -m pip install --upgrade insightface
fi

echo "📦 venv 安装完成 ✅"
deactivate

else
  echo "✅ venv 已存在，跳过创建和安装"
fi

echo "🔧 激活 venv..."
# shellcheck source=/dev/null
source venv/bin/activate
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

# ---------------------------------------------------
# 创建目录
# ---------------------------------------------------
echo "📁 [7] 初始化项目目录结构..."
mkdir -p extensions models models/ControlNet outputs

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

# ==================================================
# 资源下载 (使用 resources.txt)
# ==================================================
echo "📦 [9] 处理资源下载 (基于 $PWD/resources.txt 和下载开关)..."
RESOURCE_PATH="$PWD/resources.txt"

# ✅ 然后继续执行原来的资源遍历逻辑
echo "  - 开始处理 resources.txt 中的条目..."

# 检查资源文件是否存在，如果不存在则尝试下载默认版本
if [ ! -f "$RESOURCE_PATH" ]; then
  # 指定默认资源文件的 URL
  DEFAULT_RESOURCE_URL="https://raw.githubusercontent.com/amDosion/forage/main/resources.txt"
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

# ✅ ✅ ✅ 添加此段：记录 resources.txt 中声明的插件路径
declare -A RESOURCE_DECLARED_PATHS

while IFS=, read -r target_path source_url || [[ -n "$target_path" ]]; do
  target_path=$(echo "$target_path" | xargs)
  source_url=$(echo "$source_url" | xargs)

  [[ "$target_path" =~ ^#.*$ || -z "$target_path" || -z "$source_url" ]] && continue

  # 如果是 extensions 路径则加入映射
  if [[ "$target_path" == extensions/* ]]; then
    full_path="$PWD/$target_path"
    RESOURCE_DECLARED_PATHS["$full_path"]=1
  fi
done < "$RESOURCE_PATH"


# ✅✅✅ 检查本地 extensions 目录中未在 resources.txt 中声明的插件
EXT_DIR="$PWD/extensions"
if [ -d "$EXT_DIR" ]; then
  echo "🧹 检查本地 extensions/ 中未声明的插件..."
  for existing_path in "$EXT_DIR"/*; do
    if [ -d "$existing_path" ]; then
      if [[ -z "${RESOURCE_DECLARED_PATHS[$existing_path]}" ]]; then
        echo "    - ⛔ 插件未在 resources.txt 声明，跳过处理: $(basename "$existing_path")"
      fi
    fi
  done
fi

# 定义函数：克隆或更新 Git 仓库 (支持独立 Git 镜像开关 + 资源控制)
clone_or_update_repo() {
    # $1: 目标目录, $2: 原始仓库 URL
    local dir="$1" repo_original="$2"
    local dirname
    local repo_url # URL to be used for cloning/pulling
    local full_path="$PWD/$dir"

    dirname=$(basename "$dir")

    # ✅ 新增：只允许处理 resources.txt 中声明的插件路径
    if [[ -n "$RESOURCE_PATH" && -n "${RESOURCE_DECLARED_PATHS[$full_path]}" ]]; then
        : # 路径被声明，继续
    else
        echo "    - ⚠️ 插件未在 resources.txt 中声明，跳过 Git 操作: $dirname"
        return
    fi

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
    fi
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
# 🔥 启动最终服务（FIXED!）
# ---------------------------------------------------
echo "🚀 [11] 所有准备就绪，启动 webui.sh ..."

exec bash webui.sh $ARGS
