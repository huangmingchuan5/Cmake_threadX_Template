# =============================================================================
#  ThreadX 线程栈水位查看（GDB 脚本，免按键版 DispTaskInfo）
#
#  作用：原例程里按 K1 才会打印任务优先级/栈使用统计，这个脚本可以在电脑上
#        直接读出同样的数据，还能顺带看 CPU 占用率。
#
#  用法：
#    终端 A：openocd -f interface/cmsis-dap.cfg -f target/stm32h7x.cfg \
#                    -c "adapter speed 1800" -c "gdb port 3333" -c init -c "reset run"
#    终端 B：arm-none-eabi-gdb build/<工程名>.elf -x tools/thread_stack.gdb
#
#  也可以直接用 tools/verify_on_board.sh 一键跑完整个流程。
# =============================================================================

target remote :3333

printf "\n================ ThreadX 线程栈水位 ================\n"
printf "%-18s %4s %7s %8s %8s %8s %6s\n", "Taskname", "Prio", "Size", "Used", "Peak", "Free", "State"
set $t = _tx_thread_created_ptr
set $n = 0
while $t != 0 && $n < 64
  # 注意：栈字段相减必须按字节算。gdb 里对 ULONG* 相减得到的是"字数"，
  # 乘 4 会把数值放大 4 倍（一度误判成栈溢出）。这里强制转 char* 做字节差。
  set $used = ((char *)$t->tx_thread_stack_end - (char *)$t->tx_thread_stack_ptr)
  set $peak = ((char *)$t->tx_thread_stack_end - (char *)$t->tx_thread_stack_highest_ptr)
  printf "%-18s %4d %7d %8d %8d %8d %6d\n", $t->tx_thread_name, $t->tx_thread_priority, $t->tx_thread_stack_size, $used, $peak, ($t->tx_thread_stack_size - $used), $t->tx_thread_state
  set $t = $t->tx_thread_created_next
  set $n = $n + 1
  # ThreadX 的线程链表是环形的，转回起点就结束
  if $t == _tx_thread_created_ptr
    loop_break
  end
end
printf "线程总数(含系统定时器线程) = %d\n", _tx_thread_created_count
printf "OS CPU Usage = %.2f%%\n", OSCPUUsage
printf "======================================================\n\n"

# 让板子继续跑：openocd 在 gdb 断开后默认保持 halted，不 resume 的话串口会没有输出
monitor resume
detach
quit
