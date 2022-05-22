include_guard()

include("${ProjectOptions_SRC_DIR}/Utilities.cmake")

function(is_msvc value)
  if(# if the user has specified cl using -DCMAKE_CXX_COMPILER=cl and -DCMAKE_C_COMPILER=cl
     (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" AND CMAKE_C_COMPILER_ID STREQUAL "MSVC")
     OR (CMAKE_CXX_COMPILER MATCHES "^cl(.exe)?$" AND CMAKE_C_COMPILER MATCHES "^cl(.exe)?$")
        # if the user has specified cl using CC and CXX but not using -DCMAKE_CXX_COMPILER and -DCMAKE_C_COMPILER
     OR (NOT CMAKE_CXX_COMPILER
         AND NOT CMAKE_C_COMPILER
         AND ("$ENV{CXX}" MATCHES "^cl(.exe)?$" AND "$ENV{CC}" MATCHES "^cl(.exe)?$")))
    set(${value}
        ON
        PARENT_SCOPE)
    return()
  endif()

  include("${ProjectOptions_SRC_DIR}/DetectCompiler.cmake")
  detect_compiler()

  if((DETECTED_CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" AND DETECTED_CMAKE_C_COMPILER_ID STREQUAL "MSVC"))
    set(${value}
        ON
        PARENT_SCOPE)
    return()
  endif()

  set(${value}
      OFF
      PARENT_SCOPE)
endfunction()

# Include msvc toolchain on windows if the generator is not visual studio. Should be called before run_vcpkg and run_conan to be effective
macro(msvc_toolchain)
  if(# if on windows and the generator is not Visual Studio
     WIN32
     AND NOT
         CMAKE_GENERATOR
         MATCHES
         "Visual Studio*")
    is_msvc(_is_msvc)
    if(${_is_msvc})
      # if msvc
      message(STATUS "Using Windows MSVC toolchain")
      include(FetchContent)
      FetchContent_Declare(
        _msvc_toolchain URL "https://github.com/aminya/Toolchain/archive/95891a1e28a406ffb22e572f3ef24a7a8ad27ec0.zip")
      FetchContent_MakeAvailable(_msvc_toolchain)
      include("${_msvc_toolchain_SOURCE_DIR}/Windows.MSVC.toolchain.cmake")
      message(STATUS "Setting CXX/C compiler to ${CMAKE_CXX_COMPILER}")
      set(ENV{CXX} ${CMAKE_CXX_COMPILER})
      set(ENV{CC} ${CMAKE_C_COMPILER})
      set(MSVC_FOUND TRUE)
      run_vcvarsall()
    endif()
  endif()
endmacro()

# Run vcvarsall.bat and set CMake environment variables
macro(run_vcvarsall)
  # detect the architecture
  detect_architecture(VCVARSALL_ARCH)

  # If MSVC is being used, and ASAN is enabled, we need to set the debugger environment
  # so that it behaves well with MSVC's debugger, and we can run the target from visual studio
  if(MSVC)
    string(TOUPPER "${VCVARSALL_ARCH}" VCVARSALL_ARCH_UPPER)
    set(VS_DEBUGGER_ENVIRONMENT "PATH=\$(VC_ExecutablePath_${VCVARSALL_ARCH_UPPER});%PATH%")

    get_all_targets(all_targets)
    set_target_properties(${all_targets} PROPERTIES VS_DEBUGGER_ENVIRONMENT "${VS_DEBUGGER_ENVIRONMENT}")
  endif()

  # if msvc_found is set by msvc_toolchain
  # or if MSVC but VSCMD_VER is not set, which means vcvarsall has not run
  if(MSVC_FOUND OR (MSVC AND "$ENV{VSCMD_VER}" STREQUAL ""))

    # find vcvarsall.bat
    get_filename_component(MSVC_DIR ${CMAKE_CXX_COMPILER} DIRECTORY)
    find_file(
      VCVARSALL_FILE
      NAMES vcvarsall.bat
      PATHS "${MSVC_DIR}"
            "${MSVC_DIR}/.."
            "${MSVC_DIR}/../.."
            "${MSVC_DIR}/../../../../../../../.."
            "${MSVC_DIR}/../../../../../../.."
      PATH_SUFFIXES "VC/Auxiliary/Build" "Common7/Tools" "Tools")

    if(EXISTS ${VCVARSALL_FILE})
      # run vcvarsall and print the environment variables
      message(STATUS "Running `${VCVARSALL_FILE} ${VCVARSALL_ARCH}` to set up the MSVC environment")
      execute_process(
        COMMAND
          "cmd" "/c" ${VCVARSALL_FILE} ${VCVARSALL_ARCH} #
          "&&" "call" "echo" "VCVARSALL_ENV_START" #
          "&" "set" #
        OUTPUT_VARIABLE VCVARSALL_OUTPUT
        OUTPUT_STRIP_TRAILING_WHITESPACE)

      # parse the output and get the environment variables string
      find_substring_by_prefix(VCVARSALL_ENV "VCVARSALL_ENV_START" "${VCVARSALL_OUTPUT}")

      # set the environment variables
      set_env_from_string("${VCVARSALL_ENV}")
    else()
      message(
        WARNING
          "Could not find `vcvarsall.bat` for automatic MSVC environment preparation. Please manually open the MSVC command prompt and rebuild the project.
      ")
    endif()
  endif()
endmacro()
