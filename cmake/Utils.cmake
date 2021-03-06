################################################################################################
# Exclude and prepend functionalities
function (exclude OUTPUT INPUT)
set(EXCLUDES ${ARGN})
foreach(EXCLUDE ${EXCLUDES})
        list(REMOVE_ITEM INPUT "${EXCLUDE}")
endforeach()
set(${OUTPUT} ${INPUT} PARENT_SCOPE)
endfunction(exclude)

function (prepend OUTPUT PREPEND)
set(OUT "")
foreach(ITEM ${ARGN})
        list(APPEND OUT "${PREPEND}${ITEM}")
endforeach()
set(${OUTPUT} ${OUT} PARENT_SCOPE)
endfunction(prepend)


################################################################################################
# Clears variables from list
# Usage:
#   caffe_clear_vars(<variables_list>)
macro(caffe_clear_vars)
  foreach(_var ${ARGN})
    unset(${_var})
  endforeach()
endmacro()

################################################################################################
# Prints list element per line
# Usage:
#   caffe_print_list(<list>)
function(caffe_print_list)
  foreach(e ${ARGN})
    message(STATUS ${e})
  endforeach()
endfunction()

################################################################################################
# Reads set of version defines from the header file
# Usage:
#   caffe_parse_header(<file> <define1> <define2> <define3> ..)
macro(caffe_parse_header FILENAME FILE_VAR)
  set(vars_regex "")
  set(__parnet_scope OFF)
  set(__add_cache OFF)
  foreach(name ${ARGN})
    if("${name}" STREQUAL "PARENT_SCOPE")
      set(__parnet_scope ON)
    elseif("${name}" STREQUAL "CACHE")
      set(__add_cache ON)
    elseif(vars_regex)
      set(vars_regex "${vars_regex}|${name}")
    else()
      set(vars_regex "${name}")
    endif()
  endforeach()
  if(EXISTS "${FILENAME}")
    file(STRINGS "${FILENAME}" ${FILE_VAR} REGEX "#define[ \t]+(${vars_regex})[ \t]+[0-9]+" )
  else()
    unset(${FILE_VAR})
  endif()
  foreach(name ${ARGN})
    if(NOT "${name}" STREQUAL "PARENT_SCOPE" AND NOT "${name}" STREQUAL "CACHE")
      if(${FILE_VAR})
        if(${FILE_VAR} MATCHES ".+[ \t]${name}[ \t]+([0-9]+).*")
          string(REGEX REPLACE ".+[ \t]${name}[ \t]+([0-9]+).*" "\\1" ${name} "${${FILE_VAR}}")
        else()
          set(${name} "")
        endif()
        if(__add_cache)
          set(${name} ${${name}} CACHE INTERNAL "${name} parsed from ${FILENAME}" FORCE)
        elseif(__parnet_scope)
          set(${name} "${${name}}" PARENT_SCOPE)
        endif()
      else()
        unset(${name} CACHE)
      endif()
    endif()
  endforeach()
endmacro()

################################################################################################
# Reads single version define from the header file and parses it
# Usage:
#   caffe_parse_header_single_define(<library_name> <file> <define_name>)
function(caffe_parse_header_single_define LIBNAME HDR_PATH VARNAME)
  set(${LIBNAME}_H "")
  if(EXISTS "${HDR_PATH}")
    file(STRINGS "${HDR_PATH}" ${LIBNAME}_H REGEX "^#define[ \t]+${VARNAME}[ \t]+\"[^\"]*\".*$" LIMIT_COUNT 1)
  endif()

  if(${LIBNAME}_H)
    string(REGEX REPLACE "^.*[ \t]${VARNAME}[ \t]+\"([0-9]+).*$" "\\1" ${LIBNAME}_VERSION_MAJOR "${${LIBNAME}_H}")
    string(REGEX REPLACE "^.*[ \t]${VARNAME}[ \t]+\"[0-9]+\\.([0-9]+).*$" "\\1" ${LIBNAME}_VERSION_MINOR  "${${LIBNAME}_H}")
    string(REGEX REPLACE "^.*[ \t]${VARNAME}[ \t]+\"[0-9]+\\.[0-9]+\\.([0-9]+).*$" "\\1" ${LIBNAME}_VERSION_PATCH "${${LIBNAME}_H}")
    set(${LIBNAME}_VERSION_MAJOR ${${LIBNAME}_VERSION_MAJOR} ${ARGN} PARENT_SCOPE)
    set(${LIBNAME}_VERSION_MINOR ${${LIBNAME}_VERSION_MINOR} ${ARGN} PARENT_SCOPE)
    set(${LIBNAME}_VERSION_PATCH ${${LIBNAME}_VERSION_PATCH} ${ARGN} PARENT_SCOPE)
    set(${LIBNAME}_VERSION_STRING "${${LIBNAME}_VERSION_MAJOR}.${${LIBNAME}_VERSION_MINOR}.${${LIBNAME}_VERSION_PATCH}" PARENT_SCOPE)

    # append a TWEAK version if it exists:
    set(${LIBNAME}_VERSION_TWEAK "")
    if("${${LIBNAME}_H}" MATCHES "^.*[ \t]${VARNAME}[ \t]+\"[0-9]+\\.[0-9]+\\.[0-9]+\\.([0-9]+).*$")
      set(${LIBNAME}_VERSION_TWEAK "${CMAKE_MATCH_1}" ${ARGN} PARENT_SCOPE)
    endif()
    if(${LIBNAME}_VERSION_TWEAK)
      set(${LIBNAME}_VERSION_STRING "${${LIBNAME}_VERSION_STRING}.${${LIBNAME}_VERSION_TWEAK}" ${ARGN} PARENT_SCOPE)
    else()
      set(${LIBNAME}_VERSION_STRING "${${LIBNAME}_VERSION_STRING}" ${ARGN} PARENT_SCOPE)
    endif()
  endif()
