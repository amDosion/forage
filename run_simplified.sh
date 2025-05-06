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

# ==================================================
# 日志配置
# ==================================================

# 若日志文件存在则清空内容
if [[ -f "$LOG_FILE" ]]; then

fi
# 确保日志目录存在

# 将所有标准输出和错误输出重定向到文件和控制台

# ==================================================
# 🔒 [6.2] sudo 安装检查（确保 root 可切换为 webui 用户）
# ==================================================
# pip 检查 (通过 python -m pip 调用)
if python3.11 -m pip --version &>/dev/null; then

else

  exit 1
fi

# 容器检测
if [ -f "/.dockerenv" ]; then

else

fi

# 用户检查 (应为 webui)

# 工作目录写入权限检查
if [ -w "/app/webui" ]; then

else

  # 允许继续，以便在具体步骤中捕获错误
fi

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

# 预定义镜像地址 (如果需要可以从环境变量读取，但简单起见先硬编码)
HF_MIRROR_URL="https://hf-mirror.com"
GIT_MIRROR_URL="https://gitcode.net" # 使用 https

# ---------------------------------------------------
# 设置 Git 源路径
# ---------------------------------------------------

if [ "$UI" = "auto" ]; then
  TARGET_DIR="/app/webui/sd-webui"
  REPO="https://github.com/AUTOMATIC1111/stable-diffusion-webui.git"
elif [ "$UI" = "forge" ]; then
  TARGET_DIR="/app/webui/sd-webui-forge"
  REPO="https://github.com/lllyasviel/stable-diffusion-webui-forge.git"
else

  exit 1
fi

# ---------------------------------------------------
# 克隆/更新仓库
# ---------------------------------------------------
if [ -d "$TARGET_DIR/.git" ]; then

  git -C "$TARGET_DIR" pull --ff-only || echo "⚠️ Git pull failed"
else

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

# ==================================================
# 克隆/更新 WebUI 仓库
# ==================================================
# 如果目录中存在.git文件，说明已经克隆过仓库，尝试更新
if [ -d ".git" ]; then

  git pull --ff-only || echo "⚠️ Git pull 失败，可能是本地有修改或网络问题。将继续使用当前版本。"
else

  # 使用完整克隆（非浅克隆），并初始化子模块（推荐）
  git clone --recursive "$REPO" . || { echo "❌ 克隆仓库失败"; exit 1; }

  # 赋予启动脚本执行权限
  if [ -f "$WEBUI_EXECUTABLE" ]; then
    chmod +x "$WEBUI_EXECUTABLE"

  else

    exit 1
  fi
fi

# 赋予启动脚本执行权限
if [ -f "webui.sh" ]; then
  chmod +x "webui.sh"

else

  exit 1  # 如果找不到启动脚本，可以选择退出
fi

# 赋予启动脚本执行权限
if [ -f "webui-user.sh" ]; then
  chmod +x "webui-user.sh"

else

  exit 1  # 如果找不到启动脚本，可以选择退出
fi

# 赋予启动脚本执行权限
if [ -f "launch.py" ]; then
  chmod +x "launch.py"

else

  exit 1  # 如果找不到启动脚本，可以选择退出
fi

# =========================================
# 补丁修正 launch_utils.py 强制 torch 版本
# =========================================
PATCH_URL="https://raw.githubusercontent.com/amDosion/forage/main/force_torch_version.patch"
PATCH_FILE="force_torch_version.patch"

curl -fsSL -o "$PATCH_FILE" "$PATCH_URL" || { echo "❌ 补丁文件下载失败"; exit 1; }

# 检查 patch 是否已经打过，防止重复 patch
if patch --dry-run -p1 < "$PATCH_FILE" > /dev/null 2>&1; then

    patch -p1 < "$PATCH_FILE" || { echo "❌ 应用补丁失败"; exit 1; }

else

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

  git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui-assets.git "$REPO_ASSETS_DIR" || echo "❌ 克隆 stable-diffusion-webui-assets 仓库失败"
else

fi

