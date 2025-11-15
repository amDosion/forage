# Stable Diffusion WebUI Forge - Docker 完整部署方案

🚀 基于 Docker 的 Stable Diffusion WebUI Forge 生产级部署方案

## 🌟 项目特点

- ✅ **CUDA 12.8 + PyTorch 2.7.0** - 最新 CUDA 和深度学习框架
- ✅ **扩展依赖自动修复** - 自动修复常见扩展的依赖问题
- ✅ **灵活下载控制** - 通过环境变量控制所有资源下载
- ✅ **镜像加速支持** - 支持 HuggingFace 和 Git 镜像加速
- ✅ **Token 自动管理** - HuggingFace 和 Civitai API Token 自动配置
- ✅ **一键启动** - 自动构建镜像、创建容器、启动服务
- ✅ **配置版本管理** - 支持将配置推送到 GitHub 进行版本控制

## 📋 系统要求

- **操作系统**: Linux (Ubuntu 20.04+, Debian 11+) 或 Unraid
- **Docker**: 20.10+
- **Docker Compose**: 1.29+
- **NVIDIA GPU**: 支持 CUDA 12.8 的显卡 (需要驱动 >=525.60.13)
- **nvidia-container-toolkit**: 已安装并配置
- **磁盘空间**: 至少 50GB (推荐 100GB+)
- **内存**: 至少 16GB (推荐 32GB+)

## 🚀 快速开始

### 1. 克隆仓库

