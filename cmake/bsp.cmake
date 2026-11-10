# =============================================================================
#  安富莱 V7 BSP（BSP 驱动包 V1.2）+ newlib 系统调用适配层
#
#  User/bsp/src 下一共有 54 个驱动源文件，原 Keil 工程只编译其中 8 个。
#  这里同样只编译用到的部分；模板里保留了全部 BSP 源码，需要哪个外设时用：
#    cmake --preset Debug -DBSP_EXTRA_SOURCES="bsp_i2c_gpio.c;bsp_i2c_mpu6050.c"
#  （值可以是文件名，也可以是完整/相对路径）
#
#  User/syscalls/ 来自 STM32CubeMX 的 newlib 桩函数；
#  User/bsp/src/bsp_retarget.c 提供 __io_putchar()，把 printf 接到安富莱串口 FIFO。
#  原 BSP 的 fputc() 是 ARMCC/microlib 的重定向方式，GCC + newlib 不会调用它。
# =============================================================================

set(BSP_DIR "${CMAKE_SOURCE_DIR}/User/bsp")

set(BSP_SOURCES
    ${BSP_DIR}/bsp.c                                  # MPU / Cache / 400MHz 时钟 / bsp_Init
    ${BSP_DIR}/stm32h7xx_it.c                         # NMI / MemManage / BusFault 等
    ${BSP_DIR}/stm32h7xx_hal_timebase_tim.c           # HAL 时基改用 TIM7，避免与 ThreadX 抢 SysTick
    ${BSP_DIR}/src/bsp_led.c
    ${BSP_DIR}/src/bsp_dwt.c
    ${BSP_DIR}/src/bsp_key.c
    ${BSP_DIR}/src/bsp_timer.c
    ${BSP_DIR}/src/bsp_beep.c
    ${BSP_DIR}/src/bsp_fmc_io.c
    ${BSP_DIR}/src/bsp_uart_fifo.c
    ${BSP_DIR}/src/bsp_tim_pwm.c
    ${BSP_DIR}/src/bsp_retarget.c                     # GCC/newlib printf -> COM1
    ${CMAKE_SOURCE_DIR}/User/syscalls/syscalls.c
    ${CMAKE_SOURCE_DIR}/User/syscalls/sysmem.c
)

set(BSP_EXTRA_SOURCES "" CACHE STRING "额外加入的 BSP 源文件（分号分隔）")
foreach(_f ${BSP_EXTRA_SOURCES})
    if(IS_ABSOLUTE "${_f}")
        list(APPEND BSP_SOURCES "${_f}")
    elseif(EXISTS "${BSP_DIR}/src/${_f}")
        list(APPEND BSP_SOURCES "${BSP_DIR}/src/${_f}")
    else()
        list(APPEND BSP_SOURCES "${_f}")
    endif()
endforeach()

list(LENGTH BSP_SOURCES _bsp_count)
message(STATUS "BSP         : ${_bsp_count} 个源文件")

add_library(armfly_bsp OBJECT ${BSP_SOURCES})
target_link_libraries(armfly_bsp PRIVATE tx_template_config)
