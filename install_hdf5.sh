set -euo pipefail

if which yum; then
    echo "Installing zlib with yum"
    yum -y install zlib-devel
else
    echo "Installing zlib with apk"
    apk add zlib-dev
fi
echo "zlib installation complete"

pushd /tmp

if which yum; then
    # This seems to be needed to find libsz.so.2
    # using the presence of yum as a proxy to distinguish between
    # manylinux and musllinux, knowing that musllinux builds don't need this
    # step, and actually *crash* if it is run.
    ldconfig
fi

echo "Downloading & unpacking HDF5 ${HDF5_VERSION}"
# Releases after 2.1.0 are tagged with the plain version only (e.g. "2.2.0");
# older releases use the "hdf5_X.Y.Z" tag convention.
curl -fsSL -o "hdf5-${HDF5_VERSION}.tar.gz" "https://github.com/HDFGroup/hdf5/archive/refs/tags/${HDF5_VERSION}.tar.gz" \
    || curl -fsSL -o "hdf5-${HDF5_VERSION}.tar.gz" "https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5_${HDF5_VERSION}.tar.gz"
mkdir -p "hdf5-${HDF5_VERSION}"
tar -xzf "hdf5-${HDF5_VERSION}.tar.gz" --strip-components=1 -C "hdf5-${HDF5_VERSION}"
pushd "hdf5-${HDF5_VERSION}"

echo "Configuring, building & installing HDF5 ${HDF5_VERSION} to ${HDF5_DIR}"
mkdir build
cmake -S . -B build \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX="$HDF5_DIR" \
    -D BUILD_TESTING=OFF \
    -D BUILD_STATIC_LIBS=OFF \
    -D HDF5_BUILD_EXAMPLES=OFF \
    -D HDF5_BUILD_TOOLS=OFF \
    -D HDF5_BUILD_UTILS=OFF \
    -D HDF5_ALLOW_EXTERNAL_SUPPORT:STRING=NO \
    -D HDF5_ENABLE_ZLIB_SUPPORT=ON \
    -D HDF5_ENABLE_SZIP_SUPPORT=ON

make -C build -j "$(nproc)"
make -C build install
popd

# Clean up to limit the size of the Docker image
echo "Cleaning up unnecessary files"
rm -r "hdf5-${HDF5_VERSION}"
rm "hdf5-${HDF5_VERSION}.tar.gz"

if which yum; then
    yum erase -y zlib-devel
else
    apk del zlib-dev
fi
