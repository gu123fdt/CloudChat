# CMAKE generated file: DO NOT EDIT!
# Generated by "MinGW Makefiles" Generator, CMake Version 3.31

# Delete rule output on recipe failure.
.DELETE_ON_ERROR:

#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:

# Disable VCS-based implicit rules.
% : %,v

# Disable VCS-based implicit rules.
% : RCS/%

# Disable VCS-based implicit rules.
% : RCS/%,v

# Disable VCS-based implicit rules.
% : SCCS/s.%

# Disable VCS-based implicit rules.
% : s.%

.SUFFIXES: .hpux_make_needs_suffix_list

# Command-line flag to silence nested $(MAKE).
$(VERBOSE)MAKESILENT = -s

#Suppress display of executed commands.
$(VERBOSE).SILENT:

# A target that is always out of date.
cmake_force:
.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

SHELL = cmd.exe

# The CMake executable.
CMAKE_COMMAND = C:\msys64\mingw64\bin\cmake.exe

# The command to remove a file.
RM = C:\msys64\mingw64\bin\cmake.exe -E rm -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = E:\olm

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = E:\olm\build

# Include any dependencies generated for this target.
include tests/CMakeFiles/test_crypto.dir/depend.make
# Include any dependencies generated by the compiler for this target.
include tests/CMakeFiles/test_crypto.dir/compiler_depend.make

# Include the progress variables for this target.
include tests/CMakeFiles/test_crypto.dir/progress.make

# Include the compile flags for this target's objects.
include tests/CMakeFiles/test_crypto.dir/flags.make

tests/CMakeFiles/test_crypto.dir/codegen:
.PHONY : tests/CMakeFiles/test_crypto.dir/codegen

tests/CMakeFiles/test_crypto.dir/test_crypto.cpp.obj: tests/CMakeFiles/test_crypto.dir/flags.make
tests/CMakeFiles/test_crypto.dir/test_crypto.cpp.obj: tests/CMakeFiles/test_crypto.dir/includes_CXX.rsp
tests/CMakeFiles/test_crypto.dir/test_crypto.cpp.obj: E:/olm/tests/test_crypto.cpp
tests/CMakeFiles/test_crypto.dir/test_crypto.cpp.obj: tests/CMakeFiles/test_crypto.dir/compiler_depend.ts
	@$(CMAKE_COMMAND) -E cmake_echo_color "--switch=$(COLOR)" --green --progress-dir=E:\olm\build\CMakeFiles --progress-num=$(CMAKE_PROGRESS_1) "Building CXX object tests/CMakeFiles/test_crypto.dir/test_crypto.cpp.obj"
	cd /d E:\olm\build\tests && C:\msys64\mingw64\bin\c++.exe $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -MD -MT tests/CMakeFiles/test_crypto.dir/test_crypto.cpp.obj -MF CMakeFiles\test_crypto.dir\test_crypto.cpp.obj.d -o CMakeFiles\test_crypto.dir\test_crypto.cpp.obj -c E:\olm\tests\test_crypto.cpp

tests/CMakeFiles/test_crypto.dir/test_crypto.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color "--switch=$(COLOR)" --green "Preprocessing CXX source to CMakeFiles/test_crypto.dir/test_crypto.cpp.i"
	cd /d E:\olm\build\tests && C:\msys64\mingw64\bin\c++.exe $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E E:\olm\tests\test_crypto.cpp > CMakeFiles\test_crypto.dir\test_crypto.cpp.i

tests/CMakeFiles/test_crypto.dir/test_crypto.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color "--switch=$(COLOR)" --green "Compiling CXX source to assembly CMakeFiles/test_crypto.dir/test_crypto.cpp.s"
	cd /d E:\olm\build\tests && C:\msys64\mingw64\bin\c++.exe $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S E:\olm\tests\test_crypto.cpp -o CMakeFiles\test_crypto.dir\test_crypto.cpp.s

# Object files for target test_crypto
test_crypto_OBJECTS = \
"CMakeFiles/test_crypto.dir/test_crypto.cpp.obj"

# External object files for target test_crypto
test_crypto_EXTERNAL_OBJECTS =

tests/test_crypto.exe: tests/CMakeFiles/test_crypto.dir/test_crypto.cpp.obj
tests/test_crypto.exe: tests/CMakeFiles/test_crypto.dir/build.make
tests/test_crypto.exe: libolm.dll.a
tests/test_crypto.exe: tests/CMakeFiles/test_crypto.dir/linkLibs.rsp
tests/test_crypto.exe: tests/CMakeFiles/test_crypto.dir/objects1.rsp
tests/test_crypto.exe: tests/CMakeFiles/test_crypto.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color "--switch=$(COLOR)" --green --bold --progress-dir=E:\olm\build\CMakeFiles --progress-num=$(CMAKE_PROGRESS_2) "Linking CXX executable test_crypto.exe"
	cd /d E:\olm\build\tests && $(CMAKE_COMMAND) -E cmake_link_script CMakeFiles\test_crypto.dir\link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
tests/CMakeFiles/test_crypto.dir/build: tests/test_crypto.exe
.PHONY : tests/CMakeFiles/test_crypto.dir/build

tests/CMakeFiles/test_crypto.dir/clean:
	cd /d E:\olm\build\tests && $(CMAKE_COMMAND) -P CMakeFiles\test_crypto.dir\cmake_clean.cmake
.PHONY : tests/CMakeFiles/test_crypto.dir/clean

tests/CMakeFiles/test_crypto.dir/depend:
	$(CMAKE_COMMAND) -E cmake_depends "MinGW Makefiles" E:\olm E:\olm\tests E:\olm\build E:\olm\build\tests E:\olm\build\tests\CMakeFiles\test_crypto.dir\DependInfo.cmake "--color=$(COLOR)"
.PHONY : tests/CMakeFiles/test_crypto.dir/depend

