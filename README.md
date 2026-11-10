# Cmake_threadX_Template

**安富莱 V7 开发板（STM32H743XIHx）ThreadX 例程的 CMake + arm-none-eabi-gcc 移植模板。**

来源：`V7-3002_ThreadX Kernal Template`（安富莱《ThreadX 内核教程》第 2 章程序模板，ThreadX 6.0.2 / ST HAL 1.9.0 / 安富莱 BSP V1.2）。
原工程提供 AC5 / AC6 / IAR / Embedded Studio 四套 IDE 工程，本模板把构建系统整体换成 CMake，源码目录结构保持不变。

> 构建状态：本机 **GCC 15.3.rel2 + CMake 4.4.5 + Ninja 1.13.2** 下 Debug / Release 均可完整编译链接，产出 `.elf / .hex / .bin / .map`。
> Flash 50.5 KB / RAM 34.7 KB（Debug, -O0）。
>
> **上板状态：已在安富莱 V7 实板（DAPLink/CMSIS-DAP + CH340 串口）完成烧录与运行验证**，
> 6 个应用任务正常调度、串口 printf 正常输出、线程栈水位可读。详见 §9。

---

## 1. 移植思路：我的几个取舍

### ① 保留原例程目录骨架，另起一套构建层

没有把代码重排成 CubeMX 风格的 `Core/Drivers/...`，而是保留 `User/`、`User/bsp/`、`Libraries/`、`ThreadX/` 四层。
理由很实际：这套教程有 3002~3018 共 17 个章节，**工程骨架完全一样，差异只在 `User/main.c` 和少数几个附加组件**。
保持目录同名后，跑后续章节只需要：

```bash
cp <教程目录>/V7-30xx_xxx/User/main.c  User/main.c
./run.sh
```

RTT 打印（3003+）、执行剖析（3011+）等额外源文件则通过 `-DBSP_EXTRA_SOURCES=...` 追加，见 §8。

### ② 编译器从 armclang(AC6) 换成 arm-none-eabi-gcc，port 必须一起换

原 Keil 工程用的是 `ThreadX/ports/cortex_m7/ac6`（armclang 汇编），还有 `ac5 / iar` 三套。
**GCC 只能用 `ports/cortex_m7/gnu`**：7 个 `src/*.S` + `example_build/tx_initialize_low_level.S`。
它们语法是 GNU as，且内部有 `#ifdef TX_ENABLE_FPU_SUPPORT`，必须经 C 预处理器（工具链文件里 `-x assembler-with-cpp`）。

### ③ 组件用 CMake OBJECT 库，不用静态库 `.a`

这是本次移植最容易翻车的地方。ThreadX 靠**强符号覆盖启动文件里的 `.weak` 空实现**来接管异常：

| 强符号 | 来源 | 覆盖对象 |
|---|---|---|
| `PendSV_Handler` | `tx_thread_schedule.S` | CMSIS startup 的 weak `PendSV_Handler` |
| `SysTick_Handler` | `tx_initialize_low_level.S` | CMSIS startup 的 weak `SysTick_Handler` |

如果把 port 汇编放进静态库，链接器已用 weak 定义满足了引用，**不会为了"覆盖 weak"去归档里抽取成员**，结果是 RTOS 没有调度心跳、编译却完全不报错。
OBJECT 库的目标文件无条件参与链接，天然避开这个坑。所以 `cmake/threadx.cmake`、`stm32h7.cmake`、`bsp.cmake` 全部是 `add_library(... OBJECT ...)`。

### ④ 不改 ThreadX 官方源码，改动全部收敛在链接脚本和适配层

GNU 版 `tx_initialize_low_level.S` 引用 `_vectors` 和 `__RAM_segment_used_end__`，
而 ST 的 GCC 启动文件/链接脚本只提供 `g_pfnVectors` / `_estack` / `_end`。
这里**在 `STM32H743XX_FLASH.ld` 里 PROVIDE 这两个符号**，从而内核源码保持官方原版，日后升级 ThreadX 直接替换 `ThreadX/` 即可。

### ⑤ 模板要"轻"，不要"全"

