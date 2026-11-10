# =============================================================================
#  Azure RTOS / ThreadX 6.0.2  —— 内核 + Cortex-M7 GNU port
#
#  原 Keil 工程用的是 ThreadX/ports/cortex_m7/ac6（armclang 汇编语法），
#  GCC 必须换成 ports/cortex_m7/gnu：
#    - common/src/*.c          185 个，与编译器无关，全量编译
#    - ports/cortex_m7/gnu/src/*.S    7 个（上下文保存/恢复、PendSV、SysTick 等）
#    - gnu/example_build/tx_initialize_low_level.S
#        官方 GNU 版底层初始化：设置 VTOR、SysTick(1kHz)、异常优先级、
#        给出 first_unused_memory。它引用链接脚本符号 _vectors 与
#        __RAM_segment_used_end__，这两个符号由 STM32H743XX_FLASH.ld 提供，
#        因此无需改动 ThreadX 官方源码即可升级内核。
#
#  tx_initialize_low_level.S 定义强符号 SysTick_Handler，
#  tx_thread_schedule.S 定义强符号 PendSV_Handler，
#  用来覆盖 CMSIS 启动文件里的 .weak 空实现。
# =============================================================================

set(TX_ROOT "${CMAKE_SOURCE_DIR}/ThreadX")
set(TX_PORT "${TX_ROOT}/ports/cortex_m7/gnu")

file(GLOB TX_COMMON_SOURCES CONFIGURE_DEPENDS "${TX_ROOT}/common/src/*.c")

set(TX_PORT_SOURCES
    ${TX_PORT}/src/tx_thread_context_restore.S
    ${TX_PORT}/src/tx_thread_context_save.S
    ${TX_PORT}/src/tx_thread_interrupt_control.S
    ${TX_PORT}/src/tx_thread_schedule.S
    ${TX_PORT}/src/tx_thread_stack_build.S
    ${TX_PORT}/src/tx_thread_system_return.S
    ${TX_PORT}/src/tx_timer_interrupt.S
    ${TX_PORT}/example_build/tx_initialize_low_level.S
)

list(LENGTH TX_COMMON_SOURCES _tx_c_count)
message(STATUS "ThreadX     : common/src ${_tx_c_count} 个 C + gnu port 8 个汇编")

add_library(threadx OBJECT ${TX_COMMON_SOURCES} ${TX_PORT_SOURCES})
target_link_libraries(threadx PRIVATE tx_template_config)
