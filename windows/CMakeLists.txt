cmake_minimum_required(VERSION 3.14)

project(rx_connectivity_checker)

set(PLUGIN_NAME rx_connectivity_checker_plugin)

add_library(${PLUGIN_NAME} SHARED
        "rx_connectivity_checker_plugin.cpp"
        "rx_connectivity_checker_plugin.h"
        "rx_connectivity_checker_plugin_c_api.h"
        "rx_connectivity_checker_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
        CXX_STANDARD 20
        CXX_STANDARD_REQUIRED YES
        CXX_EXTENSIONS NO
)

# CRITICAL: Link system libraries for COM and NetworkListManager
target_link_libraries(${PLUGIN_NAME} PRIVATE
        flutter
        flutter_wrapper_plugin
        ole32   # For CoCreateInstance, CoInitializeEx
        uuid    # For CLSID_NetworkListManager, IID_INetworkListManagerEvents
)

set(rx_connectivity_checker_bundled_libraries
        ""
        PARENT_SCOPE
)