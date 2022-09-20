cmake_minimum_required(VERSION 3.24)

# Because we declare this very early, it will take precedence over any
# details the project might declare later for the same thing
include(FetchContent)
FetchContent_Declare(
  googletest
  GIT_REPOSITORY https://github.com/google/googletest.git
  GIT_TAG e2239ee6043f73722e7aa812a459f54a28552929 # release-1.11.0
)

# Both FIND_PACKAGE and FETCHCONTENT_MAKEAVAILABLE_SERIAL methods provide
# the package or dependency name as the first method-specific argument.
macro(mycomp_provide_dependency method dep_name)
  if("${dep_name}" MATCHES "^(gtest|googletest)$")
    # Save our current command arguments in case we are called recursively
    list(
      APPEND
      mycomp_provider_args
      ${method}
      ${dep_name})

    # This will forward to the built-in FetchContent implementation,
    # which detects a recursive call for the same thing and avoids calling
    # the provider again if dep_name is the same as the current call.
    FetchContent_MakeAvailable(googletest)

    # Restore our command arguments
    list(
      POP_BACK
      mycomp_provider_args
      dep_name
      method)

    # Tell the caller we fulfilled the request
    if("${method}" STREQUAL "FIND_PACKAGE")
      # We need to set this if we got here from a find_package() call
      # since we used a different method to fulfill the request.
      # This example assumes projects only use the gtest targets,
      # not any of the variables the FindGTest module may define.
      set(${dep_name}_FOUND TRUE)
    elseif(
      NOT
      "${dep_name}"
      STREQUAL
      "googletest")
      # We used the same method, but were given a different name to the
      # one we populated with. Tell the caller about the name it used.
      fetchcontent_setpopulated(
        ${dep_name}
        SOURCE_DIR
        "${googletest_SOURCE_DIR}"
        BINARY_DIR
        "${googletest_BINARY_DIR}")
    endif()
  else()
    message(WARNING "${method} ${dep_name} used")
  endif()
endmacro()

cmake_language(
  SET_DEPENDENCY_PROVIDER
  mycomp_provide_dependency
  SUPPORTED_METHODS
  FIND_PACKAGE
  FETCHCONTENT_MAKEAVAILABLE_SERIAL)
