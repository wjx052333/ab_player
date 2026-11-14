cmake_minimum_required(VERSION 3.10)
project(speexdec C)

# 只编译解码用到的 libspeex (浮点版)，对外只导出 spx_decode_ogg / spx_free_pcm
file(GLOB SPEEX_SRC ${CMAKE_CURRENT_SOURCE_DIR}/speex/libspeex/*.c)

add_library(speexdec SHARED speex_decode.c ${SPEEX_SRC})

target_include_directories(speexdec PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/speex/include
  ${CMAKE_CURRENT_SOURCE_DIR}/speex/libspeex)

target_compile_definitions(speexdec PRIVATE
  FLOATING_POINT
  USE_SMALLFT
  EXPORT=
  VAR_ARRAYS)

target_compile_options(speexdec PRIVATE -O2 -w)

# Android 15 要求 16KB 页对齐
target_link_options(speexdec PRIVATE -Wl,-z,max-page-size=16384)
