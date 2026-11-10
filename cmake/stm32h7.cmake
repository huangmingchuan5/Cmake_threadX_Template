# =============================================================================
#  CMSIS + STM32H7xx HAL Driver（ST 固件库 1.9.0）
#
#  默认只编译原 Keil 工程实际引用的 14 个 HAL .c —— 已验证可链接、编译最快。
#  新增外设时有两种方式（不必改本文件）：
#    cmake --preset Debug -DHAL_EXTRA_SOURCES="stm32h7xx_hal_adc.c;stm32h7xx_hal_adc_ex.c"
#  或一次性打开全部 HAL 源文件（编译慢一些，但不会漏文件）：
#    cmake --preset Debug -DHAL_AUTO_ALL_SOURCES=ON
#  注意：无论哪种方式，都要先在 User/bsp/stm32h7xx_hal_conf.h 里打开对应 HAL_xxx_MODULE_ENABLED。
# =============================================================================

option(HAL_AUTO_ALL_SOURCES "编译 Drivers 下全部 HAL 驱动源文件" OFF)
set(HAL_EXTRA_SOURCES "" CACHE STRING "额外加入的 HAL 源文件名（相对 Src 目录，分号分隔）")

set(HAL_DIR "${CMAKE_SOURCE_DIR}/Libraries/STM32H7xx_HAL_Driver")

# 原 Keil 工程 <Groups>/HAL_Driver 中的 14 个文件
set(HAL_CORE_SOURCES
    stm32h7xx_hal.c
    stm32h7xx_hal_cortex.c
    stm32h7xx_hal_rcc.c
    stm32h7xx_hal_rcc_ex.c
    stm32h7xx_hal_gpio.c
    stm32h7xx_hal_dma.c
    stm32h7xx_hal_dma_ex.c
    stm32h7xx_hal_tim.c
    stm32h7xx_hal_tim_ex.c
    stm32h7xx_hal_uart.c
    stm32h7xx_hal_uart_ex.c
    stm32h7xx_ll_fmc.c
    stm32h7xx_hal_sram.c
    stm32h7xx_hal_mdma.c
)

if(HAL_AUTO_ALL_SOURCES)
    file(GLOB HAL_ALL CONFIGURE_DEPENDS "${HAL_DIR}/Src/*.c")
    set(HAL_SOURCES "")
    foreach(_f ${HAL_ALL})
        # *_template.c 会与 bsp/stm32h7xx_hal_timebase_tim.c、hal_msp 冲突
        if(NOT _f MATCHES "_template\\.c$")
            list(APPEND HAL_SOURCES "${_f}")
        endif()
    endforeach()
else()
    set(HAL_SOURCES "")
    foreach(_f ${HAL_CORE_SOURCES})
        list(APPEND HAL_SOURCES "${HAL_DIR}/Src/${_f}")
    endforeach()
    foreach(_f ${HAL_EXTRA_SOURCES})
        list(APPEND HAL_SOURCES "${HAL_DIR}/Src/${_f}")
    endforeach()
endif()

list(LENGTH HAL_SOURCES _hal_count)
message(STATUS "HAL         : ${_hal_count} 个源文件")

add_library(stm32h7 OBJECT
    ${HAL_SOURCES}
    ${CMAKE_SOURCE_DIR}/Libraries/CMSIS/Device/ST/STM32H7xx/Source/Templates/system_stm32h7xx.c
)
target_link_libraries(stm32h7 PRIVATE tx_template_config)