endfunction()

##############################################################################
# Helper function to automatically generate __init__.py files where python
# sources reside but there are no __init__.py present.
function(caffe_autogen_init_py_files)
  if (CAFFE2_AUTOGEN_INIT_PY_ALREADY_RUN)
    message(STATUS
        "A previous caffe2 cmake run already created the __init__.py files.")
    return()
  endif()
  file(GLOB_RECURSE all_python_files RELATIVE ${PROJECT_SOURCE_DIR}
       "${PROJECT_SOURCE_DIR}/caffe2/*.py")
  set(python_paths_need_init_py)
  foreach(python_file ${all_python_files})
    get_filename_component(python_path ${python_file} PATH)
    string(REPLACE "/" ";" path_parts ${python_path})
    set(rebuilt_path ${CMAKE_BINARY_DIR})
    foreach(path_part ${path_parts})
      set(rebuilt_path "${rebuilt_path}/${path_part}")
      list(APPEND python_paths_need_init_py ${rebuilt_path})
    endforeach()
  endforeach()
  list(REMOVE_DUPLICATES python_paths_need_init_py)
  # Since the _pb2.py files are yet to be created, we will need to manually
  # add them to the list.
  list(APPEND python_paths_need_init_py ${CMAKE_BINARY_DIR}/caffe)
  list(APPEND python_paths_need_init_py ${CMAKE_BINARY_DIR}/caffe/proto)
  list(APPEND python_paths_need_init_py ${CMAKE_BINARY_DIR}/caffe2/proto)

  foreach(tmp ${python_paths_need_init_py})
    if(NOT EXISTS ${tmp}/__init__.py)
      # message(STATUS "Generate " ${tmp}/__init__.py)
      file(WRITE ${tmp}/__init__.py "")
    endif()
  endforeach()
  set(CAFFE2_AUTOGEN_INIT_PY_ALREADY_RUN TRUE CACHE INTERNAL
      "Helper variable to record if autogen_init_py is already run or not.")
endfunction()