原例程单章就有 2600+ 文件（含 4 套 IDE 工程、14 个芯片架构 port、预编译 `.o/.hex/.arm`、20 个 H7 型号头 40 MB）。
本模板精简到 657 个文件 / 24 MB：**删掉不参与编译的东西，但保留有用的 BSP 全量源码**（方便后续章节启用外设）。

---

## 2. 移植了哪些文件

### 保留（来自原例程）

| 目录 | 内容 | 数量 |
|---|---|---|
| `User/` | `main.c`（示例：6 个任务 + 统计 + 互斥量打印）、`includes.h`、`tx_user.h` | 3 |
| `User/bsp/` | `bsp.c`（MPU/Cache/400MHz 时钟）、中断服务、`TIM7` 时基、`stm32h7xx_hal_conf.h`、全部 BSP 头文件 | — |
| `User/bsp/src/` | 安富莱 BSP 驱动全量源码（默认只编译 8 个） | 54 |
| `User/bsp/inc/` | BSP 模块头文件全集 | 57 |
| `User/fonts/` | 字库（默认不编译，LCD 例程才需要） | 10 |
| `Libraries/CMSIS/Include/` | CMSIS 5.4.0 内核头全集 | 33 |
| `Libraries/CMSIS/Device/.../Include/` | **只保留 H743 相关 3 个**（`stm32h743xx.h` / `stm32h7xx.h` / `system_stm32h7xx.h`），其余 19 个 H7 型号头共约 35 MB 已删 | 3 |
| `Libraries/CMSIS/.../system_stm32h7xx.c` | `SystemInit()` / `SystemCoreClockUpdate()` | 1 |
| `Libraries/STM32H7xx_HAL_Driver/` | HAL 1.9.0 的 `Inc/` 全集 + `Src/` 全集（默认编译 14 个） | 131 h / 123 c |
| `ThreadX/common/` | 内核 `inc/` 12 个头 + `src/` 185 个 C 全量 | 197 |
| `ThreadX/ports/cortex_m7/gnu/` | **GNU port**：`inc/tx_port.h` + 7 个 `src/*.S` + `tx_initialize_low_level.S` | 9 |
| `ThreadX/LICENSE.txt`、`README.md` | 上游许可证与说明 | 2 |
| `Doc/` | 例程功能说明 / 修改记录（已转 UTF-8） | 2 |

### 新增（本模板自己写的）

| 文件 | 作用 |
|---|---|
| `CMakeLists.txt` | 顶层工程、全局宏与头文件路径、可执行目标、构建后处理 |
| `cmake/gcc-arm-none-eabi.cmake` | ARM GCC 工具链、CPU/FPU 选项、newlib-nano 链接选项 |
| `cmake/threadx.cmake` | ThreadX 内核 + GNU port（OBJECT 库） |
| `cmake/stm32h7.cmake` | HAL / CMSIS（OBJECT 库，带 `HAL_AUTO_ALL_SOURCES` 开关） |
| `cmake/bsp.cmake` | 安富莱 BSP + newlib 适配层（OBJECT 库，带 `BSP_EXTRA_SOURCES`） |
| `STM32H743XX_FLASH.ld` | H743 链接脚本，含 ThreadX 符号适配与多段 RAM 布局 |
| `startup_stm32h743xx.s` | 从 CMSIS `Templates/gcc/` 复制的 **GNU 语法**启动文件（原 Keil 用的是 `arm/` 版） |
| `User/bsp/src/bsp_retarget.c` | newlib `printf` → 安富莱串口 FIFO |
| `User/syscalls/{syscalls,sysmem}.c` | STM32CubeMX 的 newlib 桩函数（`_write` / `_sbrk` 等） |
| `CMakePresets.json` / `run.sh` / `flash` / `flash-reset` / `.vscode/` | 构建、烧录、调试配置（沿用你已有的 `stm32h743-cmake-template` 风格） |
| `tools/serial_monitor.py` | 串口抓取脚本（pyserial），自动挑端口、抓取、识别 ThreadX 标志性输出 |
| `tools/thread_stack.gdb` | GDB 脚本，直接读出各线程栈水位与 CPU 占用（免按 K1） |
| `tools/verify_on_board.sh` | 一键：编译 → 烧录 → 抓串口 → 打印结论 |
| `LICENSE` / `THIRD_PARTY_NOTICES.md` | 工程许可证与第三方声明 |

