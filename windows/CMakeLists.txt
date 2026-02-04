cmake_minimum_required(VERSION 3.14)

# Project name
project(rx_connectivity_checker LANGUAGES CXX)

# Plugin library name
set(PLUGIN_NAME rx_connectivity_checker_plugin)

# Build library
add_library(${PLUGIN_NAME} SHARED
        "rx_connectivity_checker_plugin.cpp"
        "connectivity_stream_handler.cpp"
)

# Apply Flutter standard settings
apply_standard_settings(${PLUGIN_NAME})

# C++ standard
set_target_properties(${PLUGIN_NAME} PROPERTIES
        CXX_STANDARD 20
        CXX_STANDARD_REQUIRED YES
        CXX_EXTENSIONS NO
)

# Include dirs
target_include_directories(${PLUGIN_NAME} PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

# Link Flutter
target_link_libraries(${PLUGIN_NAME} PRIVATE
        flutter
        flutter_wrapper_plugin
        windowsapp
)

# Register plugin
set(rx_connectivity_checker_bundled_libraries
        ""
        PARENT_SCOPE
)