# 克隆 huggingface_guess 仓库（如果尚未克隆）
REPO_HUGGINGFACE_GUESS_DIR="$REPOSITORIES_DIR/huggingface_guess"
if [ ! -d "$REPO_HUGGINGFACE_GUESS_DIR" ]; then

  git clone https://github.com/lllyasviel/huggingface_guess.git "$REPO_HUGGINGFACE_GUESS_DIR" || echo "❌ 克隆 huggingface_guess 仓库失败"
else

fi

# 克隆 BLIP 仓库（如果尚未克隆）
REPO_BLIP_DIR="$REPOSITORIES_DIR/BLIP"
if [ ! -d "$REPO_BLIP_DIR" ]; then

  git clone https://github.com/salesforce/BLIP.git "$REPO_BLIP_DIR" || echo "❌ 克隆 BLIP 仓库失败"
else

fi

# 克隆 google_blockly_prototypes 仓库（如果尚未克隆）
REPO_GOOGLE_BLOCKLY_DIR="$REPOSITORIES_DIR/google_blockly_prototypes"
if [ ! -d "$REPO_GOOGLE_BLOCKLY_DIR" ]; then

  git clone https://github.com/lllyasviel/google_blockly_prototypes.git "$REPO_GOOGLE_BLOCKLY_DIR" || echo "❌ 克隆 google_blockly_prototypes 仓库失败"
else

fi

# ---------------------------------------------------
# requirements_versions.txt 修复
# ---------------------------------------------------

REQ_FILE="$PWD/requirements_versions.txt"
touch "$REQ_FILE"

# 添加或替换某个依赖版本
add_or_replace_requirement() {
  local package="$1"
  local version="$2"
  if grep -q "^$package==" "$REQ_FILE"; then

    sed -i "s|^$package==.*|$package==$version|" "$REQ_FILE"
  else

  fi
}

# 推荐依赖版本（将统一写入或替换）
add_or_replace_requirement "diffusers" "0.31.0"
add_or_replace_requirement "transformers" "4.46.1"
add_or_replace_requirement "torchdiffeq" "0.2.3"
add_or_replace_requirement "torchsde" "0.2.6"
add_or_replace_requirement "protobuf" "4.25.3"
add_or_replace_requirement "pydantic" "2.6.4"
add_or_replace_requirement "open-clip-torch" "2.24.0"
add_or_replace_requirement "GitPython" "3.1.41"

# 🧹 清理注释和空行，保持纯净格式

CLEANED_REQ_FILE="${REQ_FILE}.cleaned"
sed 's/#.*//' "$REQ_FILE"
mv "$CLEANED_REQ_FILE" "$REQ_FILE"

# ✅ 输出最终依赖列表

cat "$REQ_FILE"

# 设置 Python 命令
python_cmd="${PYTHON_CMD:-python3.11}"

# 定义虚拟环境目录
VENV_DIR="$PWD/venv"

# 检查虚拟环境是否已存在
if [[ ! -d "${VENV_DIR}" ]]; then

  "${python_cmd}" -m venv "${VENV_DIR}" || { echo "❌ 创建虚拟环境失败，请检查 python3-venv 是否安装"; exit 1; }

  # 用 venv 内的 Python 升级 pip
  "${VENV_DIR}/bin/python" -m pip install --upgrade pip
else

fi

# 激活虚拟环境
if [[ -f "${VENV_DIR}/bin/activate" ]]; then

  source "${VENV_DIR}/bin/activate"

  # 激活后，强制更新 python_cmd 指向 venv
  python_cmd="${VENV_DIR}/bin/python"
else

  exit 1
fi

# 确认当前 Python 环境

# ---------------------------------------------------
# 升级 pip
# ---------------------------------------------------

"${python_cmd}" -m pip install --upgrade pip | tee -a "$LOG_FILE"

# ---------------------------------------------------
# 安装 huggingface-cli 工具
# ---------------------------------------------------

if "${python_cmd}" -m pip show huggingface-hub | grep -q "Version"; then

else

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

    else

    fi
done

# ==================================================
# 网络测试 (可选)
# ==================================================

NET_OK=false # 默认网络不通
# 使用 curl 测试连接，设置超时时间
if curl -fsS --connect-timeout 5 https://huggingface.co > /dev/null; then
  NET_OK=true

