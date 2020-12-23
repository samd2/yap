#!/bin/bash

set -ex
export TRAVIS_BUILD_DIR=$(pwd)
export TRAVIS_BRANCH=$DRONE_BRANCH
export TRAVIS_OS_NAME=${DRONE_JOB_OS_NAME:-linux}
export VCS_COMMIT_ID=$DRONE_COMMIT
export GIT_COMMIT=$DRONE_COMMIT
export DRONE_CURRENT_BUILD_DIR=$(pwd)
export PATH=~/.local/bin:/usr/local/bin:$PATH

echo '==================================> BEFORE_INSTALL'

. .drone/before-install.sh

echo '==================================> INSTALL'

export CHECKOUT_PATH=`pwd`;
if [ -n "$GCC_VERSION" ]; then export CXX="g++-${GCC_VERSION}" CC="gcc-${GCC_VERSION}"; fi
if [ -n "$CLANG_VERSION" ]; then export CXXFLAGS="${CXXFLAGS} -stdlib=libstdc++" CXX="clang++-${CLANG_VERSION}" CC="clang-${CLANG_VERSION}"; fi
export DEPS_DIR="${TRAVIS_BUILD_DIR}/deps"
mkdir ${DEPS_DIR} && cd ${DEPS_DIR}
mkdir usr
export PATH=${DEPS_DIR}/usr/bin:${PATH}
if [[ "$MAC_OSX" == "true" ]]; then
  export CMAKE_URL="http://www.cmake.org/files/v3.7/cmake-3.7.0-Darwin-x86_64.tar.gz"
  wget --no-check-certificate --quiet -O - ${CMAKE_URL} | tar --strip-components=3 -xz -C usr
else
  export CMAKE_URL="http://www.cmake.org/files/v3.7/cmake-3.7.0-Linux-x86_64.tar.gz"
  wget --no-check-certificate --quiet -O - ${CMAKE_URL} | tar --strip-components=1 -xz -C usr
fi

echo $PATH
wget --no-check-certificate --quiet https://dl.bintray.com/boostorg/release/1.68.0/source/boost_1_68_0.tar.bz2
tar xjf boost_1_68_0.tar.bz2
$CXX --version
which $CXX
true $CC --version
true which $CC
which cmake
cmake --version
export CXXFLAGS="${CXXFLAGS} -Wall"

echo '==================================> BEFORE_SCRIPT'

. $DRONE_CURRENT_BUILD_DIR/.drone/before-script.sh

echo '==================================> SCRIPT'

cd $CHECKOUT_PATH
export ASANVARIANT="false"
if [[ "$ASAN" == "on" ]]; then export ASANVARIANT="true"; fi
for build_type in Debug Release; do
  for asan_type in $ASANVARIANT; do
    build_dir="build-$build_type-asan-$asan_type"
    mkdir $build_dir
    cd $build_dir
    if [[ "$asan_type" == "true" ]]; then 
      CXXFLAGS="$CXXFLAGS" cmake -DUSE_ASAN=true -DBOOST_ROOT=${DEPS_DIR}/boost_1_68_0 -DCMAKE_BUILD_TYPE=$build_type ..
    else
      cmake -DBOOST_ROOT=${DEPS_DIR}/boost_1_68_0 -DCMAKE_BUILD_TYPE=$build_type ..
    fi
    VERBOSE=1 make -j4 && CTEST_OUTPUT_ON_FAILURE=1 CTEST_PARALLEL_LEVEL=4 ASAN_OPTIONS=alloc_dealloc_mismatch=0 make check
    if [ $? -ne 0 ]
    then
      exit 1
    fi
    cd ..
    rm -rf $build_dir
  done
done

echo '==================================> AFTER_SUCCESS'

. $DRONE_CURRENT_BUILD_DIR/.drone/after-success.sh
