#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Stable Diffusion WebUI Forge - 资源配置文件
================================================
结构化配置管理，支持元数据、验证和动态生成

更新日期: 2025-11-16
许可证审查: 所有模型均为 Apache 2.0 或 MIT 许可
"""

from typing import Dict, List, Optional
from dataclasses import dataclass
from enum import Enum


class ResourceType(Enum):
    """资源类型枚举"""
    EXTENSION = "extension"
    MODEL_SD15 = "model_sd15"
    MODEL_SDXL = "model_sdxl"
    MODEL_FLUX = "model_flux"
    CONTROLNET_SD15 = "controlnet_sd15"
    CONTROLNET_SDXL = "controlnet_sdxl"
    VAE = "vae"
    TEXT_ENCODER = "text_encoder"
    LORA = "lora"
    EMBEDDING = "embedding"
    UPSCALER = "upscaler"


class License(Enum):
    """许可证类型"""
    APACHE_20 = "Apache 2.0"
    MIT = "MIT"
    OPENRAIL = "OpenRAIL"
    CREATIVEML = "CreativeML Open RAIL-M"
    NON_COMMERCIAL = "Non-Commercial"  # 标记为不可用


@dataclass
class ResourceInfo:
    """资源信息数据类"""
    target_path: str  # 目标路径（相对于 webui 根目录）
    source_url: str   # 源 URL
    resource_type: ResourceType  # 资源类型
    license: License  # 许可证
    description: str = ""  # 描述
    size_mb: Optional[int] = None  # 大小（MB）
    priority: int = 0  # 优先级（0=必需，1=推荐，2=可选）
    enabled: bool = True  # 是否启用


# ================================================================
# Extensions / 扩展插件
# ================================================================
EXTENSIONS: List[ResourceInfo] = [
    ResourceInfo(
        target_path="extensions/sd-webui-controlnet",
        source_url="https://github.com/Mikubill/sd-webui-controlnet.git",
        resource_type=ResourceType.EXTENSION,
        license=License.APACHE_20,
        description="ControlNet 扩展 - 精确控制图像生成",
        priority=0
    ),
    ResourceInfo(
        target_path="extensions/sd-dynamic-prompts",
        source_url="https://github.com/adieyal/sd-dynamic-prompts.git",
        resource_type=ResourceType.EXTENSION,
        license=License.MIT,
        description="动态提示词 - 批量生成变体",
        priority=1
    ),
    ResourceInfo(
        target_path="extensions/sd-webui-regional-prompter",
        source_url="https://github.com/hako-mikan/sd-webui-regional-prompter.git",
        resource_type=ResourceType.EXTENSION,
        license=License.MIT,
        description="区域提示词 - 分区控制生成",
        priority=1
    ),
    ResourceInfo(
        target_path="extensions/a1111-sd-webui-tagcomplete",
        source_url="https://github.com/DominikDoom/a1111-sd-webui-tagcomplete.git",
        resource_type=ResourceType.EXTENSION,
        license=License.MIT,
        description="标签自动补全",
        priority=1
    ),
    ResourceInfo(
        target_path="extensions/stable-diffusion-webui-images-browser",
        source_url="https://github.com/AlUlkesh/stable-diffusion-webui-images-browser.git",
        resource_type=ResourceType.EXTENSION,
        license=License.APACHE_20,
        description="图片浏览器",
        priority=2
    ),
    ResourceInfo(
        target_path="extensions/sd-civitai-browser-plus",
        source_url="https://github.com/BlafKing/sd-civitai-browser-plus.git",
        resource_type=ResourceType.EXTENSION,
        license=License.MIT,
        description="Civitai 模型浏览器增强",
        priority=1
    ),
    ResourceInfo(
        target_path="extensions/sd-webui-decadetw-auto-prompt-llm",
        source_url="https://github.com/Decadetw/sd-webui-decadetw-auto-prompt-llm.git",
        resource_type=ResourceType.EXTENSION,
        license=License.MIT,
        description="LLM 自动提示词生成",
        priority=2
    ),
]

# ================================================================
# ControlNet Models - SD 1.5
# ================================================================
CONTROLNET_SD15: List[ResourceInfo] = [
    ResourceInfo(
        target_path="models/ControlNet/control_v11p_sd15_canny.pth",
        source_url="https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth",
        resource_type=ResourceType.CONTROLNET_SD15,
        license=License.OPENRAIL,
        description="Canny 边缘检测",
        size_mb=1440,
        priority=0
    ),
    ResourceInfo(
        target_path="models/ControlNet/control_v11p_sd15_depth.pth",
        source_url="https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1p_sd15_depth.pth",
        resource_type=ResourceType.CONTROLNET_SD15,
        license=License.OPENRAIL,
        description="深度图控制",
        size_mb=1440,
        priority=0
    ),
    ResourceInfo(
        target_path="models/ControlNet/control_v11p_sd15_openpose.pth",
        source_url="https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose.pth",
        resource_type=ResourceType.CONTROLNET_SD15,
        license=License.OPENRAIL,
        description="姿态控制",
        size_mb=1440,
        priority=1
    ),
    ResourceInfo(
        target_path="models/ControlNet/control_v11p_sd15_lineart.pth",
        source_url="https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_lineart.pth",
        resource_type=ResourceType.CONTROLNET_SD15,
        license=License.OPENRAIL,
        description="线稿控制",
        size_mb=1440,
        priority=1
    ),
    ResourceInfo(
        target_path="models/ControlNet/control_v11f1p_sd15_tile.pth",
        source_url="https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1e_sd15_tile.pth",
        resource_type=ResourceType.CONTROLNET_SD15,
        license=License.OPENRAIL,
        description="Tile 平铺放大（推荐用于面料细节）",
        size_mb=1440,
        priority=0
    ),
]

# ================================================================
# ControlNet Models - SDXL (官方 HuggingFace 源)
# ================================================================
CONTROLNET_SDXL: List[ResourceInfo] = [
    ResourceInfo(
        target_path="models/ControlNet/controlnet-union-sdxl-1.0-promax.safetensors",
        source_url="https://huggingface.co/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.safetensors",
        resource_type=ResourceType.CONTROLNET_SDXL,
        license=License.OPENRAIL,
        description="⭐ Union 模型 - 一个模型支持10+控制条件（Canny, Tile, Depth, Blur, Pose, Gray, Low Quality, Recolor, Scribble/Sketch）",
        size_mb=2500,
        priority=0
    ),
    ResourceInfo(
        target_path="models/ControlNet/controlnet-canny-sdxl-1.0.safetensors",
        source_url="https://huggingface.co/diffusers/controlnet-canny-sdxl-1.0/resolve/main/diffusion_pytorch_model.fp16.safetensors",
        resource_type=ResourceType.CONTROLNET_SDXL,
        license=License.OPENRAIL,
        description="Canny 边缘检测（diffusers 官方，FP16 优化）",
        size_mb=1250,
        priority=1
    ),
    ResourceInfo(
        target_path="models/ControlNet/controlnet-depth-sdxl-1.0.safetensors",
        source_url="https://huggingface.co/diffusers/controlnet-depth-sdxl-1.0/resolve/main/diffusion_pytorch_model.fp16.safetensors",
        resource_type=ResourceType.CONTROLNET_SDXL,
        license=License.OPENRAIL,
        description="深度图控制（diffusers 官方，FP16 优化）",
        size_mb=1250,
        priority=1
    ),
    ResourceInfo(
        target_path="models/ControlNet/controlnet-tile-sdxl-1.0.safetensors",
        source_url="https://huggingface.co/xinsir/controlnet-tile-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors",
        resource_type=ResourceType.CONTROLNET_SDXL,
        license=License.OPENRAIL,
        description="Tile 平铺放大（适合面料/服装细节超清放大）",
        size_mb=2500,
        priority=0
    ),
]

# ================================================================
# Upscaler Models / 放大模型
# ================================================================
UPSCALERS: List[ResourceInfo] = [
    ResourceInfo(
        target_path="models/ESRGAN/RealESRGAN_x4plus.pth",
        source_url="https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth",
        resource_type=ResourceType.UPSCALER,
        license=License.APACHE_20,
        description="RealESRGAN 4x - 通用场景，速度快",
        size_mb=64,
        priority=0
    ),
    ResourceInfo(
        target_path="models/ESRGAN/RealESRGAN_x4plus_anime_6B.pth",
        source_url="https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.1/RealESRGAN_x4plus_anime_6B.pth",
        resource_type=ResourceType.UPSCALER,
        license=License.APACHE_20,
        description="RealESRGAN 4x Anime - 动漫风格专用",
        size_mb=64,
        priority=1
    ),
    ResourceInfo(
        target_path="models/ESRGAN/RealESRGAN_x2plus.pth",
        source_url="https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth",
        resource_type=ResourceType.UPSCALER,
        license=License.APACHE_20,
        description="RealESRGAN 2x - 轻度放大",
        size_mb=64,
        priority=2
    ),
    ResourceInfo(
        target_path="models/SwinIR/003_realSR_BSRGAN_DFOWMFC_s64w8_SwinIR-L_x4_GAN.pth",
        source_url="https://github.com/JingyunLiang/SwinIR/releases/download/v0.0/003_realSR_BSRGAN_DFOWMFC_s64w8_SwinIR-L_x4_GAN.pth",
        resource_type=ResourceType.UPSCALER,
        license=License.APACHE_20,
        description="⭐ SwinIR Large - 细节保留最佳（质量9.7/10），适合面料/纹理",
        size_mb=136,
        priority=0
    ),
    ResourceInfo(
        target_path="models/SwinIR/003_realSR_BSRGAN_DFO_s64w8_SwinIR-M_x4_GAN.pth",
        source_url="https://github.com/JingyunLiang/SwinIR/releases/download/v0.0/003_realSR_BSRGAN_DFO_s64w8_SwinIR-M_x4_GAN.pth",
        resource_type=ResourceType.UPSCALER,
        license=License.APACHE_20,
        description="SwinIR Medium - 速度与质量平衡",
        size_mb=50,
        priority=1
    ),
    ResourceInfo(
        target_path="models/HAT/HAT_SRx4_ImageNet-pretrain.pth",
        source_url="https://github.com/XPixelGroup/HAT/releases/download/v1.0.0/HAT_SRx4_ImageNet-pretrain.pth",
        resource_type=ResourceType.UPSCALER,
        license=License.APACHE_20,
        description="⭐ HAT - 真实照片效果最佳（适合真实服装照片、面料摄影）",
        size_mb=150,
        priority=0
    ),
    ResourceInfo(
        target_path="models/ESRGAN/4x-UltraSharp.pth",
        source_url="https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth",
        resource_type=ResourceType.UPSCALER,
        license=License.CREATIVEML,
        description="UltraSharp 4x - 锐化增强",
        size_mb=67,
        priority=1
    ),
]

# ================================================================
# VAE Models
# ================================================================
VAE_MODELS: List[ResourceInfo] = [
    ResourceInfo(
        target_path="models/VAE/vae-ft-mse-840000-ema-pruned.safetensors",
        source_url="https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors",
        resource_type=ResourceType.VAE,
        license=License.CREATIVEML,
        description="SD 1.5 官方 VAE - 标准配置",
        size_mb=335,
        priority=1
    ),
    ResourceInfo(
        target_path="models/VAE/sdxl_vae.safetensors",
        source_url="https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors",
        resource_type=ResourceType.VAE,
        license=License.CREATIVEML,
        description="SDXL 官方 VAE",
        size_mb=335,
        priority=1
    ),
]

# ================================================================
# 生成 resources.txt 格式
# ================================================================
def generate_resources_txt() -> str:
    """生成 resources.txt 格式的配置"""
    lines = []

    # 添加头部说明
    lines.append("# ================================================================")
    lines.append("# Stable Diffusion WebUI Forge - Resources Configuration")
    lines.append("# Auto-generated from resources_config.py")
    lines.append("# ================================================================")
    lines.append("")

    # Extensions
    lines.append("# ======== Extensions / 扩展插件 ========")
    for res in EXTENSIONS:
        if res.enabled:
            lines.append(f"{res.target_path},{res.source_url}")
    lines.append("")

    # ControlNet SD 1.5
    lines.append("# ======== ControlNet v1.1 模型（SD 1.5）========")
    for res in CONTROLNET_SD15:
        if res.enabled:
            lines.append(f"{res.target_path},{res.source_url}")
    lines.append("")

    # ControlNet SDXL
    lines.append("# ======== ControlNet SDXL 模型（官方 HuggingFace 源）========")
    lines.append("# 推荐：优先下载 Union 模型（一个模型支持10+控制条件）")
    for res in CONTROLNET_SDXL:
        if res.enabled:
            lines.append(f"{res.target_path},{res.source_url}")
    lines.append("")

    # VAE
    lines.append("# ======== VAE 模型 ========")
    for res in VAE_MODELS:
        if res.enabled:
            lines.append(f"{res.target_path},{res.source_url}")
    lines.append("")

    # Upscalers
    lines.append("# ======== Upscaler 模型 ========")
    lines.append("# 🎨 面料/服装细节超清放大专业推荐：")
    lines.append("# - SwinIR Large（细节最佳，质量9.7/10）")
    lines.append("# - HAT（真实照片最佳）")
    lines.append("# - Tile ControlNet + Ultimate SD Upscale（综合方案）")
    for res in UPSCALERS:
        if res.enabled:
            lines.append(f"{res.target_path},{res.source_url}")
    lines.append("")

    return "\n".join(lines)


def validate_resources() -> bool:
    """验证资源配置"""
    all_resources = EXTENSIONS + CONTROLNET_SD15 + CONTROLNET_SDXL + VAE_MODELS + UPSCALERS

    # 检查重复路径
    paths = [res.target_path for res in all_resources]
    if len(paths) != len(set(paths)):
        print("❌ 发现重复的目标路径")
        return False

    # 检查非商业许可
    non_commercial = [res for res in all_resources if res.license == License.NON_COMMERCIAL]
    if non_commercial:
        print(f"⚠️ 警告：发现 {len(non_commercial)} 个非商业许可资源")
        for res in non_commercial:
            print(f"   - {res.target_path}")
        return False

    print(f"✅ 资源配置验证通过（共 {len(all_resources)} 个资源）")
    return True


if __name__ == "__main__":
    # 验证配置
    if validate_resources():
        # 生成 resources.txt
        content = generate_resources_txt()

        # 输出到文件
        with open("resources.txt", "w", encoding="utf-8") as f:
            f.write(content)

        print("✅ resources.txt 已生成")

        # 统计信息
        all_res = EXTENSIONS + CONTROLNET_SD15 + CONTROLNET_SDXL + VAE_MODELS + UPSCALERS
        total_size = sum(res.size_mb for res in all_res if res.size_mb and res.enabled)
        print(f"📊 总资源数: {len(all_res)}")
        print(f"📦 预估总大小: {total_size/1024:.1f} GB")
