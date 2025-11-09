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

# Common dependencies and include directories
set(COMMON_LIBS uv_a llhttp)
set(COMMON_INCLUDES
    ${CMAKE_CURRENT_SOURCE_DIR}/deps/libuv/include
    ${CMAKE_CURRENT_SOURCE_DIR}/deps/llhttp/include
)

# Helper function to create executables with common settings
function(add_uv_executable target_name source_file)
    add_executable(${target_name} ${source_file})
    target_link_libraries(${target_name} PRIVATE ${COMMON_LIBS})
    target_include_directories(${target_name} PRIVATE ${COMMON_INCLUDES})

    # macOS specific - CoreFoundation needed for debugging tools like Instruments
    if(APPLE)
        target_link_libraries(${target_name} PRIVATE "-framework CoreFoundation")
    endif()
endfunction()

# Create executables
add_uv_executable(webserver webserver.cc)
add_uv_executable(webclient webclient.cc)
