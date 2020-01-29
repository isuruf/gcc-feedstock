set -e -x

export CHOST="${ctng_cpu_arch}-${ctng_vendor}-linux-gnu"
_libdir=libexec/gcc/${CHOST}/${PKG_VERSION}

# libtool wants to use ranlib that is here, macOS install doesn't grok -t etc
# .. do we need this scoped over the whole file though?
#export PATH=${SRC_DIR}/gcc_built/bin:${SRC_DIR}/.build/${CHOST}/buildtools/bin:${SRC_DIR}/.build/tools/bin:${PATH}

pushd ${SRC_DIR}/build
  # We may not have built with plugin support so failure here is not fatal:
  make prefix=${PREFIX} install-lto-plugin || true
  make -C gcc prefix=${PREFIX} install-driver install-cpp install-gcc-ar install-headers install-plugin install-lto-wrapper install-collect2
  # not sure if this is the same as the line above.  Run both, just in case
  make -C lto-plugin prefix=${PREFIX} install
  install -dm755 ${PREFIX}/lib/bfd-plugins/

  # statically linked, so this so does not exist
  # ln -s $PREFIX/lib/gcc/$CHOST/liblto_plugin.so ${PREFIX}/lib/bfd-plugins/

  make -C libcpp prefix=${PREFIX} install

  # Include languages we do not have any other place for here (and also lto1)
  for file in gnat1 brig1 cc1 go1 lto1 cc1obj cc1objplus; do
    if [[ -f gcc/${file} ]]; then
      install -c gcc/${file} ${PREFIX}/${_libdir}/${file}
    fi
  done

  # https://github.com/gcc-mirror/gcc/blob/gcc-7_3_0-release/gcc/Makefile.in#L3481-L3526
  # Could have used install-common, but it also installs cxx binaries, which we
  # don't want in this package. We could patch it, or use the loop below:
  for file in gcov{,-tool,-dump}; do
    if [[ -f gcc/${file} ]]; then
      install -c gcc/${file} ${PREFIX}/bin/${CHOST}-${file}
    fi
  done

  make -C ${CHOST}/libgcc prefix=${PREFIX} install

  # mkdir -p $PREFIX/$CHOST/sysroot/lib

  # cp ${SRC_DIR}/gcc_built/$CHOST/sysroot/lib/libgomp.so* $PREFIX/$CHOST/sysroot/lib
  # if [ -e ${SRC_DIR}/gcc_built/$CHOST/sysroot/lib/libquadmath.so* ]; then
  #   cp ${SRC_DIR}/gcc_built/$CHOST/sysroot/lib/libquadmath.so* $PREFIX/$CHOST/sysroot/lib
  # fi

  make prefix=${PREFIX} install-libcc1
  install -d ${PREFIX}/share/gdb/auto-load/usr/lib

  make prefix=${PREFIX} install-fixincludes
  make -C gcc prefix=${PREFIX} install-mkheaders

  if [[ -d ${CHOST}/libgomp ]]; then
    make -C ${CHOST}/libgomp prefix=${PREFIX} install-nodist_{libsubinclude,toolexeclib}HEADERS
  fi

  if [[ -d ${CHOST}/libitm ]]; then
    make -C ${CHOST}/libitm prefix=${PREFIX} install-nodist_toolexeclibHEADERS
  fi

  if [[ -d ${CHOST}/libquadmath ]]; then
    make -C ${CHOST}/libquadmath prefix=${PREFIX} install-nodist_libsubincludeHEADERS
  fi

  if [[ -d ${CHOST}/libsanitizer ]]; then
    make -C ${CHOST}/libsanitizer prefix=${PREFIX} install-nodist_{saninclude,toolexeclib}HEADERS
  fi

  if [[ -d ${CHOST}/libsanitizer/asan ]]; then
    make -C ${CHOST}/libsanitizer/asan prefix=${PREFIX} install-nodist_toolexeclibHEADERS
  fi

  if [[ -d ${CHOST}/libsanitizer/tsan ]]; then
    make -C ${CHOST}/libsanitizer/tsan prefix=${PREFIX} install-nodist_toolexeclibHEADERS
  fi

  make -C libiberty prefix=${PREFIX} install
  # install PIC version of libiberty
  install -m644 libiberty/pic/libiberty.a ${PREFIX}/lib

  make -C gcc prefix=${PREFIX} install-man install-info

  make -C gcc prefix=${PREFIX} install-po

  # many packages expect this symlink
  [[ -f ${PREFIX}/bin/${CHOST}-cc ]] && rm ${PREFIX}/bin/${CHOST}-cc
  pushd ${PREFIX}/bin
    ln -s ${CHOST}-gcc ${CHOST}-cc
  popd

  # POSIX conformance launcher scripts for c89 and c99
  cat > ${PREFIX}/bin/c89 <<"EOF"
