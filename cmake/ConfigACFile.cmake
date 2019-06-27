# Just as autoconf transforms file.in into file
# so configure_ac_file transforms CMAKE_CURRENT_SOURCE_DIR/file.in
# into CMAKE_CURRENT_BINARY_DIR/file

#This first copies with some replacement the file.in to cmk_file.in
#so that the normal cmake configure_file command works to make a proper
#cmk_file . Then that is compared to a possibly existing file and
#if different copies file_cmk to file. This prevent recompilation of
#.o files that depend on file.

macro(configure_ac_file file)
  set(bdir ${CMAKE_CURRENT_BINARY_DIR})
  execute_process(COMMAND sed "s/\#undef/\#cmakedefine/"
    INPUT_FILE ${CMAKE_CURRENT_SOURCE_DIR}/${file}.in
    OUTPUT_FILE ${bdir}/cmk_${file}.in)
  configure_file(${bdir}/cmk_${file}.in ${bdir}/cmk_${file})
  execute_process(COMMAND cmp ${bdir}/cmk_${file} ${bdir}/${file}
    RESULT_VARIABLE result)
  if (${result} EQUAL 0)
    file(REMOVE ${bdir}/cmk_${file})
    message(STATUS "${file} unchanged")
  else()
    file(RENAME ${bdir}/cmk_${file} ${bdir}/${file})
    message(STATUS "${file} updated")
  endif()
    file(REMOVE ${bdir}/cmk_${file}.in)
endmacro()

include(CheckIncludeFiles)
include(CheckFunctionExists)
include(CheckSymbolExists)
include(CheckCXXSymbolExists)

macro(have_dir HEADER VARIABLE)
  set(CONFTEST_DIR_TPL "  
  #include <sys/types.h>
  #include <@dir_hdr@>

  int main () {
    if ((DIR *) 0)
      return 0\;
    return 0\;
  }
  ")
  check_include_files(${HEADER} HAVE_HEADER)
  if (${HAVE_HEADER})
    file(REMOVE "conftest.c")
    string(REPLACE "@dir_hdr@" ${HEADER} CONFTEST_DIR "${CONFTEST_DIR_TPL}")
    file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/conftest.c ${CONFTEST_DIR})
    try_compile(RESULT_VAR ${CMAKE_CURRENT_SOURCE_DIR}
      ${CMAKE_CURRENT_SOURCE_DIR}/conftest.c)
    set(${VARIABLE} ${RESULT_VAR})
    message(STATUS "${VARIABLE}: ${RESULT_VAR}")
    file(REMOVE "conftest.c")
  endif()
endmacro()

macro(have_type HEADER TYPE DEFAULT_TYPE VARIABLE)
  set(CONFTEST_TYPE_TPL "
  #include <@hdr@>
  int main () {
    if (sizeof (@type@))
      return 0\;
    return 0\;
  }
  ")
  string(REPLACE "@hdr@" ${HEADER} CONFTEST_TYPE "${CONFTEST_TYPE_TPL}")
  string(REPLACE "@type@" ${TYPE} CONFTEST_TYPE "${CONFTEST_TYPE}")
  file(REMOVE "conftest.c")
  file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/conftest.c ${CONFTEST_TYPE})
  try_compile(RESULT_VAR ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/conftest.c)
  if(NOT ${RESULT_VAR})
    set(${VARIABLE} ${DEFAULT_TYPE})
  endif()
  message(STATUS "${VARIABLE}: ${RESULT_VAR}")
  #file(REMOVE "conftest.c")
endmacro()

macro(setretsigtype)
  set(CONFTEST_RETSIGTYPE "
    #include <sys/types.h>
    #include <signal.h>
    int main () {
      return *(signal (0, 0)) (0) == 1;
    }
  ")
  file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/conftest.c ${CONFTEST_RETSIGTYPE})
  try_compile(RESULT_VAR ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/conftest.c)
  if(${RESULT_VAR})
    set(RETSIGTYPE int)
  else()
    set(RETSIGTYPE void)
  endif()
endmacro()

# wrap check_include_files to create a INC_FILE_LIST of existing headers
macro(my_check_include_files name var)
  check_include_files(${name} ${var})
  if (${var})
    list(APPEND INC_FILE_LIST ${name})
  endif()
endmacro()

# wrap check_symbol_exists to use INC_FILE_LIST if ilist is empty
macro(my_check_symbol_exists name ilist var)
  string(COMPARE EQUAL "${ilist}" "" tmp)
  if (${tmp}) 
    check_symbol_exists("${name}" "${INC_FILE_LIST}" ${var})
  else()
    check_symbol_exists("${name}" "${ilist}" ${var})
  endif()
endmacro()

# sometimes, though it should have succeeded with cc, it fails but
# c++ succeeds
macro(my_check_cxx_symbol_exists name ilist var)
  string(COMPARE EQUAL "${ilist}" "" tmp)
  if (${tmp}) 
    CHECK_CXX_SYMBOL_EXISTS("${name}" "${INC_FILE_LIST}" ${var})
  else()
    CHECK_CXX_SYMBOL_EXISTS("${name}" "${ilist}" ${var})
  endif()
endmacro()

