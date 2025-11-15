# GitHub 配置文件自动推送使用说明

## 📋 功能说明

此功能允许你将容器中修改的配置文件（如 `requirements_user_pins.txt`）自动推送到你的 GitHub 配置仓库，方便版本管理和分享。

## 🔑 前置准备

### 1. 创建 GitHub Personal Access Token

1. 访问 GitHub Token 设置页面: https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. 填写以下信息：
   - **Note**: `WebUI Config Push` (或任意描述)
   - **Expiration**: 选择有效期（推荐 90 天或更长）
   - **Scopes**: 勾选 `repo` (完整仓库访问权限)
4. 点击 "Generate token"
5. **重要**: 立即复制生成的 token（离开页面后将无法再次查看）

### 2. 配置 .env 文件

编辑 `/mnt/user/appdata/webui/.env` 文件，填入你的 GitHub Token：

```bash
# GitHub Personal Access Token (用于推送配置更新 / for pushing config updates)
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# GitHub 配置仓库 / GitHub config repository
GITHUB_CONFIG_REPO=amDosion/forage
GITHUB_CONFIG_BRANCH=main
```

**配置说明**:
- `GITHUB_TOKEN`: 你的 GitHub Personal Access Token
- `GITHUB_CONFIG_REPO`: 配置仓库地址（格式: owner/repo）
- `GITHUB_CONFIG_BRANCH`: 目标分支（默认: main）

## 🚀 使用方法

### 方法一：手动执行推送脚本

在宿主机（Unraid）上执行：

```bash
docker exec forge-webui bash /app/push_config_to_github.sh
```

或者在容器内执行：

```bash
docker exec -it forge-webui bash
cd /app
./push_config_to_github.sh
```

### 方法二：从宿主机直接运行

```bash
/mnt/user/appdata/webui/push_config_to_github.sh
```

## 📦 推送的文件

当前脚本会推送以下配置文件到 GitHub：

- `requirements_user_pins.txt` - Python 依赖版本锁定文件

## ✅ 成功推送后

脚本会显示提交信息和 GitHub 链接，你可以：

1. 访问 GitHub 仓库查看提交历史
2. 其他用户拉取你的配置仓库时会获得更新
3. 在容器重建时，启动脚本会自动下载最新配置

## 🔒 安全提示

1. **不要将 .env 文件提交到公开仓库**（已在 .gitignore 中）
2. **定期更新 GitHub Token**，设置合理的有效期
3. **Token 权限最小化**，只给予必要的 `repo` 权限
4. 如果 Token 泄露，立即在 GitHub 设置中撤销

## 🐛 故障排查

### 推送失败: "401 Unauthorized"
- 检查 GITHUB_TOKEN 是否正确
- 确认 Token 是否已过期
- 验证 Token 是否有 `repo` 权限

### 推送失败: "404 Not Found"
- 检查 GITHUB_CONFIG_REPO 格式是否正确（owner/repo）
- 确认仓库是否存在
- 验证 Token 是否有仓库访问权限

### 推送失败: "403 Forbidden"
- Token 权限不足，需要 `repo` 完整权限
- 仓库可能设置了分支保护规则

## 📝 自动化建议

如果想在配置文件修改后自动推送，可以：

1. 添加到启动脚本末尾
2. 设置定时任务（cron）
3. 使用 Git hooks 监控文件变化

## 🔗 相关链接

- GitHub Token 管理: https://github.com/settings/tokens
- 配置仓库: https://github.com/amDosion/forage
- WebUI Forge: https://github.com/lllyasviel/stable-diffusion-webui-forge
