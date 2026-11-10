#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
==========================================================================================================
串口监视脚本 —— 用于验证 Cmake_threadX_Template 固件的串口输出
==========================================================================================================

背景
    本模板把安富莱 BSP 的 fputc()（ARMCC/microlib 方式）换成了 newlib 的
    __io_putchar()（见 User/bsp/src/bsp_retarget.c），printf 是否真的从串口吐出来，
    只能上板看。本脚本负责抓这段输出。

用法
    python tools/serial_monitor.py --list                    # 列出所有串口
    python tools/serial_monitor.py --auto --duration 20       # 自动选端口抓 20 秒
    python tools/serial_monitor.py --port COM4 --duration 15   # 指定端口
    python tools/serial_monitor.py --port COM4 --log build/serial.log --quiet

固件侧预期输出（Cmake_threadX_Template 的 User/main.c）
    AppTaskMsg: f_a = 1.10000000001, f_b = 2.23449999998      每 500ms 一次
    按 K1 还会打印任务优先级/栈使用统计表（需要人工按键）

依赖
    pip install pyserial
==========================================================================================================
"""

import argparse
import os
import sys
import time

try:
    import serial
    import serial.tools.list_ports as list_ports
except ImportError:  # pragma: no cover
    print("缺少依赖 pyserial，请先执行： pip install pyserial")
    sys.exit(2)


# 主板自带的老式通信口（ACPI PNP0501），一般不是开发板的调试串口
DESKTOP_PORT_HINTS = ("pnp0501", "dlab", " prolific")
# 开发板常见的 USB 转串口芯片，优先级最高（安富莱 V7 用 CH340）
USB_UART_HINTS = ("ch340", "ch341", "cp210", "ftdi")
# 其它 USB CDC 串口（例如 CMSIS-DAP 自带的虚拟串口）优先级较低
USB_CDC_HINTS = ("usb 串行设备", "usb serial")


def show_ports():
    """列出本机所有串口"""
    ports = list(list_ports.comports())
    if not ports:
        print("没有发现任何串口设备")
        return []
    print("可用串口：")
    for p in ports:
        print("  %-8s %-28s %s" % (p.device, p.description, p.hwid))
    return ports


def pick_port(ports, wanted=None):
    """挑选要打开的端口：指定 > CH340 等 USB 串口 > 非主板口 > 第一个"""
    if wanted:
        for p in ports:
            if p.device.upper() == wanted.upper():
                return p
        print("找不到端口 %s" % wanted)
        return None

    def score(p):
        text = ("%s %s" % (p.description, p.hwid)).lower()
        if any(h in text for h in DESKTOP_PORT_HINTS):
            return 0
        if any(h in text for h in USB_UART_HINTS):
            return 4
        if p.device.upper() == "COM1":
            return 1
        if any(h in text for h in USB_CDC_HINTS):
            return 2
        return 3

    best = sorted(ports, key=score, reverse=True)[0]
    if score(best) == 0:
        print("提示：只找到主板自带串口 %s，若开发板没接上请检查 USB 线" % best.device)
    return best


def dump_summary(lines, raw_bytes, duration, port_name, quiet=False):
    print("")
    print("=" * 78)
    print("串口汇总：端口 %s，时长 %.1f s，收到 %d 字节 / %d 行" %
          (port_name, duration, raw_bytes, len(lines)))
    print("=" * 78)
    if not lines:
        print("!! 没有收到任何一行输出")
        print("   排查顺序：")
        print("   1) 固件是否已烧录并运行（openocd -f flash）")
        print("   2) 串口线是否插在开发板的 USART1（CH340）上，TX/RX 是否反接")
        print("   3) 波特率是否为 115200-8-N-1")
        print("   4) bsp_Init() 之前没有输出是正常的（串口在那里才初始化）")
        return 1

    keys = ("AppTaskMsg", "OS CPU Usage", "Prio", "Taskname", "App Task")
    hit = [ln for ln in lines if any(k in ln for k in keys)]
    if hit:
        print("识别到 ThreadX 模板的标志性输出 %d 行，例如：" % len(hit))
        for ln in hit[:6]:
            print("   " + ln)
        print("=> printf 重定向与 ThreadX 调度均正常")
    else:
        print("收到 %d 行数据，但未匹配到模板预期关键字" % len(lines))
        for ln in lines[:10]:
            print("   " + ln)
    return 0


def main():
    ap = argparse.ArgumentParser(description="安富莱 V7 ThreadX 模板串口监视")
    ap.add_argument("--port", help="串口号，例如 COM4；缺省自动选择")
    ap.add_argument("--auto", action="store_true",
                    help="显式要求自动选择端口（默认行为，此参数仅为可读性保留）")
    ap.add_argument("--baud", type=int, default=115200, help="波特率，默认 115200")
    ap.add_argument("--duration", type=float, default=15.0, help="抓取时长（秒），默认 15")
    ap.add_argument("--log", help="原始日志保存路径")
    ap.add_argument("--list", action="store_true", help="只列出串口后退出")
    ap.add_argument("--quiet", action="store_true", help="不逐行打印，只统计")
    ap.add_argument("--assert-dtr", action="store_true",
                    help="打开时拉高 DTR/RTS（部分板子用它复位 MCU，默认不拉高以免反复复位）")
    args = ap.parse_args()

    ports = show_ports()
    if args.list:
        return 0
    if not ports:
        return 2

    target = pick_port(ports, args.port)
    if target is None:
        return 2

    print("")
    print("打开 %s（%s）@ %d 8N1，抓取 %.1f 秒 ..." %
          (target.device, target.description, args.baud, args.duration))

    try:
        ser = serial.Serial(
            port=target.device,
            baudrate=args.baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.2,
            write_timeout=1.0,
        )
    except Exception as exc:
        print("打开串口失败：%s" % exc)
        return 2

    if not args.assert_dtr:
        try:
            ser.dtr = False
            ser.rts = False
        except Exception:
            pass

    log_path = args.log
    log_fp = None
    if log_path:
        os.makedirs(os.path.dirname(os.path.abspath(log_path)), exist_ok=True)
        log_fp = open(log_path, "wb")
        print("原始日志 -> %s" % log_path)

    buf = bytearray()
    lines = []
    start = time.time()
    last_report = start
    try:
        while time.time() - start < args.duration:
            chunk = ser.read(ser.in_waiting or 1)
            if chunk:
                buf.extend(chunk)
                if log_fp:
                    log_fp.write(chunk)
                while b"\n" in buf:
                    raw, _, rest = buf.partition(b"\n")
                    buf = bytearray(rest)
                    text = raw.decode("utf-8", errors="replace").rstrip("\r")
                    if text:
                        lines.append(text)
                        if not args.quiet:
                            print("[%6.2fs] %s" % (time.time() - start, text))
            now = time.time()
            if now - last_report >= 5:
                last_report = now
                print("  ... 已运行 %.0fs，累计 %d 字节" % (now - start, len(buf)))
    except KeyboardInterrupt:
        print("")
        print("用户中断")
    finally:
        try:
            ser.close()
        except Exception:
            pass
        if log_fp:
            log_fp.close()

    return dump_summary(lines, sum(len(x.encode("utf-8", "replace")) for x in lines) + len(buf),
                        time.time() - start, target.device, args.quiet)


if __name__ == "__main__":
    sys.exit(main())
