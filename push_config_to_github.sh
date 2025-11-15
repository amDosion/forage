#!/bin/bash

# ================================================================
# 配置文件推送脚本
# Push Configuration Files to GitHub Repository
# ================================================================

set -e

echo "🚀 配置文件 GitHub 推送脚本"
echo "=================================================="

# 加载环境变量
if [ -f "/app/.env" ]; then
    ENV_FILE="/app/.env"
elif [ -f "$(dirname "$0")/.env" ]; then
    ENV_FILE="$(dirname "$0")/.env"
else
    echo "❌ 错误: 未找到 .env 文件"
    exit 1
fi

# 安全地加载环境变量
export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | grep '=' | sed 's/=.*//' | xargs)
while IFS='=' read -r key value; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    export "$key=$value"
done < <(grep -v '^#' "$ENV_FILE" | grep -v '^$' | grep '=')

# 检查必需的环境变量
if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️ 警告: GITHUB_TOKEN 未设置，无法推送到 GitHub"
    echo "请在 .env 文件中设置 GITHUB_TOKEN"
    echo "获取地址: https://github.com/settings/tokens"
    exit 1
fi

if [ -z "$GITHUB_CONFIG_REPO" ]; then
    echo "❌ 错误: GITHUB_CONFIG_REPO 未设置"
    exit 1
fi

GITHUB_CONFIG_BRANCH="${GITHUB_CONFIG_BRANCH:-main}"
TEMP_DIR="/tmp/github-config-push"
REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_CONFIG_REPO}.git"

echo "📦 目标仓库: ${GITHUB_CONFIG_REPO}"
echo "🌿 目标分支: ${GITHUB_CONFIG_BRANCH}"
echo ""

# 清理并创建临时目录
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# 克隆仓库
echo "📥 克隆仓库..."
git clone --depth 1 --branch "$GITHUB_CONFIG_BRANCH" "$REPO_URL" repo 2>&1 | grep -v "github_pat" || {
    echo "❌ 克隆失败，请检查:"
    echo "  1. GitHub Token 是否有效"
    echo "  2. 仓库名称是否正确: ${GITHUB_CONFIG_REPO}"
    echo "  3. 分支名称是否正确: ${GITHUB_CONFIG_BRANCH}"
    echo "  4. Token 是否有仓库访问权限"
    rm -rf "$TEMP_DIR"
    exit 1
}

cd repo

# 配置 Git 用户信息
git config user.name "WebUI Automation"
git config user.email "webui@automation.local"

# 定义需要推送的文件列表
declare -A FILES_TO_PUSH=(
    ["/app/run.sh"]="run.sh"
    ["/app/webui/sd-webui-forge/requirements_user_pins.txt"]="requirements_user_pins.txt"
    ["/app/webui/sd-webui-forge/resources.txt"]="resources.txt"
    ["/tmp/push_files/Dockerfile"]="Dockerfile"
    ["/tmp/push_files/docker-compose.yml"]="docker-compose.yml"
    ["/tmp/push_files/start.sh"]="start.sh"
    ["/tmp/push_files/stop.sh"]="stop.sh"
    ["/app/push_config_to_github.sh"]="push_config_to_github.sh"
    ["/tmp/push_files/.env.example"]=".env.example"
    ["/tmp/push_files/.gitignore"]=".gitignore"
    ["/tmp/push_files/README.md"]="README.md"
    ["/tmp/push_files/GITHUB_PUSH_README.md"]="GITHUB_PUSH_README.md"
)

# 复制更新的配置文件
echo "📝 复制配置文件..."
CHANGED=false
FILES_UPDATED=()
FILES_NOCHANGE=()
FILES_MISSING=()

for source_path in "${!FILES_TO_PUSH[@]}"; do
    target_file="${FILES_TO_PUSH[$source_path]}"

    if [ -f "$source_path" ]; then
        cp "$source_path" "$target_file"

        # 检查是否有变化
        if git diff --quiet "$target_file" 2>/dev/null && [ -f "$target_file" ] && git ls-files --error-unmatch "$target_file" &>/dev/null; then
            FILES_NOCHANGE+=("$target_file")
        else
            FILES_UPDATED+=("$target_file")
            git add "$target_file"
            CHANGED=true
        fi
    else
        FILES_MISSING+=("$target_file (源: $source_path)")
    fi
done

# 输出处理结果
echo ""
echo "📊 文件处理结果:"
if [ ${#FILES_UPDATED[@]} -gt 0 ]; then
    echo "  ✅ 已更新 (${#FILES_UPDATED[@]}):"
    for file in "${FILES_UPDATED[@]}"; do
        echo "     - $file"
    done
fi

if [ ${#FILES_NOCHANGE[@]} -gt 0 ]; then
    echo "  ℹ️  无变化 (${#FILES_NOCHANGE[@]}):"
    for file in "${FILES_NOCHANGE[@]}"; do
        echo "     - $file"
    done
fi

if [ ${#FILES_MISSING[@]} -gt 0 ]; then
    echo "  ⚠️  文件缺失 (${#FILES_MISSING[@]}):"
    for file in "${FILES_MISSING[@]}"; do
        echo "     - $file"
    done
fi
echo ""

# 如果有变化，提交并推送
if [ "$CHANGED" = true ]; then
    echo ""
    echo "💾 提交更改..."

    # 生成更新文件列表
    FILE_LIST=""
    for file in "${FILES_UPDATED[@]}"; do
        FILE_LIST="${FILE_LIST}- ${file}\n"
    done

    git commit -m "chore: 更新配置文件 (v2.0)

更新的文件:
$(echo -e "$FILE_LIST")
主要改进:
- ✅ 扩展依赖自动修复 (hydra-core, send2trash, beautifulsoup4, ZipUnicode)
- ✅ 完善的环境变量配置
- ✅ 详细的项目文档
- ✅ 批量文件推送支持
- ✅ Git 忽略配置

🤖 自动生成于: $(date '+%Y-%m-%d %H:%M:%S')" || {
        echo "⚠️ 提交失败（可能没有变化）"
    }

    echo ""
    echo "🚀 推送到 GitHub..."
    git push origin "$GITHUB_CONFIG_BRANCH" 2>&1 | grep -v "github_pat" || {
        echo "❌ 推送失败"
        cd /
        rm -rf "$TEMP_DIR"
        exit 1
    }

    echo ""
    echo "✅ 成功推送到 ${GITHUB_CONFIG_REPO}"
    echo "🔗 查看变化: https://github.com/${GITHUB_CONFIG_REPO}/commits/${GITHUB_CONFIG_BRANCH}"
else
    echo ""
    echo "ℹ️ 没有需要推送的变化"
fi

# 清理
cd /
rm -rf "$TEMP_DIR"

echo ""
echo "=================================================="
echo "✨ 完成!"