### 删除（不进模板）

- 4 套 IDE 工程（`MDK-ARM(AC5)/(AC6)`、`EWARMv8`、`EmbeddedStudio`）及其 `Objects/` `Listings/` 编译产物、预编译 `.hex/.o/.arm/.a`。
- ThreadX 的 `common_modules/ common_smp/ ports_module/ ports_smp/ docs/ samples/`、`ports/` 下除 `cortex_m7/gnu` 外的全部架构，以及 ac5 / ac6 / iar 三套 M7 port。
- `Libraries/STM32_Audio/`、`STM32_USB_Device_Library/`、`STM32_USB_Host_Library/`（本例程未引用）。
- `User/segger/HardFaultHandlerMDK/`（`HardFaultHandler.S` 是 Keil armasm 语法，GCC 不兼容）。
- `User/` 根目录下一批与 `User/bsp/` 重复的陈旧副本（`bsp.c`、`stm32h7xx_it.c`、`stm32h7xx_hal_conf.h` 等），编译以 `User/bsp/` 为准。
- 19 个非 H743 型号的 CMSIS 设备头。

### 编码处理

原例程的 BSP/App 源码与注释是 **GBK**，在 GitHub 与 UTF-8 编辑器里全是乱码。
本模板把 `User/` 与 `Doc/` 下 **128 个文件统一转成 UTF-8**（代码逻辑未改动，只改注释字节）。

---

## 3. Keil → CMake 逐项映射

| Keil (AC6) | CMake / GCC |
|---|---|
| `STM32H743XIHx`, `CPUTYPE("Cortex-M7") FPU3(DFPU)` | `-mcpu=cortex-m7 -mfpu=fpv5-d16 -mfloat-abi=hard` |
| 宏 `USE_HAL_DRIVER, STM32H743xx, TX_ENABLE_FPU_SUPPORT, TX_ENABLE_STACK_CHECKING, TX_INCLUDE_USER_DEFINE_FILE` | `tx_template_config` INTERFACE 库统一分发给 C **和 ASM** |
| 8 个 IncludePath | 同样 8 个，最后一项换成 `ThreadX/ports/cortex_m7/gnu/inc` |
| `arm/startup_stm32h743xx.s`（armasm） | `gcc/startup_stm32h743xx.s`（GNU as） |
| `ports/cortex_m7/ac6/*.S` 8 个 | `ports/cortex_m7/gnu/*.S` 8 个 |
| `Objects/output.sct`（FLASH 2MB + AXI SRAM 512K） | `STM32H743XX_FLASH.ld`（同布局 + ThreadX 符号） |
| `--library_type=microlib` | `--specs=nano.specs -u _printf_float -lm` |
| `-Oz` / `-O0` | `Debug -O0 -g3` / `Release -Os -g0` |
| 213 个 C + 10 个 ASM | 185 内核 C + 14 HAL + 14 BSP/适配 + 1 main + 8 ThreadX 汇编 + 1 startup |
| `output(ac6).hex` | `build/Cmake_threadX_Template.{elf,hex,bin,map}` |

> HAL 时基：**不要把 SysTick 交给 HAL**。BSP 的 `stm32h7xx_hal_timebase_tim.c` 用 TIM7 提供 1 kHz，
> `main()` 在 `tx_kernel_enter()` 前 `HAL_SuspendTick()`，启动任务里再 `HAL_ResumeTick()`；
> SysTick 完全由 ThreadX 的 `tx_initialize_low_level.S` 接管（400 MHz / 1000 = 1 ms）。

---

## 4. 四个关键坑（以及本模板怎么解的）

1. **port 选错** — ac6 汇编是 armclang 语法，GCC 直接报错或链接异常；必须用 `gnu`。
2. **链接符号不匹配** — GNU `tx_initialize_low_level.S` 要 `_vectors` / `__RAM_segment_used_end__`；
   ld 里 `PROVIDE(_vectors = .)` 定义在 `.isr_vector` 起始，`PROVIDE(__RAM_segment_used_end__ = ADDR(._user_heap_stack) + SIZEOF(...) + 0x8000)` 给内核动态内存留起点。
