cmake_minimum_required(VERSION 3.14)

project(rx_connectivity_checker)

set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
find_package(CppWinRT REQUIRED)

set(PLUGIN_NAME rx_connectivity_checker_plugin)

add_library(${PLUGIN_NAME} SHARED
        "rx_connectivity_checker_plugin.cpp"
        "rx_connectivity_checker_plugin.h"
        "connectivity_stream_handler.cpp"
        "connectivity_stream_handler.h"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
        CXX_STANDARD 20
        CXX_STANDARD_REQUIRED YES
        CXX_EXTENSIONS NO
)

target_link_libraries(${PLUGIN_NAME} PRIVATE
        flutter
        flutter_wrapper_plugin
        winrt_base
)

set(rx_connectivity_checker_bundled_libraries
        ""
        PARENT_SCOPE
)
