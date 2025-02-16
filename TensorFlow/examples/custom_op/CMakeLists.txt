###############################################################################
# Copyright (C) 2020-2023 Habana Labs, Ltd. an Intel Company
###############################################################################
cmake_minimum_required(VERSION 3.10)

project(HpuCustomDivOp)

list(APPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR})

set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choosing default build type: Release.")

function(run_py3 CMD_TO_RUN OUT_VAR)
  execute_process(
    COMMAND python3 -c "${CMD_TO_RUN}"
    OUTPUT_VARIABLE CMD_RESULT
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE retcode)
  if(NOT "${retcode}" STREQUAL "0")
    message(FATAL_ERROR "Running python command failed. Command: ${CMD_TO_RUN}")
  endif()
  set(${OUT_VAR} ${CMD_RESULT} PARENT_SCOPE)
endfunction()

if (TF_FOUND)
  message(STATUS "Reuse cached information from TensorFlow ${TF_VERSION}.")
else()
  # Let's print installed TF version
  run_py3("import tensorflow as tf; print(tf.__version__)" TF_VERSION)
  message(STATUS "Found TensorFlow ${TF_VERSION}")

  # Getting Compiler and Linker flags in the way described in https://www.tensorflow.org/guide/create_op
  run_py3("import tensorflow as tf; \
           print(','.join(tf.sysconfig.get_compile_flags())); \
           print(' '.join(tf.sysconfig.get_link_flags()))"
           TF_INFORMATION_STRING)
  string(REPLACE "\n" ";" TF_INFORMATION_LIST ${TF_INFORMATION_STRING})
  list(GET TF_INFORMATION_LIST 0 TF_COMPILE_FALGS)
  string(REPLACE "," ";" TF_COMPILE_FALGS ${TF_COMPILE_FALGS})
  list(GET TF_INFORMATION_LIST 1 TF_LINK_FALGS)
  set(TF_FOUND TRUE)
endif()

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
if(DEFINED USE_CUSTOM_KERNEL)
  add_definitions(-DUSE_CUSTOM_KERNEL=${USE_CUSTOM_KERNEL})
endif()

add_library(hpu_custom_div_op SHARED hpu_custom_div_op.cpp)

# Get Habana-specific information
run_py3("import habana_frameworks.tensorflow as htf; \
          print(htf.sysconfig.get_include_dir()); \
          print(','.join(htf.sysconfig.get_compile_flags())); \
          print(' '.join(htf.sysconfig.get_link_flags()))"
          HTF_INFORMATION_STRING)
string(REPLACE "\n" ";" HTF_INFORMATION_LIST ${HTF_INFORMATION_STRING})
list(GET HTF_INFORMATION_LIST 0 HTF_INCLUDE_DIR)
list(GET HTF_INFORMATION_LIST 1 HTF_COMPILE_FLAGS)
string(REPLACE "," ";" HTF_COMPILE_FLAGS ${HTF_COMPILE_FLAGS})
list(GET HTF_INFORMATION_LIST 2 HTF_LINK_FLAGS)

target_include_directories(hpu_custom_div_op PUBLIC ${HTF_INCLUDE_DIR})

if (TF_VERSION MATCHES "^2\.13\.*")
    target_include_directories(hpu_custom_div_op PRIVATE tf_ver/2.13.0)
else()
    target_include_directories(hpu_custom_div_op PRIVATE tf_ver/common)
endif()

target_compile_options(hpu_custom_div_op PUBLIC ${TF_COMPILE_FALGS} ${HTF_COMPILE_FLAGS})
target_link_libraries(hpu_custom_div_op PUBLIC ${TF_LINK_FALGS} ${HTF_LINK_FLAGS})
add_definitions(-DINCLUDE_FROM_WHEEL=1)

set(TF_VERSION ${TF_VERSION} CACHE STRING "Version of TF")
set(TF_COMPILE_FALGS ${TF_COMPILE_FALGS} CACHE STRING "Set of TF compiler flags")
set(TF_LINK_FALGS ${TF_LINK_FALGS} CACHE STRING "Set of TF linker flags")
set(TF_FOUND ${TF_FOUND} CACHE BOOL "If false, do not try to use TENSORFLOW")
if (TF_VERSION MATCHES "^2\.8\.*" OR TF_VERSION MATCHES "^2\.9\.*")
    set_target_properties(hpu_custom_div_op PROPERTIES CXX_STANDARD 14 CXX_STANDARD_REQUIRED ON)
else()
    set_target_properties(hpu_custom_div_op PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
endif()
