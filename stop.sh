#!/bin/bash

set -e

# ================================================================
# Forge WebUI - 停止脚本
# ================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="forge-webui"

echo "========================================================"
echo "🛑 Forge WebUI - 停止容器"
echo "========================================================"
echo ""

# 进入项目目录
cd "$SCRIPT_DIR" || { echo "❌ 无法进入项目目录"; exit 1; }

# 检查容器是否存在
if docker ps -a --filter "name=^/${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "🔍 检测到容器: $CONTAINER_NAME"

    # 停止并删除容器
    echo "🛑 停止并删除容器..."
    docker-compose down

    echo ""
    echo "✅ 容器已停止并删除"
else
    echo "ℹ️  容器不存在或已停止"
fi

echo ""
echo "========================================================"
echo "完成！"
echo "========================================================"
echo ""
echo "💡 重新启动容器："
echo "   ./start.sh"
echo ""
