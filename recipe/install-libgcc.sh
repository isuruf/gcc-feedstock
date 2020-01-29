set -e -x

export CHOST="${ctng_cpu_arch}-${ctng_vendor}-linux-gnu"

if [[ "$target_platform" == "linux-64" ]]; then
  mkdir -p $PREFIX/lib
  ln -s $PREFIX/lib $PREFIX/lib64 || true;
  mkdir -p $PREFIX/$CHOST/lib
  ln -s $PREFIX/$CHOST/lib $PREFIX/$CHOST/lib64 || true;
fi

# libtool wants to use ranlib that is here, macOS install doesn't grok -t etc
# .. do we need this scoped over the whole file though?
#export PATH=${SRC_DIR}/gcc_built/bin:${SRC_DIR}/.build/${CHOST}/buildtools/bin:${SRC_DIR}/.build/tools/bin:${PATH}

pushd ${SRC_DIR}/build

  make -C ${CHOST}/libgcc prefix=${PREFIX} install-shared

  mkdir -p ${PREFIX}/${CHOST}/sysroot/lib || true
  # TODO :: Also do this for libgfortran (and libstdc++ too probably?)
  sed -i.bak 's/.*cannot install.*/func_warning "Ignoring libtool error about cannot install to a directory not ending in"/' \
             ${CHOST}/libsanitizer/libtool
  for lib in libatomic libgomp libquadmath libitm libvtv libsanitizer/{a,l,ub,t}san; do
    # TODO :: Also do this for libgfortran (and libstdc++ too probably?)
    if [[ -f ${CHOST}/${lib}/libtool ]]; then
      sed -i.bak 's/.*cannot install.*/func_warning "Ignoring libtool error about cannot install to a directory not ending in"/' \
                 ${CHOST}/${lib}/libtool
    fi
    if [[ -d ${CHOST}/${lib} ]]; then
      make -C ${CHOST}/${lib} prefix=${PREFIX} install-toolexeclibLTLIBRARIES
      make -C ${CHOST}/${lib} prefix=${PREFIX} install-nodist_fincludeHEADERS || true
    fi
  done

  for lib in libgomp libquadmath; do
    if [[ -d ${CHOST}/${lib} ]]; then
      make -C ${CHOST}/${lib} prefix=${PREFIX} install-info
    fi
  done

popd

mkdir -p ${PREFIX}/lib
mv ${PREFIX}/${CHOST}/lib/* ${PREFIX}/lib

for lib in libatomic libgomp libquadmath libitm libgcc_s libvtv lib{a,l,ub,t}san; do
  symtargets=$(find ${PREFIX}/lib -name "${lib}.so*")
  for symtarget in ${symtargets}; do
    symtargetname=$(basename ${symtarget})
    ln -s ${PREFIX}/lib/${symtargetname} ${PREFIX}/${CHOST}/sysroot/lib/${symtargetname} || true;
  done
done

# no static libs
find ${PREFIX}/lib -name "*\.a" -exec rm -rf {} \;
# no libtool files
find ${PREFIX}/lib -name "*\.la" -exec rm -rf {} \;
# clean up empty folder
rm -rf ${PREFIX}/lib/gcc

# Install Runtime Library Exception
install -Dm644 ${SRC_DIR}/COPYING.RUNTIME \
        ${PREFIX}/share/licenses/gcc-libs/RUNTIME.LIBRARY.EXCEPTION