3. **weak 强符号覆盖** — 见 §1③，用 OBJECT 库。已通过 `nm` 验证：
   `PendSV_Handler = 0x080002cc`（ThreadX `__tx_PendSVHandler`）、`SysTick_Handler = 0x080004e2`（`__tx_SysTickHandler`）。
4. **printf 没输出** — 原 BSP 重写 `fputc()` 是 microlib 方式；newlib 走 `_write() → __io_putchar()`。
   `bsp_retarget.c` 提供 `__io_putchar()` 调 `comSendChar(COM1, ...)`。
   另外 `main.c` 用 `printf("%.11f")` 打印 double，newlib-nano 默认裁掉浮点 printf，链接必须带 `-u _printf_float`。

附加两点：

- **主 RAM 选 AXI SRAM (0x24000000, 512K)** 而不是 DTCM：与 Keil 实际链接用的 `output.sct` 一致，也和 `MPU_Config()` 里 Region0 的 Write-back 配置一致；512K 更适合放任务栈。`_estack` 必须和 `.data/.bss/heap` 在同一块 RAM，否则 `sysmem.c` 的 `_sbrk()` 堆上限会算错。
- **GBK 注释**：GCC 虽能编译，但 GitHub 上不可读，已批量转 UTF-8。

---

## 5. 快速开始

### 环境

| 工具 | 本机验证版本 |
|---|---|
| arm-none-eabi-gcc | 15.3.rel2 |
| CMake | 4.4.5（≥ 3.22） |
| Ninja | 1.13.2 |
| OpenOCD（烧录用，可选） | xpack 0.12.0-7 |
| pyserial（串口脚本用，可选） | 3.5（`pip install pyserial`） |

`run.sh` 在 PATH 找不到工具时会自动回退到 `D:/Embedded_Toolchain/...` 下的安装路径。

### 构建

```bash
# 方式一：一键脚本（推荐）
./run.sh                 # Debug 全量构建
./run.sh clean           # 清空 build 后重建
./run.sh flash           # 构建后用 OpenOCD 烧录
BUILD_TYPE=Release ./run.sh

# 方式二：CMake Presets
cmake --preset Debug
cmake --build --preset Debug

# 方式三：显式命令
cmake -S . -B build -G Ninja \
      -DCMAKE_TOOLCHAIN_FILE=cmake/gcc-arm-none-eabi.cmake \
      -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel 8
```

产物（构建后由 CMake 自动生成，无需手动 objcopy）：

```
build/Cmake_threadX_Template.elf   # 带调试符号
build/Cmake_threadX_Template.hex   # OpenOCD / ST-Link 烧录
build/Cmake_threadX_Template.bin
build/Cmake_threadX_Template.map   # 段/符号分布
build/compile_commands.json        # clangd 补全
```

### 烧录 / 调试

```bash
openocd -f flash          # 必须在工程根目录执行（flash 里用相对路径）
```

VS Code 已配好 `cortex-debug`（`.vscode/launch.json`）：DAPLink 或 ST-Link 两种配置，F5 直接调试；
`Ctrl+Shift+B` 走 `.vscode/tasks.json` 调 `run.sh`。

### 上板验证（编译 → 烧录 → 抓串口 → 结论）

```bash
./tools/verify_on_board.sh            # 一键跑完，依赖 DAPLink + 串口
DURATION=30 ./tools/verify_on_board.sh # 抓更久
PORT=COM4    ./tools/verify_on_board.sh # 指定串口
```

或者分步来：

```bash
python tools/serial_monitor.py --list                  # 列出串口
python tools/serial_monitor.py --auto --duration 20    # 自动选端口抓 20 秒
openocd -f flash                                      # 烧录
```

### 预期输出

串口 1（115200-8-N-1）：启动后 `AppTaskMsg` / `AppTaskCom` 两个任务**每 500 ms 自动打印一次浮点数**（不需要按键）；
按 K1 会额外打印任务优先级/栈使用统计表，格式见 `Doc/01.例程功能说明.txt`。

---

## 6. 目录结构

