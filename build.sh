#!/bin/bash -e -u
########################################################################################################################
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
########################################################################################################################
#
# Build-script for OpenOCD on MacOS, avoiding any non-system dependency
#
########################################################################################################################



#=======================================================================================================================
#
# Directory structure
#
#=======================================================================================================================
ROOT="$( cd "$( dirname "$0" )" && /bin/pwd )"
BLDROOT="$ROOT/_build"
SRCROOT="$ROOT/src"
OUTROOT="$ROOT/out"

SRC_LIBUSB="$SRCROOT/libusb"
SRC_HIDAPI="$SRCROOT/hidapi"
SRC_LIBFTDI="$SRCROOT/libftdi"
SRC_LIBCAPSTONE="$SRCROOT/libcapstone"
SRC_OPENOCD="$SRCROOT/OpenOCD"

BLD_LIBS="$BLDROOT/libs"
BLD_PCS="$BLDROOT/pcs"
BLD_OUT_BIN="$OUTROOT/bin"
BLD_OUT_SCR="$OUTROOT/share/openocd/scripts"

BLD_LIBUSB="$BLDROOT/_libusb"
BLD_HIDAPI="$BLDROOT/_hidapi"
BLD_LIBFTDI="$BLDROOT/_libftdi"
BLD_LIBCAPSTONE="$BLDROOT/_libcapstone"
BLD_OPENOCD="$BLDROOT/_OpenOCD"





#=======================================================================================================================
#
# Global build options
#
#=======================================================================================================================

export PKG_CONFIG_PATH="$BLD_PCS"
export CMAKE_LIBRARY_PATH="$BLD_LIBS" 
W1="-Wno-unused-variable -Wno-unused-but-set-variable -Wno-unused-but-set-parameter -Wno-unused-function" 
export CFLAGS="-O3 -Werror -Wall ${W1}"
export LDFLAGS="-dead_strip -L$BLD_LIBS/ -framework Foundation -framework AppKit -framework IOKit -framework security" \





#=======================================================================================================================
#
# Usage
#
#=======================================================================================================================

function usage
{
cat <<__EOF__
build.sh --help
build.sh [<step> ...]

This script takes a list of build steps which will be executed in order. Some steps combine other,
smaller steps.

Step/Sub-steps                   Description
---------------------------------------------------------------------------------------------
- all                            build everything and clean the interim build files
  +-- all-noclean                build everything, keep the intermin build files
  |   +-- clean-build            clean the (previous) iterim build files
  |   +-- libusb                 configure+build libusb
  |   |   +-- conf_libusb        configure stage of libusb
  |   |   +-- build_libusb       build stage of libusb
  |   +-- hidapi                 configure+build hidapi
  |   |   +-- conf_hidapi        configure stage of hidapi
  |   |   +-- build_hidapi       build stage of hidapi
  |   +-- libftdi                configure+build libftdi
  |   |   +-- conf_libftdi       configure stage of libftdi
  |   |   +-- build_libftdi      build stage of libftdi
  |   +-- libcapstone            configure+build libcapstone
  |   |   +-- conf_libcapstone   configure stage of libcapstone
  |   |   +-- build_libcapstone  build stage of libcapstone
  |   +-- OpenOCD                configure+build OpenOCD
  |   |   +-- conf_OpenOCD       configure stage of OpenOCD
  |   |   +-- build_OpenOCD      build stage of OpenOCD
  |   + assemble                 assemble binaries and other artefacts into output directory
  +-- clean-build                clean the interim build files

- clean_all                      clean the interim build files as well as the output files
  +-- clean_build                clean the interim build files
  +-- clean_out                  clean the output directory
__EOF__
}





#=======================================================================================================================
#
# High-Level Actions
#
#=======================================================================================================================

function all
{
  all_noclean
  clean_build
}

function all_noclean
{
  clean_build

  libusb
  hidapi
  libftdi
  libcapstone
  OpenOCD

  assemble
}

function clean_all
{
  clean_build
  clean_out
}

function libusb
{
  conf_libusb
  build_libusb
}

function hidapi
{
  conf_hidapi
  build_hidapi
}

function libftdi
{
  conf_libftdi
  build_libftdi
}

function libcapstone
{
  conf_libcapstone
  build_libcapstone
}

function OpenOCD
{
  conf_OpenOCD
  build_OpenOCD
}





#=======================================================================================================================
#
# General Utilities
#
#=======================================================================================================================


function h1
{
  spaceBefore h1
  printf "%s\n" "$*" | sed 'h;s/./=/g;H;G'
}
function h2
{
  spaceBefore h2
  printf "%s\n" "$*" | sed 'h;s/./-/g;H;g'
}

