cmake_minimum_required(VERSION 3.14)
project(rx_connectivity_checker LANGUAGES CXX)
cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "rx_connectivity_checker_plugin")

list(APPEND PLUGIN_SOURCES
        "rx_connectivity_checker_plugin.cpp"
        "rx_connectivity_checker_plugin.h"
)

# --- Plugin library ---
add_library(${PLUGIN_NAME} SHARED
        "include/rx_connectivity_checker/rx_connectivity_checker_plugin_c_api.h"
        "rx_connectivity_checker_plugin_c_api.cpp"
        ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME}
        PROPERTIES
        CXX_VISIBILITY_PRESET hidden
)

target_compile_definitions(${PLUGIN_NAME}
        PRIVATE
        FLUTTER_PLUGIN_IMPL
)

target_include_directories(${PLUGIN_NAME}
        INTERFACE
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_link_libraries(${PLUGIN_NAME}
        PRIVATE
        flutter
        flutter_wrapper_plugin
        netlistmgr.lib
)
