cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "native_audio_engine")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "native_audio_engine_plugin")

list(APPEND PLUGIN_SOURCES
  "native_audio_engine_plugin.cpp"
  "native_audio_engine_plugin.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/live_mixer.cpp"
)

add_library(${PLUGIN_NAME} SHARED
  "include/native_audio_engine/native_audio_engine_plugin_c_api.h"
  "native_audio_engine_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../src"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

if(WIN32)
  target_link_libraries(${PLUGIN_NAME} PRIVATE mfreadwrite mfplat mfuuid ole32)
endif()

set(native_audio_engine_bundled_libraries
  ""
  PARENT_SCOPE
)
