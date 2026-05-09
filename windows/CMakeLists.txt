# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(flutter_application_1 LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "flutter_application_1")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# Finds ATL/MFC paths for plugins whose CMake files do not request them.
function(RESOLVE_VISUAL_STUDIO_ATL_PATHS OUT_INCLUDE_VAR OUT_LIBRARY_VAR)
  set(ATL_INSTALLATION_ROOTS)

  if(CMAKE_GENERATOR_INSTANCE)
    list(APPEND ATL_INSTALLATION_ROOTS "${CMAKE_GENERATOR_INSTANCE}")
  endif()

  if(DEFINED ENV{VSINSTALLDIR})
    list(APPEND ATL_INSTALLATION_ROOTS "$ENV{VSINSTALLDIR}")
  endif()

  set(VSWHERE_PATH
    "$ENV{ProgramFiles\(x86\)}/Microsoft Visual Studio/Installer/vswhere.exe")
  if(EXISTS "${VSWHERE_PATH}")
    execute_process(
      COMMAND
        "${VSWHERE_PATH}"
        -products *
        -requires Microsoft.VisualStudio.Component.VC.ATL
        -property installationPath
      OUTPUT_VARIABLE ATL_INSTALLATION_OUTPUT
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    string(REPLACE "\n" ";" ATL_VSWHERE_ROOTS "${ATL_INSTALLATION_OUTPUT}")
    list(APPEND ATL_INSTALLATION_ROOTS ${ATL_VSWHERE_ROOTS})
  endif()

  foreach(ATL_ROOT IN LISTS ATL_INSTALLATION_ROOTS)
    file(GLOB ATL_INCLUDE_DIRS LIST_DIRECTORIES true
      "${ATL_ROOT}/VC/Tools/MSVC/*/atlmfc/include")
    list(SORT ATL_INCLUDE_DIRS)
    list(REVERSE ATL_INCLUDE_DIRS)

    foreach(ATL_INCLUDE_DIR IN LISTS ATL_INCLUDE_DIRS)
      get_filename_component(ATL_ATLMFC_DIR "${ATL_INCLUDE_DIR}" DIRECTORY)
      set(ATL_LIBRARY_DIR "${ATL_ATLMFC_DIR}/lib/${CMAKE_VS_PLATFORM_NAME}")

      if(CMAKE_VS_PLATFORM_NAME STREQUAL "Win32")
        set(ATL_LIBRARY_DIR "${ATL_ATLMFC_DIR}/lib/x86")
      endif()

      if(EXISTS "${ATL_INCLUDE_DIR}/atlstr.h"
          AND EXISTS "${ATL_LIBRARY_DIR}/atls.lib")
        set(${OUT_INCLUDE_VAR} "${ATL_INCLUDE_DIR}" PARENT_SCOPE)
        set(${OUT_LIBRARY_VAR} "${ATL_LIBRARY_DIR}" PARENT_SCOPE)
        return()
      endif()
    endforeach()
  endforeach()

  set(${OUT_INCLUDE_VAR} "" PARENT_SCOPE)
  set(${OUT_LIBRARY_VAR} "" PARENT_SCOPE)
endfunction()

if(WIN32 AND MSVC AND TARGET flutter_secure_storage_windows_plugin)
  RESOLVE_VISUAL_STUDIO_ATL_PATHS(
    SECURE_STORAGE_ATL_INCLUDE_DIR
    SECURE_STORAGE_ATL_LIBRARY_DIR)

  if(SECURE_STORAGE_ATL_INCLUDE_DIR AND SECURE_STORAGE_ATL_LIBRARY_DIR)
    target_include_directories(flutter_secure_storage_windows_plugin
      PRIVATE "${SECURE_STORAGE_ATL_INCLUDE_DIR}")
    target_link_directories(flutter_secure_storage_windows_plugin
      PRIVATE "${SECURE_STORAGE_ATL_LIBRARY_DIR}")
  else()
    message(FATAL_ERROR
      "flutter_secure_storage_windows benoetigt ATL/MFC-Header und "
      "Bibliotheken. Installiere die Visual-Studio-Komponente 'C++ ATL/MFC'.")
  endif()
endif()


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