#!/bin/sh
fl="-std=c89"
for opt; do
  case "$opt" in
    -ansi|-std=c89|-std=iso9899:1990) fl="";;
    -std=*) echo "`basename $0` called with non ANSI/ISO C option $opt" >&2
      exit 1;;
  esac
done
exec gcc $fl ${1+"$@"}
EOF

  cat > ${PREFIX}/bin/c99 <<"EOF"
#!/bin/sh
fl="-std=c99"
for opt; do
  case "$opt" in
    -std=c99|-std=iso9899:1999) fl="";;
    -std=*) echo "`basename $0` called with non ISO C99 option $opt" >&2
      exit 1;;
  esac
done
exec gcc $fl ${1+"$@"}
EOF

  chmod 755 ${PREFIX}/bin/c{8,9}9

  rm ${PREFIX}/bin/${CHOST}-gcc-${PKG_VERSION}

popd

# generate specfile so that we can patch loader link path
# link_libgcc should have the gcc's own libraries by default (-R)
# so that LD_LIBRARY_PATH isn't required for basic libraries.
#
# GF method here to create specs file and edit it.  The other methods
# tried had no effect on the result.  including:
#   setting LINK_LIBGCC_SPECS on configure
#   setting LINK_LIBGCC_SPECS on make
#   setting LINK_LIBGCC_SPECS in gcc/Makefile
specdir=`dirname $($PREFIX/bin/${CHOST}-gcc -print-libgcc-file-name)`
$PREFIX/bin/${CHOST}-gcc -dumpspecs > $specdir/specs
# We use double quotes here because we want $PREFIX and $CHOST to be expanded at build time
#   and recorded in the specs file.  It will undergo a prefix replacement when our compiler
#   package is installed.
sed -i -e "/\*link_libgcc:/,+1 s+%.*+& -rpath ${PREFIX}/lib+" $specdir/specs

# Install Runtime Library Exception
install -Dm644 $SRC_DIR/COPYING.RUNTIME \
        ${PREFIX}/share/licenses/gcc/RUNTIME.LIBRARY.EXCEPTION

set +x
# Strip executables, we may want to install to a different prefix
# and strip in there so that we do not change files that are not
# part of this package.
pushd ${PREFIX}
  _files=$(find . -type f)
  for _file in ${_files}; do
    _type="$( file "${_file}" | cut -d ' ' -f 2- )"
    case "${_type}" in
      *script*executable*)
      ;;
      *executable*)
        #${BUILD_PREFIX}/bin/${CHOST}-strip --strip-all -v "${_file}"
      ;;
    esac
  done
popd

#${PREFIX}/bin/${CHOST}-gcc "${RECIPE_DIR}"/c11threads.c -std=c11

pushd ${PREFIX}/lib
ln -sf libgomp.so.${libgomp_ver} libgomp.so
popd

pushd ${PREFIX}/${CHOST}/sysroot/lib
ln -sf ../../../lib/libgomp.so libgomp.so
popd
