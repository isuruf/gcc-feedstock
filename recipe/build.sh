#!/bin/bash

set -e

#for file in ./crosstool_ng/packages/gcc/$PKG_VERSION/*.patch; do
#  patch -p1 < $file;
#done

export HOST="${ctng_cpu_arch}-${ctng_vendor}-linux-gnu"

pushd binutils
for file in ../crosstool_ng/packages/binutils/2.29.1/*.patch; do
  patch -p1 < $file;
done

mkdir build
cd build

../configure \
  --prefix="$BUILD_PREFIX" \
  --target=$HOST \
  --enable-ld=default \
  --enable-gold=yes \
  --enable-plugins \
  --disable-multilib \
  --disable-sim \
  --disable-gdb \
  --disable-nls \
  --enable-default-pie \
  --with-sysroot=$PREFIX/$HOST/sysroot \
  --with-build-sysroot=$PREFIX/$HOST/sysroot

make -j${CPU_COUNT}
make install

for f in addr2line ar as c++filt dwp elfedit gprof ld ld.bfd ld.gold nm objcopy objdump ranlib readelf size strings strip; do
    ln -s $BUILD_PREFIX/bin/x86_64-conda-linux-gnu-$f $BUILD_PREFIX/bin/$f
done
popd

./contrib/download_prerequisites

mkdir build
cd build

export HOST="${ctng_cpu_arch}-${ctng_vendor}-linux-gnu"

../configure \
  --prefix="$PREFIX" \
  --libdir="$PREFIX/lib" \
  --target=$HOST \
  --enable-default-pie \
  --enable-languages=c,c++,fortran,objc,obj-c++ \
  --enable-__cxa_atexit \
  --disable-libmudflap \
  --enable-libgomp \
  --disable-libssp \
  --enable-libquadmath \
  --enable-libquadmath-support \
  --enable-libsanitizer \
  --enable-libmpx \
  --enable-lto \
  --with-host-libstdcxx='-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm' \
  --enable-threads=posix \
  --enable-target-optspace \
  --enable-plugin \
  --enable-gold \
  --disable-nls \
  --disable-multilib \
  --enable-long-long \
  --enable-default-pie \
  --with-sysroot=$PREFIX/$HOST/sysroot \
  --with-build-sysroot=$PREFIX/$HOST/sysroot

make -j${CPU_COUNT}

#exit 1
