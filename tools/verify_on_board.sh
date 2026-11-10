#!/usr/bin/env bash
# ============================================================
# 一键上板验证：编译 -> 烧录 -> 抓串口 -> 打印结论
#
#   ./tools/verify_on_board.sh              # 默认抓 15 秒
#   DURATION=30 ./tools/verify_on_board.sh  # 抓更久
#   PORT=COM4 ./tools/verify_on_board.sh    # 指定串口
#
# 依赖：DAPLink/CMSIS-DAP 调试器 + 板子 USB 转串口（安富莱 V7 用 CH340）
# ============================================================
set -e

cd "$(dirname "$0")/.."

TOOLCHAIN_ROOT="/d/Embedded_Toolchain"
command -v arm-none-eabi-gcc >/dev/null 2>&1 || \
    export PATH="$TOOLCHAIN_ROOT/arm-none-eabi-gcc/15.3.rel2/bin:$PATH"
command -v cmake >/dev/null 2>&1 || \
    export PATH="$TOOLCHAIN_ROOT/cmake/4.4.5/bin:$PATH"
command -v ninja >/dev/null 2>&1 || \
    export PATH="$TOOLCHAIN_ROOT/ninja/1.13.2:$PATH"
command -v openocd >/dev/null 2>&1 || \
    export PATH="$TOOLCHAIN_ROOT/xpack-openocd/0.12.0-7/xpack-openocd-0.12.0-7/bin:$PATH"
command -v python >/dev/null 2>&1 || \
    export PATH="$TOOLCHAIN_ROOT/../python:$PATH"

DURATION="${DURATION:-15}"
ELF_NAME="$(basename "$(pwd)")"

echo "[1/3] 编译 ..."
./run.sh

echo ""
echo "[2/3] 烧录 (OpenOCD + CMSIS-DAP) ..."
openocd -f flash

echo ""
echo "[3/3] 抓取串口输出 ${DURATION}s ..."
if [ -n "$PORT" ]; then
    python tools/serial_monitor.py --port "$PORT" --duration "$DURATION" --log build/serial.log
else
    python tools/serial_monitor.py --auto --duration "$DURATION" --log build/serial.log
fi

echo ""
echo "提示：想看各任务栈水位（相当于按 K1），执行"
echo "  openocd -f interface/cmsis-dap.cfg -f target/stm32h7x.cfg \\"
echo "          -c \"adapter speed 1800\" -c \"gdb port 3333\" -c init -c \"reset run\""
echo "  arm-none-eabi-gdb build/$ELF_NAME.elf -x tools/thread_stack.gdb"
