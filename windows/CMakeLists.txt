cmake_minimum_required(VERSION 3.15)

# Plugin name
set(PROJECT_NAME "rx_connectivity_checker")

project(${PROJECT_NAME} LANGUAGES CXX)

# Flutter-managed config (REQUIRED)
include(flutter/generated_plugins.cmake)

# Plugin target name
set(PLUGIN_NAME ${PROJECT_NAME}_plugin)

# Sources
add_library(${PLUGIN_NAME} SHARED
        "rx_connectivity_checker_plugin.cpp"
        "connectivity_stream_handler.cpp"
)

# Standard Flutter settings
apply_standard_settings(${PLUGIN_NAME})

# C++ Standard
set_target_properties(${PLUGIN_NAME} PROPERTIES
        CXX_STANDARD 20
        CXX_STANDARD_REQUIRED YES
        CXX_EXTENSIONS NO
)

# Include dirs
target_include_directories(${PLUGIN_NAME} PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

# Link Flutter + Windows
target_link_libraries(${PLUGIN_NAME} PRIVATE
        flutter
        flutter_wrapper_plugin
        windowsapp
)

# Register plugin
flutter_add_plugin(${PLUGIN_NAME})