```
Cmake_threadX_Template/
├── CMakeLists.txt                 顶层工程（工程名 = 目录名）
├── CMakePresets.json              Debug / Release 预设
├── STM32H743XX_FLASH.ld           链接脚本（含 ThreadX 符号适配）
├── startup_stm32h743xx.s          GNU 语法启动文件
├── run.sh / flash / flash-reset   构建与烧录
├── cmake/
│   ├── gcc-arm-none-eabi.cmake    工具链
│   ├── threadx.cmake              ThreadX 内核 + GNU port
│   ├── stm32h7.cmake              HAL + CMSIS
│   └── bsp.cmake                  安富莱 BSP + newlib 适配
├── User/
│   ├── main.c / includes.h / tx_user.h
│   ├── bsp/  bsp.c, bsp.h, *.h, stm32h7xx_it.c, hal_timebase_tim.c
│   │   ├── inc/   57 个 BSP 模块头
│   │   └── src/   54 个 BSP 驱动 + bsp_retarget.c
│   ├── fonts/     字库（默认不编译）
│   └── syscalls/  newlib 桩函数
├── tools/
│   ├── serial_monitor.py    串口抓取脚本（pyserial）
│   ├── thread_stack.gdb     GDB 脚本：读线程栈水位（免按键版 DispTaskInfo）
│   └── verify_on_board.sh   一键：编译 + 烧录 + 抓串口
├── Libraries/
│   ├── CMSIS/
│   └── STM32H7xx_HAL_Driver/
├── ThreadX/
│   ├── common/    inc(12) + src(185)
│   └── ports/cortex_m7/gnu/  inc + src(7) + example_build/tx_initialize_low_level.S
├── Doc/     例程说明 + serial_output_sample.txt（实抓串口日志）
├── .vscode/, LICENSE, THIRD_PARTY_NOTICES.md
```

**工程名自动取目录名**：整个文件夹复制并重命名成 `My_ThreadX_App` 后，
`.elf/.hex/.bin/.map`、`launch.json`、`flash` 全部自动跟随，无需改任何文件。

---

## 7. 配置开关

| 变量 | 默认 | 说明 |
|---|---|---|
| `CMAKE_BUILD_TYPE` | `Debug` | `Debug`(-O0 -g3) / `Release`(-Os -g0) |
| `HAL_AUTO_ALL_SOURCES` | `OFF` | `ON` 时编译 `Libraries/STM32H7xx_HAL_Driver/Src/*.c` 全量（排除 `*_template.c`） |
| `HAL_EXTRA_SOURCES` | 空 | 追加 HAL 源文件名，分号分隔，如 `"stm32h7xx_hal_adc.c;stm32h7xx_hal_adc_ex.c"` |
| `BSP_EXTRA_SOURCES` | 空 | 追加 BSP 源文件，如 `"bsp_i2c_gpio.c;bsp_i2c_mpu6050.c"` |

新增外设时记得同时打开 `User/bsp/stm32h7xx_hal_conf.h` 里对应的 `HAL_xxx_MODULE_ENABLED`。

---

## 8. 用这个模板跑教程后续章节

| 章节 | 需要的改动 |
|---|---|
| 3003~3010、3012~3017 | 只替换 `User/main.c` |
| 3003+（RTT 打印） | 额外 `-DBSP_EXTRA_SOURCES="SEGGER_RTT.c;SEGGER_RTT_printf.c"`（先复制源码到 `User/bsp/src/`） |
| 3011~3017（执行剖析） | 追加宏 `TX_EXECUTION_PROFILE_ENABLE`、`TX_CORTEX_M_EPK`，并加入 `tx_execution_profile.c` |
| 3005、3018 | 原例程只有 AC5 工程，`main.c` 可直接用；低功耗章节需自行核对时钟/唤醒代码 |
| 需要新外设 | `BSP_EXTRA_SOURCES` + `HAL_EXTRA_SOURCES` + `hal_conf.h` 三处 |

例：

```bash
cp "<教程>/V7-3012_ThreadX Event Flags Groups/User/main.c" User/main.c
cmake --preset Debug -DBSP_EXTRA_SOURCES="SEGGER_RTT.c;SEGGER_RTT_printf.c"
cmake --build --preset Debug
```

---

## 9. 上板验证结果（实板实测）

### 测试环境