###
# Removes common indentation from a block of text to produce code suitable for
# setting to `python -c`, or using with pycmd. This allows multiline code to be
# nested nicely in the surrounding code structure.
#
# This function respsects PYTHON_EXECUTABLE if it defined, otherwise it uses
# `python` and hopes for the best. An error will be thrown if it is not found.
#
# Args:
#     outvar : variable that will hold the stdout of the python command
#     text   : text to remove indentation from
#
function(dedent outvar text)
  # Use PYTHON_EXECUTABLE if it is defined, otherwise default to python
  if ("${PYTHON_EXECUTABLE}" STREQUAL "")
    set(_python_exe "python")
  else()
    set(_python_exe "${PYTHON_EXECUTABLE}")
  endif()
  set(_fixup_cmd "import sys; from textwrap import dedent; print(dedent(sys.stdin.read()))")
  file(WRITE "${CMAKE_BINARY_DIR}/indented.txt" "${text}")
  execute_process(
    COMMAND "${_python_exe}" -c "${_fixup_cmd}"
    INPUT_FILE "${CMAKE_BINARY_DIR}/indented.txt"
    RESULT_VARIABLE _dedent_exitcode
    OUTPUT_VARIABLE _dedent_text)
  if(NOT ${_dedent_exitcode} EQUAL 0)
    message(ERROR " Failed to remove indentation from: \n\"\"\"\n${text}\n\"\"\"
    Python dedent failed with error code: ${_dedent_exitcode}")
    message(FATAL_ERROR " Python dedent failed with error code: ${_dedent_exitcode}")
  endif()
  # Remove supurflous newlines (artifacts of print)
  string(STRIP "${_dedent_text}" _dedent_text)
  set(${outvar} "${_dedent_text}" PARENT_SCOPE)
endfunction()


###
# Helper function to run `python -c "<cmd>"` and capture the results of stdout
#
# Runs a python command and populates an outvar with the result of stdout.
# Common indentation in the text of `cmd` is removed before the command is
# executed, so the caller does not need to worry about indentation issues.
#
# This function respsects PYTHON_EXECUTABLE if it defined, otherwise it uses
# `python` and hopes for the best. An error will be thrown if it is not found.
#
# Args:
#     outvar : variable that will hold the stdout of the python command
#     cmd    : text representing a (possibly multiline) block of python code
#
function(pycmd outvar cmd)
  dedent(_dedent_cmd "${cmd}")
  # Use PYTHON_EXECUTABLE if it is defined, otherwise default to python
  if ("${PYTHON_EXECUTABLE}" STREQUAL "")
    set(_python_exe "python")
  else()
    set(_python_exe "${PYTHON_EXECUTABLE}")
  endif()
  # run the actual command
  execute_process(
    COMMAND "${_python_exe}" -c "${_dedent_cmd}"
    RESULT_VARIABLE _exitcode
    OUTPUT_VARIABLE _output)
  if(NOT ${_exitcode} EQUAL 0)
    message(ERROR " Failed when running python code: \"\"\"\n${_dedent_cmd}\n\"\"\"")
    message(FATAL_ERROR " Python command failed with error code: ${_exitcode}")
  endif()
  # Remove supurflous newlines (artifacts of print)
  string(STRIP "${_output}" _output)
  set(${outvar} "${_output}" PARENT_SCOPE)
endfunction()

###
# Helper function to print out everything that cmake knows about a target
#
# Copied from https://stackoverflow.com/questions/32183975/how-to-print-all-the-properties-of-a-target-in-cmake
# This isn't called anywhere, but it's very useful when debugging cmake
# NOTE: This doesn't work for INTERFACE_LIBRARY or INTERFACE_LINK_LIBRARY targets

function(print_target_properties tgt)
  if(NOT TARGET ${tgt})
    message("There is no target named '${tgt}'")
    return()
  endif()

  # Get a list of all cmake properties TODO cache this lazily somehow
  execute_process(COMMAND cmake --help-property-list OUTPUT_VARIABLE CMAKE_PROPERTY_LIST)
  STRING(REGEX REPLACE ";" "\\\\;" CMAKE_PROPERTY_LIST "${CMAKE_PROPERTY_LIST}")
  STRING(REGEX REPLACE "\n" ";" CMAKE_PROPERTY_LIST "${CMAKE_PROPERTY_LIST}")

  foreach (prop ${CMAKE_PROPERTY_LIST})
    string(REPLACE "<CONFIG>" "${CMAKE_BUILD_TYPE}" prop ${prop})
    get_property(propval TARGET ${tgt} PROPERTY ${prop} SET)
    if (propval)
      get_target_property(propval ${tgt} ${prop})
      message ("${tgt} ${prop} = ${propval}")
    endif()
  endforeach(prop)
endfunction(print_target_properties)


###
# Helper function to add style warning options to the given target
# Optionally pass in the second argument ($ARGV1) which will force -Werror if
# it evaluates to true.
function(target_enable_style_warnings TARGET)
  if(MSVC)
    # TODO Also add some warning options that MSVC can understand
    set(WARNING_OPTIONS "")
  else()
    set(WARNING_OPTIONS
            -Wall
            -Wextra
            -Wold-style-cast
            -Wno-missing-braces
            -Wcast-align
            -Wcast-qual
            -Wctor-dtor-privacy
            -Wdisabled-optimization
            -Wformat=2
            -Winit-self
            -Wmissing-include-dirs
            -Woverloaded-virtual
            -Wredundant-decls
            -Wsign-promo
            -Wstrict-overflow=5
            -fdiagnostics-show-option
            -Wconversion
            -Wpedantic
            -Wundef
            )
    # -Wno-gnu-zero-variadic-macro-arguments is not available in GCC-4.8.5. Set
    # only when using clang.
    # Compared against https://gcc.gnu.org/onlinedocs/gcc-4.8.5/gcc/Option-Summary.html
    if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
      list(APPEND WARNING_OPTIONS "-Wno-gnu-zero-variadic-macro-arguments")
    endif()
    set(WERROR $ENV{WERROR})
    if (${ARGC} GREATER 1)
      # accessing ${ARGV1} is UB when ${ARGC} <= 1
      # CMake doesn't do smart AND, so we have to use a nested `if`
      if (${ARGV1})
        set(WERROR TRUE)
      endif()
    endif()
    if (WERROR)
      list(APPEND WARNING_OPTIONS "-Werror")
    endif()
  endif()
  target_compile_options(${TARGET} PRIVATE ${WARNING_OPTIONS})
endfunction()