FIRST_HEADER=y
function spaceBefore
{
  if [[ -n "$FIRST_HEADER" ]] ; then
    FIRST_HEADER=''
  else
    case "$1" in
    h1)
      printf "\n\n"
      ;;
    *)
      printf "\n"
      ;;
    esac
  fi
}

function safeRemoveDir
{
  typeset dir="$1"

  if [[ ! -d "$dir" ]] ; then
    return 0
  fi

  typeset parent="$( dirname "$dir" )"
  case "$parent" in
  /*/*)
    ;;
  *)
    parent=""
    ;;
  esac

  if [[ -n "$parent" && -d "$parent" ]] ; then
    h2 "Remove directory \"$dir\""
    rm -Rf "$dir"
  else
    printf "Cowardly refusing to remove directory $dir\n"
    exit 1
  fi
}

function ensureDirExists
{
  typeset dir="$1"

  if [[ ! -d "$dir" ]] ; then
    mkdir -p "$dir"
  fi
}

function makeRelative
{
  typeset path="$1" to="${2:.}"
  OUT="$( perl -le 'use File::Spec; print File::Spec->abs2rel(@ARGV)' "$path" "$to")"
}





#=======================================================================================================================
#
# Build-specific Utilities
#
#=======================================================================================================================

function prepareAndGoToBuildDir
{
  typeset blddir="$1"

  if [[ -d "$blddir" ]] ; then
    safeRemoveDir "$blddir"
  fi

  h2 "Create $blddir"
  ensureDirExists "$BLDROOT"
  mkdir "$blddir"
  cd "$blddir"
}

function bootstrap
{
  typeset srcdir="$1"

  if [[ -x "$srcdir/bootstrap.sh" ]] ; then
    bs="bootstrap.sh"
  else
    bs="bootstrap"
  fi

  h2 "Clean source directory $srcdir"
  (cd "$srcdir" && make distclean 2>/dev/null || true)

  h2 "Invoke $bs"
  (cd "$srcdir" && "./$bs")
}

function invokeConfigure
{
  typeset confpath="$1" ; shift

  h2 "Invoke configure"
  makeRelative "$confpath" ; confpath="$OUT"
  (
    set -x
    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS" \
    PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}" \
      "$confpath" "$@"
  )
}

function invokeCmake
{
  typeset srcdir="$1" ; shift

  h2 "Invoke cmake"
  makeRelative "$srcdir" ; srcdir="$OUT"
  (
    set -x
    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS" \
    PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}" \
    CMAKE_LIBRARY_PATH="${CMAKE_LIBRARY_PATH:-}" \
    CMAKE_INCLUDE_PATH="${CMAKE_INCLUDE_PATH:-}" \
      cmake "$@" -S "$srcdir"
  )
}

function invokeMake
{
  typeset blddir="$1"

  h2 "Invoke make"
  cd "$blddir"
  make
}

function installLibs
{
  typeset libdir="$1"
  typeset tgt="$BLD_LIBS"

  h2 "Collect libraries"
  ensureDirExists "$tgt"
  find "$libdir" -name "lib*.a" -o -name "lib*.la*" | xargs -I{} cp -v {} "$tgt/"
}

function installPcs
{
  typeset pcsdir="$1"
  typeset tgt="$BLD_PCS"

  h2 "Collect package configs"
  ensureDirExists "$tgt"
  find "$pcsdir" -name "*.pc" | xargs -I{} cp -v {} "$tgt/"
}

function clean_build
{
  h1 "Cleanup of build directory"
  
  safeRemoveDir "$BLD_LIBS"
  safeRemoveDir "$BLD_PCS"

  safeRemoveDir "$BLD_LIBUSB"
  safeRemoveDir "$BLD_HIDAPI"
  safeRemoveDir "$BLD_LIBFTDI"
  safeRemoveDir "$BLD_LIBCAPSTONE"
  safeRemoveDir "$BLD_OPENOCD"
 
  safeRemoveDir "$BLDROOT"
}

function clean_out
{
  h1 "Cleanup of output dir"

  safeRemoveDir "$OUTROOT"
}





#=======================================================================================================================
#
# Per-package configuration
#
#=======================================================================================================================

function conf_libusb
{
  h1 "Configuration of libusb"

  prepareAndGoToBuildDir "$BLD_LIBUSB"
  bootstrap "$SRC_LIBUSB"
  invokeConfigure "$SRC_LIBUSB/configure" --disable-shared --enable-static
}

function conf_hidapi
{
  h1 "Configuration of hidapi"

  prepareAndGoToBuildDir "$BLD_HIDAPI"
  bootstrap "$SRC_HIDAPI"
  CFLAGS="${CFLAGS} -I$SRC_LIBUSB/libusb/" \
    invokeConfigure "$SRC_HIDAPI/configure" --disable-shared --enable-static
}

function conf_libftdi
{
  h1 "Configuration of libftdi"

  prepareAndGoToBuildDir "$BLD_LIBFTDI"
  CMAKE_INCLUDE_PATH="$SRC_LIBUSB/libusb/" \
    invokeCmake "$SRC_LIBFTDI" \
      -D LIBUSB_INCLUDE_DIR="$SRC_LIBUSB/libusb/" \
      -D LIBUSB_LIBRARIES="$BLD_LIBS/libusb-1.0.a" \
      -D EXAMPLES=OFF
}

function conf_libcapstone
{
  h1 "Configuration of libcapstone"

  prepareAndGoToBuildDir "$BLD_LIBCAPSTONE"
  CFLAGS="${CFLAGS}" \
    invokeCmake "$SRC_LIBCAPSTONE" \
      -D CAPSTONE_BUILD_STATIC_RUNTIME=OFF \
      -D CAPSTONE_BUILD_SHARED=OFF \
      -D CAPSTONE_BUILD_TESTS=OFF \
      -D CAPSTONE_BUILD_CSTOOL=OFF \
      -D CAPSTONE_ARCHITECTURE_DEFAULT=OFF \
      -D CAPSTONE_ARM_SUPPORT=ON \
      -D CAPSTONE_ARM64_SUPPORT=ON 
}

function conf_OpenOCD
{
  h1 "Configuration of OpenOCD"

  prepareAndGoToBuildDir "$BLD_OPENOCD"
  bootstrap "$SRC_OPENOCD"
  typeset W2="-Wno-strict-prototypes -Wno-deprecated-declarations -Wno-pointer-bool-conversion"
  CFLAGS="${CFLAGS} ${W2} -I$SRC_LIBUSB/libusb/ -I$SRC_LIBFTDI/src/ -I$SRC_HIDAPI/hidapi/" \
    invokeConfigure "$SRC_OPENOCD/configure"
}





#=======================================================================================================================
#
# Per-package build and assemble
#
#=======================================================================================================================

function build_libusb
{
  h1 "Build of libusb"
  invokeMake "$BLD_LIBUSB"
  installLibs "$BLD_LIBUSB/libusb/.libs"
  installPcs "$BLD_LIBUSB"
}

function build_hidapi
{
  h1 "Build of hidapi"
  invokeMake "$BLD_HIDAPI"
  installLibs "$BLD_HIDAPI/mac/.libs"
  installPcs "$BLD_HIDAPI"
}

function build_libftdi
{
  h1 "Build of libftdi"
  invokeMake "$BLD_LIBFTDI"
  installLibs "$BLD_LIBFTDI/src"
  installPcs "$BLD_LIBFTDI"
}

function build_libcapstone
{
  h1 "Build of libcapstone"
  invokeMake "$BLD_LIBCAPSTONE"
  installLibs "$BLD_LIBCAPSTONE"
  installPcs "$BLD_LIBCAPSTONE"
}

function build_OpenOCD
{
  h1 "Build of OpenOCD"
  invokeMake "$BLD_OPENOCD"

  h2 "Strip binary"
  strip "$BLD_OPENOCD/src/openocd"
}

function assemble
{
  clean_out

  h1 "Deployment of OpenOCD"

  h2 "Install binary files"
  ensureDirExists "$BLD_OUT_BIN"
  cp -p -v "$BLD_OPENOCD/src/openocd" "$BLD_OUT_BIN"

  h2 "Install script files"
  ensureDirExists "$BLD_OUT_SCR"
  cp -Rp -v "$SRC_OPENOCD/tcl"/* "$BLD_OUT_SCR"/
}





#=======================================================================================================================
#
# Main
#
#=======================================================================================================================

function filterCmd
{
  typeset cmd="$1"
  typeset item

  case "$cmd" in
  conf_*)
    item="${cmd#conf_}"
    ;;
  build_*)
    item="${cmd#build_}"
    ;;
  all|all_noclean|assemble)
    return 0
    ;;
  clean_all|clean_out|clean_build)
    return 0
    ;;
  *)
    item="$cmd"
    ;;
  esac

  case "$item" in
  libusb|hidapi|libftdi|libcapstone|OpenOCD)
    return 0
    ;;
  esac

  echo "Invalid command \"$cmd\"" 1>&2
  exit 1
}

for cmd in $* ; do
  case "$cmd" in
  --help)
    usage
    exit 0
    ;;
  esac

  cmd="${cmd/-/_}"
  filterCmd "$cmd"
  "$cmd"
done