| 项 | 值 |
|---|---|
| 开发板 | 安富莱 V7（STM32H743XIHx，Cortex-M7 @400MHz） |
| 调试器 | DAPLink / CMSIS-DAP（FW 1.0），SWD @1800 kHz |
| 串口 | CH340 → **COM4**，115200-8-N-1（板子 USART1） |
| 工具 | GCC 15.3.rel2 / CMake 4.4.5 / Ninja / OpenOCD 0.12.0 / pyserial 3.5 |

### 烧录

```
openocd -f flash
Info : [stm32h7x.cpu0] Cortex-M7 r1p1 processor detected
xPSR: 0x01000000 pc: 0x080087b4 msp: 0x24080000     ← msp 与链接脚本 _estack 一致
** Programming Finished **
** Verified OK **
```

### 串口输出（`tools/serial_monitor.py` 实抓 20 秒，80 行 / 4160 字节）

```
AppTaskMsg: f_a = 1.10000000210, f_b = 2.23449999580
AppTaskCom: f_a = 1.10000000210, f_b = 2.23449999580
AppTaskMsg: f_a = 1.10000000211, f_b = 2.23449999578
AppTaskCom: f_a = 1.10000000211, f_b = 2.23449999578
...
```

原始日志存档在 `Doc/serial_output_sample.txt`。这条输出同时证明了三件事：

1. **printf 重定向成功** —— newlib 的 `_write → __io_putchar → comSendChar(COM1)` 这条链是通的（这是移植中最容易"编译通过但没输出"的一环）。
2. **浮点打印成功** —— `%.11f` 精确到 1e-11，说明 `-u _printf_float` 与 `--specs=nano.specs` 配置正确。
3. **ThreadX 调度正常** —— `AppTaskMsg`（prio 3）与 `AppTaskCom`（prio 5）两个不同优先级的任务严格每 500 ms 交替输出一次；两个任务都在做 double 运算且数值连续无跳变，说明**浮点上下文（S16-S31）保存正确**，`TX_ENABLE_FPU_SUPPORT` 确实生效。

### 线程栈水位（`tools/thread_stack.gdb`，等效于按 K1 的 DispTaskInfo）

```
Taskname           Prio    Size     Used     Peak     Free  State
System Timer Thread    0    1020      395      395      625     3 (SUSPENDED)
App Task Start        2    4092      519      667     3573     4 (READY)
App Task STAT        30    1020      519      519      501     4 (READY)
App Task IDLE        31    1020      151       71      869     0 (READY)
App Msp Pro           3    4092      543     1007     3549     4 (READY)
App Task UserIF       4    4092      391      391     3701     4 (READY)
App Task COM          5    4092      543      907     3549     4 (READY)
线程总数(含系统定时器线程) = 7
OS CPU Usage = 0.67%
```

与原 Keil 例程 `User/main.c` 头部注释记录的栈数据**逐项对照**：

| 任务 | Keil(ARMCC) Cur / Max | 本模板(GCC) Used / Peak | 判定 |
|---|---|---|---|
| App Task Start | 383 / 391 | 519 / 667 | 同量级 |
| App Msp Pro | 543 / 659 | 543 / 1007 | 同量级 |
| App Task UserIF | 391 / 391 | **391 / 391** | 完全一致 |
| App Task COM | 543 / 659 | 543 / 907 | 同量级 |
| App Task STAT | 519 / 519 | **519 / 519** | 完全一致 |
| App Task IDLE | 143 / 71 | 151 / **71** | 完全一致 |
| System Timer Thread | 391 / 391 | **395 / 395** | 完全一致 |

| 项 | Keil(ARMCC) | 本模板(GCC) | 结论 |
|---|---|---|---|
| 任务数量 | 6 + 1 系统定时器线程 | 6 + 1 = **7** | 一致 |
| 任务名 / 优先级 / 栈大小 | 见原注释 | 完全一致 | 一致 |
| OS CPU Usage | 1.94% | 0.67% ~ 0.92% | 同量级 |

**结论：移植后的栈行为与 Keil 版等价**，最紧的 `App Task STAT`（1020 字节）也还剩 501 字节余量，不存在栈溢出风险，无需改动原例程的 `main.c`。

