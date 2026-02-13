cmake_minimum_required(VERSION 3.14)

project(rx_connectivity_checker)

set(PLUGIN_NAME rx_connectivity_checker_plugin)

add_library(${PLUGIN_NAME} SHARED
        "rx_connectivity_checker_plugin.cpp"
        "rx_connectivity_checker_plugin.h"
        "rx_connectivity_checker_plugin_c_api.cpp"
        "include/rx_connectivity_checker/rx_connectivity_checker_plugin_c_api.h"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
        CXX_STANDARD 20
        CXX_STANDARD_REQUIRED YES
        CXX_EXTENSIONS NO
)

target_include_directories(${PLUGIN_NAME} PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE
        FLUTTER_PLUGIN_IMPL
)

target_link_libraries(${PLUGIN_NAME} PRIVATE
        flutter
        flutter_wrapper_plugin
        ole32
        uuid
)

set(rx_connectivity_checker_bundled_libraries
        ""
        PARENT_SCOPE
)