source ${RECIPE_DIR}/install-libgcc.sh

# stash what we need and rm -rf the rest
tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
cp ${PREFIX}/lib/libgomp.so.${libgomp_ver} ${tmp_dir}/libgomp.so.${libgomp_ver}
cp -r ${PREFIX}/conda-meta ${tmp_dir}/conda-meta
rm -rf ${PREFIX}/*

# copy back and make the right links
cp -r ${tmp_dir}/conda-meta ${PREFIX}/conda-meta
mkdir -p ${PREFIX}/lib
mkdir -p ${PREFIX}/${CHOST}/sysroot/lib
cp ${tmp_dir}/libgomp.so.${libgomp_ver} ${PREFIX}/lib/libgomp.so.${libgomp_ver}

pushd ${PREFIX}/${CHOST}/sysroot/lib
ln -s ../../../lib/libgomp.so.${libgomp_ver} libgomp.so.${libgomp_ver}
popd

# Install Runtime Library Exception
install -Dm644 ${SRC_DIR}/COPYING.RUNTIME \
        ${PREFIX}/share/licenses/gcc-libs/RUNTIME.LIBRARY.EXCEPTION.gomp_copy

rm -rf ${tmp_dir}
