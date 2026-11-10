# =============================================================================
#  Cmake_threadX_Template
#  安富莱 V7 (STM32H743XIHx) ThreadX 例程 —— CMake + arm-none-eabi-gcc 移植模板
#
#  设计原则：
#   1. 源码目录结构原样保留原例程（User / Libraries / ThreadX），
#      教程 3003~3018 只需替换 User/main.c（必要时追加 BSP 源文件）即可复用。
#   2. 各组件用 CMake OBJECT 库分层，而不是静态库 .a：
#      ThreadX 的 PendSV_Handler / SysTick_Handler 是「强符号覆盖启动文件弱符号」，
#      若放进静态库，链接器按需抽取时不会为了覆盖 weak 而去取目标文件，
#      RTOS 会失去调度心跳。OBJECT 库的目标文件无条件参与链接，天然避开这个坑。
#   3. 工程名 = 所在目录名，复制整个文件夹重命名即可生成新工程。
# =============================================================================
cmake_minimum_required(VERSION 3.22)

# 注意：toolchain 文件是在 project() 时才被 CMake 读取的，所以此处只能检查变量本身
if(NOT DEFINED CMAKE_TOOLCHAIN_FILE OR "${CMAKE_TOOLCHAIN_FILE}" STREQUAL "")
    message(FATAL_ERROR
        "未检测到交叉编译工具链。请用以下任一方式配置：\n"
        "  cmake --preset Debug\n"
        "  cmake -G Ninja -DCMAKE_TOOLCHAIN_FILE=cmake/gcc-arm-none-eabi.cmake -B build\n"
        "  ./run.sh")
endif()

get_filename_component(_AUTO_PROJECT_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
set(CMAKE_PROJECT_NAME "${_AUTO_PROJECT_NAME}")
project(${CMAKE_PROJECT_NAME} LANGUAGES C ASM)

set(CMAKE_C_STANDARD           11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS         ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Build type" FORCE)
endif()
message(STATUS "Project      : ${CMAKE_PROJECT_NAME}")
message(STATUS "Build type   : ${CMAKE_BUILD_TYPE}")
message(STATUS "Toolchain    : ${CMAKE_C_COMPILER}")

list(REMOVE_ITEM CMAKE_C_IMPLICIT_LINK_LIBRARIES ob)

# -----------------------------------------------------------------------------
# 全局编译配置：一个 INTERFACE 库统一分发给所有组件，避免宏/头文件路径各写一份
# -----------------------------------------------------------------------------
add_library(tx_template_config INTERFACE)

target_compile_definitions(tx_template_config INTERFACE
    USE_HAL_DRIVER                  # 使用 STM32 HAL 库
    STM32H743xx                     # 器件型号
    TX_ENABLE_FPU_SUPPORT           # ThreadX 上下文切换保存 S16-S31（C 与 ASM 都要）
    TX_ENABLE_STACK_CHECKING        # 对齐原 Keil 工程
    TX_INCLUDE_USER_DEFINE_FILE     # 使 tx_api.h / tx_port.h 包含 User/tx_user.h
)

target_include_directories(tx_template_config INTERFACE
    ${CMAKE_SOURCE_DIR}/User
    ${CMAKE_SOURCE_DIR}/User/bsp
    ${CMAKE_SOURCE_DIR}/User/bsp/inc
    ${CMAKE_SOURCE_DIR}/Libraries/CMSIS/Include
    ${CMAKE_SOURCE_DIR}/Libraries/CMSIS/Device/ST/STM32H7xx/Include
    ${CMAKE_SOURCE_DIR}/Libraries/STM32H7xx_HAL_Driver/Inc
    ${CMAKE_SOURCE_DIR}/ThreadX/common/inc
    ${CMAKE_SOURCE_DIR}/ThreadX/ports/cortex_m7/gnu/inc
)

# -----------------------------------------------------------------------------
# 组件
# -----------------------------------------------------------------------------
include(cmake/threadx.cmake)
include(cmake/stm32h7.cmake)
include(cmake/bsp.cmake)

# -----------------------------------------------------------------------------
# 可执行目标
#   startup 必须直接放在可执行目标里（静态/OBJECT 库中的向量表 .o 有被丢弃风险，
#   且链接脚本依赖 .isr_vector 段位于 FLASH 起始地址）
# -----------------------------------------------------------------------------
add_executable(${CMAKE_PROJECT_NAME}
    ${CMAKE_SOURCE_DIR}/startup_stm32h743xx.s
    ${CMAKE_SOURCE_DIR}/User/main.c
)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
    tx_template_config
    threadx
    stm32h7
    armfly_bsp
)

target_link_options(${CMAKE_PROJECT_NAME} PRIVATE
    "-Wl,-Map=${CMAKE_BINARY_DIR}/${CMAKE_PROJECT_NAME}.map"
)

# -----------------------------------------------------------------------------
# 构建后处理：生成 .hex / .bin 并打印尺寸
# -----------------------------------------------------------------------------
add_custom_command(TARGET ${CMAKE_PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O ihex   $<TARGET_FILE:${CMAKE_PROJECT_NAME}>
            ${CMAKE_BINARY_DIR}/${CMAKE_PROJECT_NAME}.hex
    COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${CMAKE_PROJECT_NAME}>
            ${CMAKE_BINARY_DIR}/${CMAKE_PROJECT_NAME}.bin
    COMMAND ${CMAKE_SIZE} --format=berkeley $<TARGET_FILE:${CMAKE_PROJECT_NAME}>
    COMMENT "生成 ${CMAKE_PROJECT_NAME}.hex / .bin 并统计 Flash/RAM 占用"
    VERBATIM
)
