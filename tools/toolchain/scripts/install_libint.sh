#!/bin/bash -e
[ "${BASH_SOURCE[0]}" ] && SCRIPT_NAME="${BASH_SOURCE[0]}" || SCRIPT_NAME=$0
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_NAME")" && pwd -P)"

source "${SCRIPT_DIR}"/common_vars.sh
source "${SCRIPT_DIR}"/tool_kit.sh
source "${SCRIPT_DIR}"/signal_trap.sh
source "${INSTALLDIR}"/toolchain.conf
source "${INSTALLDIR}"/toolchain.env

libint_ver="2.7.0-beta.2"
libint_pkg="libint-v${libint_ver}-cp2k-lmax-${LIBINT_LMAX}.tgz"

case "$LIBINT_LMAX" in
    4)
        libint_sha256="5717515af65e805c3808d889d91c4effa8d84dcbdc02a31e6f4d9027e3444261"
        ;;
    5)
        libint_sha256="0c9606b64bd4ebf3f40528437b1618b54677b04475f87e5d4dc6fe28a68bf69f"
        ;;
    6)
        libint_sha256="75047b9114e04ada4dbe8ec4990427571ea3ae9b5b26d77b0d80e8cc28e00669"
        ;;
    7)
        libint_sha256="8357102a9de1c577264a20d3d2d7baeb414d73ef08fb2cee16d394fd32d4ce33"
        ;;
    *)
       report_error "Unsupported value --libint-lmax=${LIBINT_LMAX}."
       exit 1
       ;;
esac

[ -f "${BUILDDIR}/setup_libint" ] && rm "${BUILDDIR}/setup_libint"

LIBINT_CFLAGS=''
LIBINT_LDFLAGS=''
LIBINT_LIBS=''
! [ -d "${BUILDDIR}" ] && mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

case "$with_libint" in
    __INSTALL__)
        echo "==================== Installing LIBINT ===================="
        pkg_install_dir="${INSTALLDIR}/libint-v${libint_ver}-cp2k-lmax-${LIBINT_LMAX}"
        install_lock_file="$pkg_install_dir/install_successful"
        if verify_checksums "${install_lock_file}" ; then
            echo "libint-${libint_ver} is already installed, skipping it."
        else
            if [ -f ${libint_pkg} ] ; then
                echo "${libint_pkg} is found"
            else
                download_pkg ${DOWNLOADER_FLAGS} ${libint_sha256} \
                             https://github.com/cp2k/libint-cp2k/releases/download/v${libint_ver}/${libint_pkg}
            fi

            [ -d libint-v${libint_ver}-cp2k-lmax-${LIBINT_LMAX} ] && rm -rf libint-v${libint_ver}-cp2k-lmax-${LIBINT_LMAX}
            tar -xzf ${libint_pkg}

            echo "Installing from scratch into ${pkg_install_dir}"
            cd libint-v${libint_ver}-cp2k-lmax-${LIBINT_LMAX}

            # reduce debug information to level 1 since
            # level 2 (default for -g flag) leads to very large binary size
            LIBINT_CXXFLAGS="$CXXFLAGS -g1"

            cmake . -DCMAKE_INSTALL_PREFIX=${pkg_install_dir} \
                    -DCMAKE_CXX_COMPILER="$CXX" \
                    -DLIBINT2_INSTALL_LIBDIR="${pkg_install_dir}/lib" \
                    -DENABLE_FORTRAN=ON \
                    -DCXXFLAGS="$LIBINT_CXXFLAGS" > configure.log 2>&1

            # restrict number of jobs to 8 since parallel build may consume too much memory
            make -j $(( NPROCS < 8 ? NPROCS : 8 )) > make.log 2>&1
            make install > install.log 2>&1

            cd ..
            write_checksums "${install_lock_file}" "${SCRIPT_DIR}/$(basename ${SCRIPT_NAME})"
        fi

        LIBINT_CFLAGS="-I'${pkg_install_dir}/include'"
        LIBINT_LDFLAGS="-L'${pkg_install_dir}/lib'"
        ;;
    __SYSTEM__)
        echo "==================== Finding LIBINT from system paths ===================="
        check_lib -lint2 "libint"
        add_include_from_paths -p LIBINT_CFLAGS "libint" $INCLUDE_PATHS
        add_lib_from_paths LIBINT_LDFLAGS "libint2.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        echo "==================== Linking LIBINT to user paths ===================="
        pkg_install_dir="$with_libint"
        check_dir "${pkg_install_dir}/lib"
        check_dir "${pkg_install_dir}/include"
        LIBINT_CFLAGS="-I'${pkg_install_dir}/include'"
        LIBINT_LDFLAGS="-L'${pkg_install_dir}/lib'"
        ;;
esac
if [ "$with_libint" != "__DONTUSE__" ] ; then
    LIBINT_LIBS="-lint2"
    if [ "$with_libint" != "__SYSTEM__" ] ; then
        cat <<EOF > "${BUILDDIR}/setup_libint"
prepend_path LD_LIBRARY_PATH "$pkg_install_dir/lib"
prepend_path LD_RUN_PATH "$pkg_install_dir/lib"
prepend_path LIBRARY_PATH "$pkg_install_dir/lib"
prepend_path CPATH "$pkg_install_dir/include"
EOF
        cat "${BUILDDIR}/setup_libint" >> $SETUPFILE
    fi
    cat <<EOF >> "${BUILDDIR}/setup_libint"
export LIBINT_CFLAGS="${LIBINT_CFLAGS}"
export LIBINT_LDFLAGS="${LIBINT_LDFLAGS}"
export LIBINT_LIBS="${LIBINT_LIBS}"
export CP_DFLAGS="\${CP_DFLAGS} -D__LIBINT"
export CP_CFLAGS="\${CP_CFLAGS} ${LIBINT_CFLAGS}"
export CP_LDFLAGS="\${CP_LDFLAGS} ${LIBINT_LDFLAGS}"
export CP_LIBS="${LIBINT_LIBS} \${CP_LIBS}"
EOF
fi

# update toolchain environment
load "${BUILDDIR}/setup_libint"
export -p > "${INSTALLDIR}/toolchain.env"

cd "${ROOTDIR}"
report_timing "libint"