else
  # 如果 Hugging Face 不通，尝试 GitHub 作为备选检查
  if curl -fsS --connect-timeout 5 https://github.com > /dev/null; then
      NET_OK=true # 至少 Git 相关操作可能成功

  else

  fi
fi

# ==================================================
# 安装 WebUI 核心依赖 (基于 UI 类型)
# ==================================================

# ==================================================
# 根据 UI 类型决定依赖处理方式
# ==================================================
if [ "$UI" = "forge" ]; then

    INSTALL_TORCH="${INSTALL_TORCH:-true}"
    if [[ "$INSTALL_TORCH" == "true" ]]; then
        TORCH_COMMAND="pip install torch=="$TORCH_VERSION" torchvision=="$TORCHVISION_VERSION" torchaudio=="$TORCHAUDIO_VERSION" --extra-index-url "$TORCH_INDEX_URL"

        $TORCH_COMMAND && echo "    ✅ PyTorch 安装成功" || echo "    ❌ PyTorch 安装失败"
    else

    fi

    # 🔧 安装其他核心依赖（升级主依赖，跳过 xformers + tensorflow）
    REQ_FILE="$PWD/requirements_versions.txt"
    if [ -f "$REQ_FILE" ]; then

        sed -i 's/\r$//' "$REQ_FILE"

        while IFS= read -r line || [[ -n "$line" ]]; do
            # 去除注释和空白
            clean_line=$(echo "$line"
            [[ -z "$clean_line" ]] && continue

            # 提取包名（支持 ==、>=、<=、~= 形式）
            pkg_name=$(echo "$clean_line" | cut -d '=' -f1 | cut -d '<' -f1 | cut -d '>' -f1 | cut -d '~' -f1)

            # 跳过已从源码构建的依赖
            if [[ "$pkg_name" == *xformers* ]]; then

                continue
            fi

            if [[ "$pkg_name" == "tensorflow" || "$pkg_name" == "tf-nightly" ]]; then

                continue
            fi

            # 已安装则跳过（避免覆盖 auto 安装的依赖）
            if pip show "$pkg_name" > /dev/null 2>&1; then

                continue
            fi

            # 安装主包（不锁版本）

            pip install --upgrade --no-cache-dir "$pkg_name" --extra-index-url "$PIP_EXTRA_INDEX_URL" 2>&1 \
                | tee -a "$LOG_FILE" \

            if [ ${PIPESTATUS[0]} -ne 0 ]; then

            fi
        done < "$REQ_FILE"

    else

    fi

else

    REQ_FILE="$PWD/requirements_versions.txt"
    if [ -f "$REQ_FILE" ]; then
        sed -i 's/\r$//' "$REQ_FILE"

        while IFS= read -r line || [[ -n "$line" ]]; do
            clean_line=$(echo "$line"
            [[ -z "$clean_line" ]] && continue

            pip install "$clean_line" --no-cache-dir --extra-index-url "$PIP_EXTRA_INDEX_URL" 2>&1 \
                | tee -a "$LOG_FILE" \

            if [ ${PIPESTATUS[0]} -ne 0 ]; then

            fi
        done < "$REQ_FILE"

    else

    fi
fi

# 自动检查并安装缺失的库
check_and_install_package() {
    local package=$1
    local version=$2

    # 检查库是否已经安装
    if ! python -c "import $package" >/dev/null 2>&1; then

        
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

TARGET_VERSION="0.0.30+0b3963ad"

# 获取当前已安装的 xformers 版本（如果有）
INSTALLED_VERSION=$(python -c "import importlib.metadata as m; print(m.version('xformers'))" 2>/dev/null || echo "none")

if [ "$INSTALLED_VERSION" = "$TARGET_VERSION" ]; then

else
    if [ "$INSTALLED_VERSION" != "none" ]; then

        pip uninstall -y xformers
    else

    fi

    pip install https://huggingface.co/Alissonerdx/xformers-0.0.30-torch2.7.0-cuda12.8/resolve/main/xformers-0.0.30%2B0b3963ad.d20250210-cp312-cp312-linux_x86_64.whl
fi

# ==================================================
# Token 处理 (Hugging Face, Civitai)
# ==================================================
# 步骤号顺延为 [10]

# 处理 Hugging Face Token (如果环境变量已设置)
if [[ -n "$HUGGINGFACE_TOKEN" ]]; then

  # 检查 huggingface-cli 命令是否存在 (应由 huggingface_hub[cli] 提供)
  if command -v huggingface-cli &>/dev/null; then
      # 正确用法：将 token 作为参数传递给 --token
      huggingface-cli login --token "$HUGGINGFACE_TOKEN" --add-to-git-credential
      # 检查命令执行是否成功
      if [ $? -eq 0 ]; then

      else
          # 登录失败通常不会是致命错误，只记录警告

      fi
  else

  fi
else
  # 如果未提供 Token

fi

# 检查 Civitai API Token
if [[ -n "$CIVITAI_API_TOKEN" ]]; then

else

fi

deactivate

# ==================================================
# 资源下载 (使用 resources.txt)
# ==================================================

RESOURCE_PATH="$PWD/resources.txt"  # 资源列表文件路径现在使用 $PWD

# 检查资源文件是否存在，如果不存在则尝试下载默认版本
if [ ! -f "$RESOURCE_PATH" ]; then
  # 指定默认资源文件的 URL
  DEFAULT_RESOURCE_URL="https://raw.githubusercontent.com/chuan1127/SD-webui-forge/main/resources.txt"

  # 使用 curl 下载，确保失败时不输出错误页面 (-f)，静默 (-s)，跟随重定向 (-L)
  curl -fsSL -o "$RESOURCE_PATH" "$DEFAULT_RESOURCE_URL"
  if [ $? -eq 0 ]; then

  else

      # 创建一个空文件以避免后续读取错误，但不会下载任何内容
      touch "$RESOURCE_PATH"

  fi
else

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
        git_mirror_host=$(echo "$GIT_MIRROR_URL"
        repo_url=$(echo "$repo_original"

    else
        repo_url="$repo_original"
    fi

    # 检查扩展下载开关
    if [[ "$ENABLE_DOWNLOAD_EXTS" != "true" ]]; then
        if [ -d "$dir" ]; then

        else

        fi
        return
    fi

    # 尝试更新或克隆
    if [ -d "$dir/.git" ]; then

        (cd "$dir" && git pull --ff-only) || echo "      ⚠️ Git pull 失败: $dirname (可能存在本地修改或网络问题)"
    elif [ ! -d "$dir" ]; then

        git clone --recursive "$repo_url" "$dir" || echo "      ❌ Git clone 失败: $dirname (检查 URL: $repo_url 和网络)"
    else

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

        return
    fi
    # 检查网络
    if [[ "$NET_OK" != "true" ]]; then

        return
    fi

    # 检查是否启用了 HF 镜像以及是否是 Hugging Face URL
    # 使用步骤 [2] 中定义的 HF_MIRROR_URL
    if [[ "$USE_HF_MIRROR" == "true" && "$url_original" == "https://huggingface.co/"* ]]; then
        # 替换 huggingface.co 为镜像地址
        download_url=$(echo "$url_original"

    else
        # 使用原始 URL
        download_url="$url_original"
    fi

    # 检查文件是否已存在
    if [ ! -f "$output_path" ]; then

        mkdir -p "$(dirname "$output_path")"
        # 执行下载
        wget --progress=bar:force:noscroll --timeout=120 -O "$output_path" "$download_url"
        # 检查结果
        if [ $? -ne 0 ]; then

            rm -f "$output_path"
        else

        fi
    else

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

             clone_or_update_repo "$target_path" "$source_url" # Uses ENABLE_DOWNLOAD_EXTS internally
        elif [[ "$source_url" == http* ]]; then

             download_with_progress "$target_path" "$source_url" "Unknown Model/File" "$ENABLE_DOWNLOAD_MODEL_SD15"
        else

        fi
        ;;
  esac # 结束 case
done < "$RESOURCE_PATH" # 从资源文件读取

# 设置跳过 Forge 环境流程的参数，并合并用户自定义参数

export COMMANDLINE_ARGS="--cuda-malloc --skip-python-version-check --skip-torch-cuda-test $ARGS"

# 验证启动参数

# 启动 WebUI 脚本，正确传递参数

set -- $COMMANDLINE_ARGS
exec "$PWD/webui.sh" "$@"
