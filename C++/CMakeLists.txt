cmake_minimum_required (VERSION 2.8)
project (PiGPS)

#version number
set (PiGPS_VERSION_MAJOR 1)
set (PiGPS_VERSION_MINOR 0)

set (SOURCE_FILES main.cpp peri.cpp channel.cpp coroutines.cpp ephemeris.cpp search.cpp solve.cpp spi.cpp user.cpp)

#include the subdirectory containing our libs
#add_subdirectory (.)
include_directories("${CMAKE_SOURCE_DIR}")
#indicate the entry point for the executable
add_executable (PiGPS channel.cpp  coroutines.cpp  ephemeris.cpp  main.cpp  peri.cpp  search.cpp  solve.cpp  spi.cpp  user.cpp)

SET(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -ggdb")

# Indicate which libraries to include during the link process.
#target_link_libraries (PiGPS main)
target_link_libraries(PiGPS -lfftw3 -lfftw3f)

#install (TARGETS PiGPS DESTINATION bin)
