#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "Olm::Olm" for configuration "Release"
set_property(TARGET Olm::Olm APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(Olm::Olm PROPERTIES
  IMPORTED_IMPLIB_RELEASE "${_IMPORT_PREFIX}/lib/libolm.dll.a"
  )

list(APPEND _cmake_import_check_targets Olm::Olm )
list(APPEND _cmake_import_check_files_for_Olm::Olm "${_IMPORT_PREFIX}/lib/libolm.dll.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
