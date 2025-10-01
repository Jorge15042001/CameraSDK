include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(CameraSDK_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(CameraSDK_setup_options)
  option(CameraSDK_ENABLE_HARDENING "Enable hardening" ON)
  option(CameraSDK_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    CameraSDK_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    CameraSDK_ENABLE_HARDENING
    OFF)

  CameraSDK_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR CameraSDK_PACKAGING_MAINTAINER_MODE)
    option(CameraSDK_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(CameraSDK_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(CameraSDK_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(CameraSDK_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(CameraSDK_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(CameraSDK_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(CameraSDK_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(CameraSDK_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(CameraSDK_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(CameraSDK_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(CameraSDK_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(CameraSDK_ENABLE_PCH "Enable precompiled headers" OFF)
    option(CameraSDK_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(CameraSDK_ENABLE_IPO "Enable IPO/LTO" ON)
    option(CameraSDK_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(CameraSDK_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(CameraSDK_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(CameraSDK_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(CameraSDK_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(CameraSDK_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(CameraSDK_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(CameraSDK_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(CameraSDK_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(CameraSDK_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(CameraSDK_ENABLE_PCH "Enable precompiled headers" OFF)
    option(CameraSDK_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      CameraSDK_ENABLE_IPO
      CameraSDK_WARNINGS_AS_ERRORS
      CameraSDK_ENABLE_USER_LINKER
      CameraSDK_ENABLE_SANITIZER_ADDRESS
      CameraSDK_ENABLE_SANITIZER_LEAK
      CameraSDK_ENABLE_SANITIZER_UNDEFINED
      CameraSDK_ENABLE_SANITIZER_THREAD
      CameraSDK_ENABLE_SANITIZER_MEMORY
      CameraSDK_ENABLE_UNITY_BUILD
      CameraSDK_ENABLE_CLANG_TIDY
      CameraSDK_ENABLE_CPPCHECK
      CameraSDK_ENABLE_COVERAGE
      CameraSDK_ENABLE_PCH
      CameraSDK_ENABLE_CACHE)
  endif()

  CameraSDK_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (CameraSDK_ENABLE_SANITIZER_ADDRESS OR CameraSDK_ENABLE_SANITIZER_THREAD OR CameraSDK_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(CameraSDK_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(CameraSDK_global_options)
  if(CameraSDK_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    CameraSDK_enable_ipo()
  endif()

  CameraSDK_supports_sanitizers()

  if(CameraSDK_ENABLE_HARDENING AND CameraSDK_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR CameraSDK_ENABLE_SANITIZER_UNDEFINED
       OR CameraSDK_ENABLE_SANITIZER_ADDRESS
       OR CameraSDK_ENABLE_SANITIZER_THREAD
       OR CameraSDK_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${CameraSDK_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${CameraSDK_ENABLE_SANITIZER_UNDEFINED}")
    CameraSDK_enable_hardening(CameraSDK_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(CameraSDK_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(CameraSDK_warnings INTERFACE)
  add_library(CameraSDK_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  CameraSDK_set_project_warnings(
    CameraSDK_warnings
    ${CameraSDK_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(CameraSDK_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    CameraSDK_configure_linker(CameraSDK_options)
  endif()

  include(cmake/Sanitizers.cmake)
  CameraSDK_enable_sanitizers(
    CameraSDK_options
    ${CameraSDK_ENABLE_SANITIZER_ADDRESS}
    ${CameraSDK_ENABLE_SANITIZER_LEAK}
    ${CameraSDK_ENABLE_SANITIZER_UNDEFINED}
    ${CameraSDK_ENABLE_SANITIZER_THREAD}
    ${CameraSDK_ENABLE_SANITIZER_MEMORY})

  set_target_properties(CameraSDK_options PROPERTIES UNITY_BUILD ${CameraSDK_ENABLE_UNITY_BUILD})

  if(CameraSDK_ENABLE_PCH)
    target_precompile_headers(
      CameraSDK_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(CameraSDK_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    CameraSDK_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(CameraSDK_ENABLE_CLANG_TIDY)
    CameraSDK_enable_clang_tidy(CameraSDK_options ${CameraSDK_WARNINGS_AS_ERRORS})
  endif()

  if(CameraSDK_ENABLE_CPPCHECK)
    CameraSDK_enable_cppcheck(${CameraSDK_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(CameraSDK_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    CameraSDK_enable_coverage(CameraSDK_options)
  endif()

  if(CameraSDK_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(CameraSDK_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(CameraSDK_ENABLE_HARDENING AND NOT CameraSDK_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR CameraSDK_ENABLE_SANITIZER_UNDEFINED
       OR CameraSDK_ENABLE_SANITIZER_ADDRESS
       OR CameraSDK_ENABLE_SANITIZER_THREAD
       OR CameraSDK_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    CameraSDK_enable_hardening(CameraSDK_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