\`\`\`bash
git clone https://github.com/amDosion/forage.git
cd forage
\`\`\`

### 2. 配置环境变量

复制环境变量模板并填入你的配置：

\`\`\`bash
cp .env.example .env
nano .env  # 或使用你喜欢的编辑器
\`\`\`

**必须配置的项目**：
- \`HUGGINGFACE_TOKEN\` - HuggingFace API Token (从 https://huggingface.co/settings/tokens 获取)
- \`CIVITAI_API_TOKEN\` - Civitai API Token (从 https://civitai.com/user/account 获取)

**可选配置**：
- \`GITHUB_TOKEN\` - 用于自动推送配置到 GitHub (从 https://github.com/settings/tokens 获取)
- \`ENABLE_DOWNLOAD_*\` - 控制各类资源的下载开关

### 3. 启动容器

\`\`\`bash
chmod +x start.sh
./start.sh
\`\`\`

首次启动会自动：
1. 构建 Docker 镜像（约 10-15 分钟）
2. 创建容器
3. 下载 WebUI 代码和扩展
4. 安装 Python 依赖
5. 启动服务

### 4. 访问 WebUI

启动成功后，通过以下地址访问：

- **本地访问**: http://localhost:7860
- **局域网访问**: http://YOUR_SERVER_IP:7860

首次启动完成后大约 5-10 分钟可以访问 WebUI。

## 📂 项目结构

\`\`\`
forage/
├── run.sh                      # 容器启动脚本（自动处理依赖和资源）
├── start.sh                    # 宿主机启动脚本（构建+启动）
├── stop.sh                     # 宿主机停止脚本
├── Dockerfile                  # Docker 镜像构建文件
├── docker-compose.yml          # Docker Compose 配置
├── .env.example                # 环境变量配置模板
├── .env                        # 环境变量配置（需要自己创建，不提交到 Git）
├── .gitignore                  # Git 忽略配置
├── requirements_user_pins.txt  # Python 依赖版本锁定
├── resources.txt               # 扩展和模型资源列表
├── push_config_to_github.sh    # 配置文件推送脚本
├── GITHUB_PUSH_README.md       # GitHub 推送功能说明
└── webui/                      # WebUI 数据目录（挂载卷）
    ├── sd-webui-forge/         # Forge WebUI 主目录
    │   ├── models/             # 模型文件
    │   ├── extensions/         # 扩展插件
    │   ├── outputs/            # 生成图片
    │   └── venv/               # Python 虚拟环境
    └── launch.log              # 启动日志
\`\`\`

## 🔧 配置文件说明

### \`requirements_user_pins.txt\`

Python 依赖版本锁定文件，包含：
- 核心依赖版本（PyTorch, xformers 等）
- **扩展依赖修复**（见下文）

### \`resources.txt\`

扩展和模型资源列表，格式：

\`\`\`
# 扩展
extensions/扩展名,https://github.com/用户名/仓库名.git

# 模型
models/路径/文件名,https://huggingface.co/模型路径
\`\`\`

可通过 \`.env\` 中的下载开关控制每类资源的下载。

### \`.env\` 环境变量

详细说明见 \`.env.example\` 文件，主要配置项：

#### UI 选择
\`\`\`bash
UI=forge  # forge | auto | fastforge
\`\`\`

#### 启动参数
\`\`\`bash
ARGS="--xformers --api --listen --theme dark ..."
\`\`\`

#### API Tokens
\`\`\`bash
HUGGINGFACE_TOKEN=hf_xxx  # HuggingFace Token
CIVITAI_API_TOKEN=xxx     # Civitai Token
GITHUB_TOKEN=ghp_xxx      # GitHub Token（可选）
\`\`\`

#### 下载控制
\`\`\`bash
ENABLE_DOWNLOAD=true                    # 全局开关
ENABLE_DOWNLOAD_EXTS=true               # 扩展
ENABLE_DOWNLOAD_MODEL_SD15=false        # SD 1.5 模型
ENABLE_DOWNLOAD_MODEL_SDXL=false        # SDXL 模型
ENABLE_DOWNLOAD_MODEL_FLUX=false        # FLUX 模型
# ... 更多开关见 .env.example
\`\`\`

#### 镜像加速
\`\`\`bash
USE_HF_MIRROR=false   # HuggingFace 镜像 (hf-mirror.com)
USE_GIT_MIRROR=false  # Git 镜像 (gitcode.net)
\`\`\`

## 🐛 扩展依赖修复

本项目自动修复以下扩展的依赖问题：

### 1. sd-webui-inpaint-anything-forge
**问题**: 缺少 \`hydra-core\` 依赖
**修复**: 在 \`requirements_user_pins.txt\` 中添加 \`hydra-core==1.3.2\`

### 2. sd-civitai-browser-plus
**问题**: 缺少 \`send2trash\`, \`beautifulsoup4\`, \`ZipUnicode\` 依赖
**修复**: 在 \`requirements_user_pins.txt\` 中添加：
- \`send2trash==1.8.2\`
- \`beautifulsoup4==4.12.3\`
- \`ZipUnicode==1.1.1\`

### 原理

启动脚本 \`run.sh\` 会：
1. 下载 \`requirements_user_pins.txt\`（如果不存在）
2. 将依赖合并到 \`requirements_versions.txt\`
3. WebUI 启动时自动安装所有依赖

## 🛠️ 常用命令

### 查看日志
\`\`\`bash
# 实时查看日志
docker-compose logs -f

# 或者
docker logs -f forge-webui
\`\`\`

### 重启容器
\`\`\`bash
docker-compose restart
\`\`\`

### 停止容器
\`\`\`bash
./stop.sh
# 或者
docker-compose down
\`\`\`

### 进入容器
\`\`\`bash
docker exec -it forge-webui bash
\`\`\`

### 重建容器（保留数据）
\`\`\`bash
docker-compose down
docker-compose up -d
\`\`\`

### 完全重建（包括镜像）
\`\`\`bash
docker-compose down
docker rmi forge-webui:latest
./start.sh
\`\`\`

## 📦 配置版本管理

支持将配置文件推送到 GitHub 进行版本管理：

### 1. 配置 GitHub Token

在 \`.env\` 中设置：
\`\`\`bash
GITHUB_TOKEN=ghp_xxx          # 你的 GitHub Token
GITHUB_CONFIG_REPO=用户名/仓库名
GITHUB_CONFIG_BRANCH=main
\`\`\`

### 2. 推送配置

\`\`\`bash
docker exec forge-webui bash /app/push_config_to_github.sh
\`\`\`

详细说明见 [GITHUB_PUSH_README.md](GITHUB_PUSH_README.md)

## 🔍 故障排查

### 问题 1: 扩展加载失败 - ModuleNotFoundError

**症状**: 启动日志显示 \`ModuleNotFoundError: No module named 'xxx'\`

**解决方案**:
1. 检查 \`requirements_user_pins.txt\` 是否包含缺失的依赖
2. 进入容器手动安装：
   \`\`\`bash
   docker exec -it forge-webui bash
   source /app/webui/sd-webui-forge/venv/bin/activate
   pip install 缺失的包名
   \`\`\`
3. 将依赖添加到 \`requirements_user_pins.txt\` 并推送到 GitHub

### 问题 2: GPU 未被识别

**症状**: 启动日志显示 CUDA 不可用

**解决方案**:
1. 检查 nvidia-container-toolkit 是否安装：
   \`\`\`bash
   docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
   \`\`\`
2. 检查 Docker 配置是否支持 GPU:
   \`\`\`bash
   docker info | grep -i runtime
   \`\`\`

### 问题 3: 端口被占用

**症状**: 启动失败，提示端口 7860 被占用

**解决方案**:
1. 修改 \`docker-compose.yml\` 中的端口映射：
   \`\`\`yaml
   ports:
     - "7861:7860"  # 改为其他端口
   \`\`\`
2. 或者停止占用端口的程序

### 问题 4: 下载速度慢

**解决方案**:
1. 启用镜像加速：
   \`\`\`bash
   USE_HF_MIRROR=true   # HuggingFace 镜像
   USE_GIT_MIRROR=true  # Git 镜像
   \`\`\`
2. 使用代理（修改 Docker daemon 配置）

### 问题 5: 权限错误

**症状**: 容器启动失败，提示 Permission denied

**解决方案**:
\`\`\`bash
chmod -R 777 ./webui
./start.sh
\`\`\`

## 📝 更新日志

### v2.0 (2025-11-15)
- ✅ 添加扩展依赖自动修复
- ✅ 添加 GitHub 配置版本管理功能
- ✅ 完善环境变量配置
- ✅ 优化启动脚本逻辑
- ✅ 添加详细文档

### v1.0 (2025-10-30)
- ✅ 初始版本
- ✅ 基于 CUDA 12.8 + PyTorch 2.7.0
- ✅ 支持 Forge / Auto / FastForge 三种 UI
- ✅ 灵活的下载控制

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目基于 MIT 许可证开源。

## 🔗 相关链接

- [Stable Diffusion WebUI Forge](https://github.com/lllyasviel/stable-diffusion-webui-forge)
- [AUTOMATIC1111 WebUI](https://github.com/AUTOMATIC1111/stable-diffusion-webui)
- [HuggingFace](https://huggingface.co/)
- [Civitai](https://civitai.com/)

---

**💡 提示**: 如有问题，请先查看日志 (\`docker-compose logs -f\`) 和本文档的故障排查部分。
