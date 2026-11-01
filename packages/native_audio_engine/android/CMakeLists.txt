cmake_minimum_required(VERSION 3.4.1)

project(native_audio_engine_plugin)

# --- AUDIO DSP OPTIMIZATIONS ---
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -ffast-math -fomit-frame-pointer")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -ffast-math -fomit-frame-pointer")

add_library(native_audio_engine_plugin SHARED
    "${CMAKE_CURRENT_SOURCE_DIR}/../src/live_mixer.cpp"
)

include_directories(
    "${CMAKE_CURRENT_SOURCE_DIR}/../src"
)

find_library(log-lib log)

target_link_libraries(native_audio_engine_plugin ${log-lib})