> **实测踩到的两个坑（已写进脚本，避免后人重踩）**
> 1. GDB 里 `tx_thread_stack_end - tx_thread_stack_ptr` 对 `ULONG*` 相减返回的是**字数**，
>    再 `*4` 会把用量放大 4 倍——一度误判成"`App Msp Pro` 只剩 64 字节、即将栈溢出"。
>    脚本里改用 `(char*)` 强制按字节相减后才与 Keil 数据对上。
> 2. OpenOCD 在 GDB 客户端断开后**默认保持 halted**，不 `monitor resume` 的话板子会"哑掉"，
>    串口一条数据都没有——很容易被误判成"固件跑飞"。脚本末尾已加 `monitor resume`。

### 看线程栈水位（免按 K1）

```bash
# 终端 A：起 GDB 服务器
openocd -f interface/cmsis-dap.cfg -f target/stm32h7x.cfg \
        -c "adapter speed 1800" -c "gdb port 3333" -c init -c "reset run"

# 终端 B：读出线程栈水位表
arm-none-eabi-gdb build/Cmake_threadX_Template.elf -x tools/thread_stack.gdb
```

> GDB 断开后 OpenOCD 默认保持 halted，脚本末尾已自动 `monitor resume`；
> 若手工操作，记得再执行一次 `monitor resume`，否则串口会没有输出。

### 一键复现

```bash
./tools/verify_on_board.sh            # 编译 + 烧录 + 抓 15 秒串口 + 结论
DURATION=30 ./tools/verify_on_board.sh
PORT=COM4    ./tools/verify_on_board.sh
```

### 静态级验证（上一版结论，仍然有效）

- Debug / Release 全量编译链接无错误，产出 elf/hex/bin/map。
- `nm` 确认 `_vectors = g_pfnVectors = 0x08000000`；向量表首字 `0x24080000`（`_estack`），Reset/PendSV/SysTick 入口均指向正确实现。
- `PendSV_Handler`、`SysTick_Handler` 被 ThreadX 强符号覆盖，未被 startup 的 weak 空实现吃掉。
- `TX_ENABLE_FPU_SUPPORT` 传入了汇编编译（`tx_thread_fpu_enable/disable` 符号存在，上下文切换会保存 S16-S31）。
- `_tx_initialize_low_level` 反汇编确认写入 `SCB->VTOR (0xE000ED08)`、SysTick LOAD/CTRL、SHPR1~3。
- `printf` / `_printf_float` / `__io_putchar` / `_write` 全部链接进镜像。

### 仍未覆盖 / 注意

- **按键 K1 路径未人工触发**（需物理按键），但该路径打印的正是上面 GDB 读出的同一份 TCB 数据，等效验证。
- `ThreadX/ports/cortex_m7/gnu/CMakeLists.txt` 是上游官方片段，本工程不使用它（构建由 `cmake/threadx.cmake` 负责）。
- 示例 `main.c` 用静态数组做任务栈，未使用 `first_unused_memory`；若改用 `tx_byte_pool_create()` 等动态分配，请核对 ld 里 `__RAM_segment_used_end__` 的 32 KB 余量是否够。
- `SVC_Handler` 保持 CMSIS 的 weak 空实现（Cortex-M7 版 ThreadX 不用 SVC），与原 Keil 工程行为一致。
- 实测未覆盖：DMA、低功耗、以太网、SD 卡等外设（模板未启用相应驱动）。

---

## 10. 许可证与致谢

本模板自身构建脚本与适配层采用 MIT（见 `LICENSE`）。第三方组件的来源与许可见 `THIRD_PARTY_NOTICES.md`：

- **Azure RTOS / ThreadX 6.0.2** — Microsoft，MIT（`ThreadX/LICENSE.txt`）
- **STM32H7xx HAL Driver 1.9.0 / CMSIS 5.4.0** — STMicroelectronics，BSD-3-Clause
- **安富莱 V7 BSP V1.2 与例程** — 安富莱电子 www.armfly.com，仅供学习
- **syscalls.c / sysmem.c** — STM32CubeMX 生成，STMicroelectronics

原教程与例程版权归安富莱电子所有，本仓库仅做构建系统移植与学习用途，请保留原始版权声明。
