#!/usr/bin/env bash
set -u
set -e
set -x

GCC_SRC=$(realpath $1)
RISCV_TOOLCHAIN_PATH=$(realpath $2)

BUILD_PATH=$(pwd)/build
INSTALL_PATH=$BUILD_PATH/install

TARGET=riscv64-unknown-elf

MULTILIBS_GCC=( $("$RISCV_TOOLCHAIN_PATH/bin/$TARGET-gcc" -print-multi-lib 2>/dev/null) )

# Install prerequisites
cd $GCC_SRC
contrib/download_prerequisites
mkdir -p $INSTALL_PATH/$TARGET/bin
cp $RISCV_TOOLCHAIN_PATH/bin/${TARGET}-as $INSTALL_PATH/$TARGET/bin/as
cp $RISCV_TOOLCHAIN_PATH/bin/${TARGET}-ld $INSTALL_PATH/$TARGET/bin/ld
cp $RISCV_TOOLCHAIN_PATH/bin/${TARGET}-ld.bfd $INSTALL_PATH/$TARGET/bin/ld.bfd
cp $RISCV_TOOLCHAIN_PATH/bin/${TARGET}-ranlib $INSTALL_PATH/$TARGET/bin/ranlib
cp $RISCV_TOOLCHAIN_PATH/bin/${TARGET}-ar $INSTALL_PATH/$TARGET/bin/ar

# Generate multilib
MULTILIBS_GEN="rv32e-ilp32e--c \
        rv32ea-ilp32e--m \
        rv32em-ilp32e--c \
        rv32eac-ilp32e-- \
        rv32emac-ilp32e-- \
        rv32i-ilp32--c \
        rv32ia-ilp32--m \
        rv32im-ilp32--c \
        rv32if-ilp32f-rv32ifd-c \
        rv32iaf-ilp32f-rv32imaf,rv32iafc-d \
        rv32imf-ilp32f-rv32imfd-c \
        rv32iac-ilp32-- \
        rv32imac-ilp32-- \
        rv32imafc-ilp32f-rv32imafdc- \
        rv32ifd-ilp32d--c \
        rv32imfd-ilp32d--c \
        rv32iafd-ilp32d-rv32imafd,rv32iafdc- \
        rv32imafdc-ilp32d-- \
        rv64i-lp64--c \
        rv64ia-lp64--m \
        rv64im-lp64--c \
        rv64if-lp64f-rv64ifd-c \
        rv64iaf-lp64f-rv64iafc-d \
        rv64imf-lp64f-rv64imfd-c \
        rv64imaf-lp64f-- \
        rv64iac-lp64-- \
        rv64imac-lp64-- \
        rv64imafc-lp64f-rv64imafdc- \
        rv64ifd-lp64d--m,c \
        rv64iafd-lp64d-rv64imafd,rv64iafdc- \
        rv64imafdc-lp64d--"

cd $GCC_SRC/gcc/config/riscv; rm t-elf-multilib; ./multilib-generator $MULTILIBS_GEN > t-elf-multilib

# Build libstdc++ in GCC
mkdir -p $BUILD_PATH
cd $BUILD_PATH
$GCC_SRC/configure \
  --target=$TARGET \
  --prefix=$INSTALL_PATH \
  --with-pkgversion='SiFive GCC 8.3.0-2019.08.0' \
  --with-bugurl=https://github.com/sifive/freedom-tools/issues \
  --disable-shared \
  --disable-threads \
  --enable-languages=c,c++ \
  --enable-tls \
  --with-newlib \
  --with-sysroot=$RISCV_TOOLCHAIN_PATH/$TARGET \
  --with-native-system-header-dir=/include \
  --disable-libmudflap \
  --disable-libssp \
  --disable-libquadmath \
  --disable-libgomp \
  --disable-nls \
  --disable-tm-clone-registry \
  --src=$GCC_SRC \
  --with-system-zlib \
  --enable-checking=yes \
  --enable-multilib \
  --with-abi=lp64d \
  --with-arch=rv64imafdc \
  CFLAGS=-O2 \
  CXXFLAGS=-O2 \
  'CFLAGS_FOR_TARGET=-Os  -mcmodel=medany' \
  'CXXFLAGS_FOR_TARGET=-Os  -mcmodel=medany -fno-exceptions'
make -j
make install

# Copy new libstdc++ to toolchain
MULTILIBS=( $("$RISCV_TOOLCHAIN_PATH/bin/$TARGET-gcc" -print-multi-lib 2>/dev/null) )
for MULTILIB in "${MULTILIBS[@]}" ; do
    if [ $MULTILIB = ".;" ]; then
        # Skip the default multilib
        continue
    fi
    MULTI_DIR="${MULTILIB%%;*}"
    SRC_DIR=${INSTALL_PATH}/${TARGET}/lib/${MULTI_DIR}
    DST_DIR=${RISCV_TOOLCHAIN_PATH}/${TARGET}/lib/${MULTI_DIR}
    cp -f "${SRC_DIR}/libstdc++.a" "${DST_DIR}/libstdc++_nano.a"
    cp -f "${SRC_DIR}/libsupc++.a" "${DST_DIR}/libsupc++_nano.a"
done

# Sed nano.specs
