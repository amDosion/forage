# 资源配置系统

## 📋 概述

本项目使用 Python 配置文件 (`resources_config.py`) 来管理所有模型和扩展资源，提供结构化、可维护的配置管理。

## 🆚 新旧对比

### 旧方式 (resources.txt)
```
# 简单的文本文件
models/ControlNet/control_v11p_sd15_canny.pth,https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth
```

**缺点：**
- ❌ 无元数据（许可证、大小、描述）
- ❌ 难以验证和管理
- ❌ 无法动态生成配置
- ❌ 容易出错

### 新方式 (resources_config.py)
```python
ResourceInfo(
    target_path="models/ControlNet/control_v11p_sd15_canny.pth",
    source_url="https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth",
    resource_type=ResourceType.CONTROLNET_SD15,
    license=License.OPENRAIL,
    description="Canny 边缘检测",
    size_mb=1440,
    priority=0
)
```

**优势：**
- ✅ **完整元数据** - 许可证、大小、描述、优先级
- ✅ **类型安全** - 枚举类型防止错误
- ✅ **自动验证** - 检测重复、许可证冲突
- ✅ **动态生成** - 自动生成兼容的 resources.txt
- ✅ **易于扩展** - 添加新字段只需修改 dataclass

## 🎯 主要功能

### 1. 资源分类管理
```python
EXTENSIONS          # 扩展插件
CONTROLNET_SD15    # SD 1.5 ControlNet
CONTROLNET_SDXL    # SDXL ControlNet
VAE_MODELS         # VAE 模型
UPSCALERS          # 放大模型
```

### 2. 许可证自动检查
```python
# 自动排除非商业许可
if res.license == License.NON_COMMERCIAL:
    print(f"⚠️ 警告：非商业许可资源 - {res.target_path}")
    return False
```

### 3. 统计信息
```
✅ 资源配置验证通过（共 25 个资源）
📊 总资源数: 25
📦 预估总大小: 15.6 GB
```

### 4. 优先级管理
```python
priority=0  # 必需（Canny, Tile, SwinIR, HAT）
priority=1  # 推荐（Depth, OpenPose, Anime Upscaler）
priority=2  # 可选（Scribble, 2x Upscaler）
```

## 🚀 使用方法

### 方式一：直接使用 resources.txt（推荐）
```bash
# resources.txt 由 resources_config.py 自动生成
# run.sh 会自动读取 resources.txt
docker-compose up -d
```

### 方式二：重新生成配置
```bash
# 修改 resources_config.py 后，重新生成 resources.txt
python3 resources_config.py

# 输出：
# ✅ 资源配置验证通过（共 25 个资源）
# ✅ resources.txt 已生成
# 📊 总资源数: 25
# 📦 预估总大小: 15.6 GB
```

## 📝 添加新资源

### 示例：添加新的 SDXL ControlNet 模型

```python
# 在 resources_config.py 中的 CONTROLNET_SDXL 列表添加：
ResourceInfo(
    target_path="models/ControlNet/controlnet-new-model.safetensors",
    source_url="https://huggingface.co/author/model/resolve/main/model.safetensors",
    resource_type=ResourceType.CONTROLNET_SDXL,
    license=License.OPENRAIL,
    description="新模型的描述",
    size_mb=2500,
    priority=1  # 推荐
)
```

然后运行：
```bash
python3 resources_config.py
```

自动生成的 resources.txt 将包含新模型。

## ⚠️ 许可证策略

当前配置**仅包含**以下许可证的模型：
- ✅ **Apache 2.0** - 完全开源，商业友好
- ✅ **MIT** - 完全开源，商业友好
- ✅ **OpenRAIL / CreativeML OpenRAIL-M** - 开源，商业友好

**已排除**的许可证：
- ❌ **Non-Commercial** - FLUX.1 Dev ControlNet 等

## 📊 当前资源清单

### Extensions（7个）
- ControlNet 扩展
- Dynamic Prompts
- Regional Prompter
- Tag Autocomplete
- Images Browser
- Civitai Browser+
- Auto Prompt LLM

### ControlNet SD 1.5（5个）
- Canny, Depth, OpenPose, Lineart, Tile

### ControlNet SDXL（4个）
- ⭐ **Union ProMax**（一个模型支持10+控制条件）
- Canny, Depth, Tile

### Upscalers（7个）
- RealESRGAN 系列（x4plus, x4plus_anime, x2plus, UltraSharp）
- ⭐ **SwinIR**（Large, Medium - 细节最佳）
- ⭐ **HAT**（真实照片最佳）

### VAE（2个）
- SD 1.5 VAE, SDXL VAE

## 🎨 专业应用建议

### 面料/服装细节超清放大

**方案 1：Tile ControlNet + Ultimate SD Upscale（最推荐）**
- 模型：SDXL + Tile ControlNet
- Denoise：0.3-0.4
- ControlNet Strength：0.9

**方案 2：SwinIR Large（细节之王）**
- 质量评分：9.7/10（最高）
- 适合：织物纹理、刺绣、服装细节

**方案 3：HAT（真实照片最佳）**
- 适合：真实服装照片、面料摄影

## 🔄 版本历史

### 2025-11-16
- ✅ 初始版本
- ✅ 所有资源许可证审查完成
- ✅ 移除 FLUX ControlNet（非商业许可）
- ✅ 更新 SDXL ControlNet 为官方源
- ✅ 添加 Union ProMax 模型
- ✅ 优化 Upscaler 配置（面料专用）

## 📚 相关文档

- `resources_config.py` - Python 配置源文件
- `resources.txt` - 自动生成的配置文件（run.sh 使用）
- `.env.example` - 环境变量配置模板
- `docker-compose.yml` - Docker 编排配置
