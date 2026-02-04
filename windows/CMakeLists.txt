cmake_minimum_required(VERSION 3.15)

# Project name (must match plugin name)
set(PROJECT_NAME "rx_connectivity_checker")

project(${PROJECT_NAME} LANGUAGES CXX)

# Plugin target name
set(PLUGIN_NAME ${PROJECT_NAME}_plugin)

# Source files
add_library(${PLUGIN_NAME} SHARED
        "rx_connectivity_checker_plugin.cpp"
        "connectivity_stream_handler.cpp"
)

# Standard Flutter / MSVC settings
apply_standard_settings(${PLUGIN_NAME})

# C++ Standard (WinRT needs C++20 for best compatibility)
set_target_properties(${PLUGIN_NAME} PROPERTIES
        CXX_STANDARD 20
        CXX_STANDARD_REQUIRED YES
        CXX_EXTENSIONS NO
)

# Public include directory
target_include_directories(${PLUGIN_NAME} PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

# Required Windows + Flutter libraries
target_link_libraries(${PLUGIN_NAME} PRIVATE
        flutter
        flutter_wrapper_plugin
        windowsapp
)

# Export plugin to Flutter
flutter_add_plugin(${PLUGIN_NAME})
