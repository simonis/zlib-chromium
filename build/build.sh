#!/bin/bash
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
pushd $MYDIR
OS=`uname`
if test "$OS" = "Darwin"; then
  CC=${CC:-clang}
  LIB_EXT="dylib"
else
  CC=${CC:-gcc}
  LIB_EXT="so"
fi
BASEDIR=../
ARCH=`uname -m`

rm -f *.o *.so *.bat *.lib *.exp *.dll *.obj *.dylib

SRC="adler32.c crc32.c gzclose.c gzread.c infback.c inflate.c trees.c zutil.c \
     compress.c deflate.c gzlib.c gzwrite.c inffast.c inftrees.c uncompr.c \
     cpu_features.c adler32_simd.c crc32_simd.c \
     contrib/optimizations/inffast_chunk.c contrib/optimizations/inflate.c"

if test "$ARCH" = "x86_64"; then
  SRC+=" crc_folding.c fill_window_sse.c"
  if [[ "$OS" == "CYGWIN"* ]]; then
    FLAGS="-DCHROMIUM_ZLIB_NO_CHROMECONF -DX86_WINDOWS -DINFLATE_CHUNK_READ_64LE -DUNALIGNED_OK -DADLER32_SIMD_SSSE3 \
           -DINFLATE_CHUNK_SIMD_SSE2 -DDEFLATE_FILL_WINDOW_SSE2 -DCRC32_SIMD_SSE42_PCLMUL -wd4244 -wd4267"
  else
    FLAGS="-DCHROMIUM_ZLIB_NO_CHROMECONF -DX86_NOT_WINDOWS -DINFLATE_CHUNK_READ_64LE -DUNALIGNED_OK -DADLER32_SIMD_SSSE3 \
           -DINFLATE_CHUNK_SIMD_SSE2 -DDEFLATE_FILL_WINDOW_SSE2 -DCRC32_SIMD_SSE42_PCLMUL -msse4.2 -mpclmul"
  fi
fi
if test "$ARCH" = "aarch64"; then
  FLAGS="-DCHROMIUM_ZLIB_NO_CHROMECONF -DARMV8_OS_LINUX -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON \
         -DCRC32_ARMV8_CRC32 -march=armv8-a+crc"
  git -C ../../zlib-chromium checkout .
  patch -p1 --directory=../../zlib-chromium < aarch64_build.patch
fi

if [[ "$OS" == "CYGWIN"* ]]; then
  #
  # Very barebone, crappy, manual Windows build
  # Still needs to get the path to either "vcvars64.bat" or "VsDevCmd.BAT"
  # passed in via the "VS_ENV_CMD" environment variable.
  #
  # For Visual Studio 2017 the locations are:
  # C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars64.bat
  # C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\vsdevcmd.bat
  #
  if test "x$VS_ENV_CMD" = "x"; then
    echo "Must define VS_ENV_CMD to point to vcvars64.bat/vsdevcmd.bat of your Visual Studio installation"
    exit
  else
    VS_ENV_CMD_UNIX=$(cygpath -u "$VS_ENV_CMD")
    if [ ! -f "$VS_ENV_CMD_UNIX" ]; then
      echo "Can't open \"$VS_ENV_CMD\""
      echo "Can't open \"$VS_ENV_CMD_UNIX\""
      echo "VS_ENV_CMD must point to vcvars64.bat/vsdevcmd.bat of your Visual Studio installation"
      exit
    fi
    if [[ $VS_ENV_CMD == *"vcvars64"* ]]; then
      VS_ENV_CMD_ARG="amd64"
    else
      VS_ENV_CMD_ARG="-arch=amd64"
    fi
  fi
  MYDIR_WIN=`cygpath -m -l $MYDIR`
  echo "CALL \"$VS_ENV_CMD\" $VS_ENV_CMD_ARG" > compile.bat
  echo "ECHO ON" >> compile.bat
  for src in $SRC; do
    echo "cl -D_CRT_SECURE_NO_DEPRECATE -D_CRT_NONSTDC_NO_DEPRECATE -DWIN32 -DIAL \
          -nologo -MD -Zc:wchar_t- -DWINDOWS -DNDEBUG -W3 -wd4800 -D_LITTLE_ENDIAN \
          -DARCH='\"amd64\"' -Damd64 -D_AMD64_ -Damd64 -Z7 -d2Zi+ -DLIBRARY_NAME=zlib-chromium \
          ${FLAGS} -D_WINDOWS -DZLIB_DLL -O2 -I$MYDIR_WIN/../../zlib-chromium/ \
          -Fo`basename $src .c`.obj -c $MYDIR_WIN/../../zlib-chromium/$src" >> compile.bat
  done
  echo "link.exe -nologo -opt:ref -incremental:no -dll -out:zlib.dll *.obj" >> compile.bat
  cmd /c compile.bat
else
  for src in $SRC; do
    ${CC} ${FLAGS} -O3 -fPIC -I${BASEDIR} -I${BASEDIR}/contrib/optimizations -c \
	  -o `basename $src .c`.o ${BASEDIR}/$src
  done
  ${CC} -shared -o libz.$LIB_EXT *.o -lc
  ln -sf libz.$LIB_EXT libz.$LIB_EXT.1
fi

if test "$ARCH" = "aarch64"; then
  git -C ../../zlib-chromium checkout .
fi

popd
