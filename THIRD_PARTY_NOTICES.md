# 第三方组件声明

本仓库为学习用途的构建系统移植模板，包含以下第三方代码。各组件版权归原作者所有，
本模板没有修改其授权条款；原始版权声明均保留在对应文件头部。

| 组件 | 版本 | 目录 | 版权方 | 许可 |
|---|---|---|---|---|
| Azure RTOS / ThreadX | 6.0.2 | `ThreadX/` | Microsoft Corporation | MIT（全文见 `ThreadX/LICENSE.txt`） |
| STM32H7xx HAL Driver | 1.9.0 | `Libraries/STM32H7xx_HAL_Driver/` | STMicroelectronics | BSD-3-Clause（见各文件头 `@attention`） |
| CMSIS (Core + Device/ST) | 5.4.0 | `Libraries/CMSIS/` | Arm Limited / STMicroelectronics | Apache-2.0 / BSD-3-Clause |
| 安富莱 V7 BSP + 例程 | BSP V1.2 | `User/`、`Doc/` | 安富莱电子 www.armfly.com | 原例程声明「Copyright (C), 2020-2030, 安富莱电子」，仅供配合教程学习使用 |
| syscalls.c / sysmem.c | CubeMX 生成 | `User/syscalls/` | STMicroelectronics | BSD-3-Clause / AS-IS |

## 本模板对第三方代码做过的改动

1. **编码转换**：`User/`、`Doc/` 下 128 个 GBK 源码/文档转为 UTF-8，仅影响注释显示，未改动代码逻辑。
2. **新增适配层**：`User/bsp/src/bsp_retarget.c`（newlib printf 重定向）、`User/syscalls/`（newlib 桩函数）。
3. **链接脚本**：`STM32H743XX_FLASH.ld` 基于 STM32CubeMX 生成的 H743 脚本改写，新增 ThreadX 所需的 `_vectors` / `__RAM_segment_used_end__` 符号、多段 RAM 布局与 ASSERT。
4. **未改动**：`ThreadX/common/`、`ThreadX/ports/cortex_m7/gnu/`、HAL、CMSIS、CMSIS GCC 启动文件均保持上游原样（只做了目录裁剪）。

## 说明

- 原例程《安富莱 ThreadX 内核教程（V7/V6 板）》及配套 BSP 的著作权归安富莱电子所有，
  本仓库不主张任何权利，也不提供商业授权。
- 若用于产品化，请自行替换为 ST 官方最新 HAL/CMSIS、Eclipse ThreadX 官方发行版，
  并复核各组件的许可义务。
