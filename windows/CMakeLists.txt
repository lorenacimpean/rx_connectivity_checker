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
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin netlistmgr.lib)

# --- Unit tests ---
if(${include_rx_connectivity_checker_tests})
    set(TEST_NAME rx_connectivity_checker_tests)

    # Add GoogleTest
    include(FetchContent)
    FetchContent_Declare(
            googletest
            GIT_REPOSITORY https://github.com/google/googletest.git
            GIT_TAG v1.14.0
    )
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(googletest)

    # Build test executable
    add_executable(${TEST_NAME}
            test/main.cpp
            test/rx_connectivity_checker_plugin_test.cpp
            ${PLUGIN_SOURCES}
    )
    apply_standard_settings(${TEST_NAME})

    # Include directories & link libraries
    target_include_directories(${TEST_NAME} PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}
            ${CMAKE_CURRENT_SOURCE_DIR}/include
    )
    target_link_libraries(${TEST_NAME} PRIVATE gtest gtest_main flutter flutter_wrapper_plugin netlistmgr.lib)

    # Copy Flutter DLL for runtime
    add_custom_command(TARGET ${TEST_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_NAME}>
    )

    # Enable automatic test discovery
    include(GoogleTest)
    gtest_discover_tests(${TEST_NAME})
endif()
