cmake
cmake_minimum_required(VERSION 3.14)

# Project name.
# The CXX language is added by the CppWinRT package.
project(rx_connectivity_checker)

# Find and apply C++/WinRT.
# The an empty CMAKE_FIND_ROOT_PATH is needed to find the CppWinRT.cmake
# file that is part of the CppWinRT NuGet package.
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
find_package(CppWinRT REQUIRED)

# Plugin library name
set(PLUGIN_NAME rx_connectivity_checker_plugin)

# Build library
add_library(${PLUGIN_NAME} SHARED
        "rx_connectivity_checker_plugin.cpp"
        "rx_connectivity_checker_plugin.h"
        "connectivity_stream_handler.cpp"
        "connectivity_stream_handler.h"
)

# Apply Flutter standard settings
apply_standard_settings(${PLUGIN_NAME})

# C++ standard
set_target_properties(${PLUGIN_NAME} PROPERTIES
        CXX_STANDARD 20
        CXX_STANDARD_REQUIRED YES
        CXX_EXTENSIONS NO
)

# The CppWinRT package adds the necessary include paths, so this is no longer needed.
# target_include_directories(${PLUGIN_NAME} PUBLIC
#         "${CMAKE_CURRENT_SOURCE_DIR}/include"
# )

# Link libraries.
target_link_libraries(${PLUGIN_NAME} PRIVATE
        flutter
        flutter_wrapper_plugin
        # Link against the C++/WinRT libraries.
        winrt_base
)

# Register plugin
set(rx_connectivity_checker_bundled_libraries
        ""
        PARENT_SCOPE
)
