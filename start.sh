#!/bin/bash

set -e

# ================================================================
# Forge WebUI - 自动构建和启动脚本
# ================================================================
# 功能：
# 1. 检查 Docker 镜像是否存在
# 2. 如果不存在，自动构建本地镜像
# 3. 如果存在，跳过构建
# 4. 启动容器
# ================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="forge-webui:latest"
CONTAINER_NAME="forge-webui"

echo "========================================================"
echo "🚀 Forge WebUI - 自动启动脚本"
echo "========================================================"
echo ""

# 进入项目目录
cd "$SCRIPT_DIR" || { echo "❌ 无法进入项目目录"; exit 1; }

# ----------------------------------------------------------------
# 检查 Docker 是否运行
# ----------------------------------------------------------------
echo "🔍 [1/4] 检查 Docker 服务..."
if ! docker info &>/dev/null; then
    echo "❌ Docker 服务未运行，请先启动 Docker"
    exit 1
fi
echo "✅ Docker 服务正常"
echo ""

# ----------------------------------------------------------------
# 检查镜像是否存在
# ----------------------------------------------------------------
echo "🔍 [2/4] 检查 Docker 镜像 ($IMAGE_NAME)..."
if docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "✅ 镜像已存在，跳过构建"
    SKIP_BUILD=true
else
    echo "⚠️  镜像不存在，需要构建"
    SKIP_BUILD=false
fi
echo ""

# ----------------------------------------------------------------
# 构建镜像（如果需要）
# ----------------------------------------------------------------
if [ "$SKIP_BUILD" = false ]; then
    echo "🔨 [3/4] 构建 Docker 镜像..."
    echo "   这可能需要 10-15 分钟，请耐心等待..."
    echo ""

    # 使用 docker-compose build
    if docker-compose build; then
        echo ""
        echo "✅ 镜像构建完成"
    else
        echo ""
        echo "❌ 镜像构建失败，请检查错误信息"
        exit 1
    fi
else
    echo "⏭️  [3/4] 跳过构建步骤"
fi
echo ""

# ----------------------------------------------------------------
# 检查容器状态
# ----------------------------------------------------------------
echo "🔍 检查容器状态..."
if docker ps -a --filter "name=^/${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
    echo "   容器存在，当前状态: $CONTAINER_STATUS"

    if [ "$CONTAINER_STATUS" = "running" ]; then
        echo "   容器已在运行中"
        NEED_START=false
    else
        echo "   容器已停止，将重新启动"
        NEED_START=true
    fi
else
    echo "   容器不存在，将创建新容器"
    NEED_START=true
fi
echo ""

# ----------------------------------------------------------------
# 修复权限（重要：确保容器内 webui 用户可以写入）
# ----------------------------------------------------------------
echo "🔧 [3.5/5] 检查并修复 webui 目录权限..."
if [ -d "./webui" ]; then
    chmod -R 777 ./webui
    echo "✅ 权限已修复"
else
    mkdir -p ./webui
    chmod -R 777 ./webui
    echo "✅ 已创建并设置 webui 目录"
fi
echo ""

# ----------------------------------------------------------------
# 启动容器
# ----------------------------------------------------------------
echo "🚀 [5/5] 启动容器..."
if [ "$NEED_START" = true ]; then
    if docker-compose up -d; then
        echo "✅ 容器启动成功"
    else
        echo "❌ 容器启动失败，请检查错误信息"
        exit 1
    fi
else
    echo "ℹ️  容器已在运行，无需启动"
fi
echo ""

# ----------------------------------------------------------------
# 显示状态信息
# ----------------------------------------------------------------
echo "========================================================"
echo "✅ 部署完成！"
echo "========================================================"
echo ""
echo "📊 容器信息："
docker-compose ps
echo ""

# 获取容器 IP 地址
if docker ps --filter "name=^/${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    CONTAINER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME" 2>/dev/null || echo "N/A")
    echo "🌐 访问地址："
    if [ "$CONTAINER_IP" != "N/A" ] && [ -n "$CONTAINER_IP" ]; then
        echo "   - http://${CONTAINER_IP}:7860"
    fi
    echo "   - http://localhost:7860"
    echo "   - http://YOUR_SERVER_IP:7860"
    echo ""
fi

echo "📝 查看日志："
echo "   docker-compose logs -f"
echo "   或"
echo "   docker logs -f $CONTAINER_NAME"
echo ""

echo "🛑 停止容器："
echo "   docker-compose down"
echo ""

echo "🔄 重启容器："
echo "   docker-compose restart"
echo ""

echo "========================================================"
echo "💡 提示："
echo "   - 首次启动需要 5-10 分钟下载依赖"
echo "   - 查看详细日志: docker-compose logs -f"
echo "   - 访问 WebUI: http://192.168.50.68:7860"
echo "========================================================"
