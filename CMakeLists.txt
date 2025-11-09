cmake_minimum_required(VERSION 3.10)
project(libuv-webserver C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Add subdirectories for dependencies
add_subdirectory(deps/libuv EXCLUDE_FROM_ALL)

# Build llhttp as a static library
add_library(llhttp STATIC
    deps/llhttp/src/api.c
    deps/llhttp/src/http.c
    deps/llhttp/src/llhttp.c
)

target_include_directories(llhttp PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/deps/llhttp/include
)

# Webserver executable
add_executable(webserver webserver.cc)
target_link_libraries(webserver PRIVATE uv_a llhttp)
target_include_directories(webserver PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/deps/libuv/include
    ${CMAKE_CURRENT_SOURCE_DIR}/deps/llhttp/include
)

# Webclient executable
add_executable(webclient webclient.cc)
target_link_libraries(webclient PRIVATE uv_a llhttp)
target_include_directories(webclient PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/deps/libuv/include
    ${CMAKE_CURRENT_SOURCE_DIR}/deps/llhttp/include
)

# macOS specific - CoreFoundation needed for debugging tools like Instruments
if(APPLE)
    target_link_libraries(webserver PRIVATE "-framework CoreFoundation")
    target_link_libraries(webclient PRIVATE "-framework CoreFoundation")
endif()
