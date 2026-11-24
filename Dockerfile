ARG ARCH
ARG MANYLINUXIMG
FROM docker.io/pagmo2/llvm_${MANYLINUXIMG}_${ARCH} AS builder

# NOTE: ARG declared before the first FROM is only in scope for FROM instructions.
# Re-declare it here so that $ARCH is available in the RUN instructions of this stage
# (e.g. the conditional enabling of quadmath/real128 in the mp++ build below).
ARG ARCH

# We install all dependencies in a somehow decreasing order of compile length as to
# allow for downstream modifications to be efficient.

# Install sqlite.
WORKDIR /root/install
ARG SQLITE_VERSION="3540100"
# NOTE: the download path contains the release year, update it together with the version.
ARG SQLITE_YEAR="2026"
RUN curl -L https://www.sqlite.org/${SQLITE_YEAR}/sqlite-autoconf-${SQLITE_VERSION}.tar.gz \
  -o sqlite-autoconf-${SQLITE_VERSION}.tar.gz \
  && tar xzf sqlite-autoconf-${SQLITE_VERSION}.tar.gz \
  && cd sqlite-autoconf-${SQLITE_VERSION} \
  && export OPTIONS=" \
    -DSQLITE_DQS=3 \
    -DSQLITE_ENABLE_COLUMN_METADATA \
    -DSQLITE_ENABLE_DBSTAT_VTAB \
    -DSQLITE_ENABLE_EXPLAIN_COMMENTS \
    -DSQLITE_ENABLE_FTS3 \
    -DSQLITE_ENABLE_FTS3_PARENTHESIS \
    -DSQLITE_ENABLE_FTS3_TOKENIZER \
    -DSQLITE_ENABLE_FTS4 \
    -DSQLITE_ENABLE_FTS5 \
    -DSQLITE_ENABLE_GEOPOLY \
    -DSQLITE_ENABLE_MATH_FUNCTIONS \
    -DSQLITE_ENABLE_PREUPDATE_HOOK \
    -DSQLITE_ENABLE_RTREE \
    -DSQLITE_ENABLE_SESSION \
    -DSQLITE_ENABLE_STAT4 \
    -DSQLITE_ENABLE_STMTVTAB \
    -DSQLITE_ENABLE_UNLOCK_NOTIFY \
    -DSQLITE_ENABLE_UPDATE_DELETE_LIMIT \
    -DSQLITE_LIKE_DOESNT_MATCH_BLOBS \
    -DSQLITE_MAX_EXPR_DEPTH=10000 \
    -DSQLITE_MAX_VARIABLE_NUMBER=250000 \
    -DSQLITE_SOUNDEX \
    -DSQLITE_STRICT_SUBTYPE=1 \
    -DSQLITE_THREADSAFE=1 \
    -DSQLITE_USE_URI \
    -DHAVE_ISNAN \
    -DHAVE_PREAD64 \
    -DHAVE_PWRITE64" \
  && CFLAGS="$OPTIONS" \
    ./configure \
        --prefix=/usr/local \
        --enable-threadsafe \
        --enable-load-extension \
        --disable-static \
        --disable-static-shell \
  && make -j4 \
  && make install

# Install openssl.
RUN yum -y install perl-IPC-Cmd perl-Pod-Html perl-Time-Piece
WORKDIR /root/install
ARG OPENSSL_VERSION="4.1.0"
RUN curl -L https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz > openssl.tar.gz \
  && tar xvzf openssl.tar.gz \
  && cd openssl-${OPENSSL_VERSION} \
  && ./Configure no-tests no-docs \
  && make -j4 \
  && make install

# Install gmp (before mpfr as its used by it)
WORKDIR /root/install
ARG GMP_VERSION="6.3.0"
RUN curl -L https://raw.githubusercontent.com/esa/manylinux_x86_64_with_deps/master/gmp-${GMP_VERSION}.tar.bz2 > gmp-${GMP_VERSION}.tar.bz2 \
  && tar xvf gmp-${GMP_VERSION}.tar.bz2  > /dev/null 2>&1 \
  && cd gmp-${GMP_VERSION} > /dev/null 2>&1 \
  && ./configure --enable-cxx --enable-fat > /dev/null 2>&1 \
  && make -j4 \
    #> /dev/null 2>&1 \
  && make install > /dev/null 2>&1

# Install Boost
WORKDIR /root/install
ARG BOOST_VERSION="1.92.0"
# Boost libraries download
RUN curl -L https://archives.boost.io/release/${BOOST_VERSION}/source/boost_`echo ${BOOST_VERSION}|tr "." "_"`.tar.bz2 > boost_`echo ${BOOST_VERSION}|tr "." "_"`.tar.bz2 \
  && tar xjf boost_`echo ${BOOST_VERSION}|tr "." "_"`.tar.bz2
# Make the boost libraries,  install headers
RUN cd boost_`echo ${BOOST_VERSION}|tr "." "_"` \
  && sh bootstrap.sh \
  # > /dev/null \
  && ./b2 --toolset=gcc link=shared threading=multi cxxflags="-std=c++17" variant=release \
  --with-date_time --with-test --with-filesystem --with-iostreams --with-timer --with-regex --with-chrono --with-serialization --with-charconv -j4 install
  # > /dev/null

# Install Lapack and blas (4 IPOPT)
WORKDIR /root/install
RUN yum install -y lapack-devel 
#\ > /dev/null 

# Install MUMPS (4 IPOPT)
WORKDIR /root/install
# NOTE: track the stable/3.0 branch, which is the one Ipopt 3.14 lists in its .coin-or/Dependencies file.
RUN git clone --depth 1 -b stable/3.0 https://github.com/coin-or-tools/ThirdParty-Mumps.git
RUN cd ThirdParty-Mumps && ./get.Mumps && ./configure && make && make install

# Download Ipopt
WORKDIR /root/install
ARG IPOPT_VERSION="3.14.20"
RUN curl -L  https://github.com/coin-or/Ipopt/archive/releases/${IPOPT_VERSION}.tar.gz > ipopt.tar.gz \
  && tar -xvf ipopt.tar.gz > /dev/null \
  && mv Ipopt* ipopt

# Install Ipopt (ADD_CFLAGS and friends are there to avoid the compilation error: undefined reference to 'clock_gettime' and 'clock_settime')
RUN cd ipopt && ./configure && make -j4 && make install

# Install mpfr
WORKDIR /root/install
ARG MPFR_VERSION="4.2.2"
RUN curl -L https://www.mpfr.org/mpfr-${MPFR_VERSION}/mpfr-${MPFR_VERSION}.tar.gz > mpfr-${MPFR_VERSION}.tar.gz \
  && tar xvf mpfr-${MPFR_VERSION}.tar.gz > /dev/null 2>&1 \
  && cd mpfr-${MPFR_VERSION} \
  && ./configure > /dev/null 2>&1 \
  && make -j4 \
  #> /dev/null 2>&1 \
  && make install > /dev/null 2>&1

# Installing TBB
WORKDIR /root/install
ARG TBB_VERSION="2023.2.0"
RUN curl -L https://github.com/uxlfoundation/oneTBB/archive/refs/tags/v${TBB_VERSION}.tar.gz > tbb.tar.gz \
  && tar xvf tbb.tar.gz > /dev/null 2>&1 \
  && cd oneTBB-${TBB_VERSION} \
  && mkdir build \
  && cd build \
  && cmake -DCMAKE_BUILD_TYPE=Release -DTBB_TEST=OFF -DTCM_BUILD=OFF ../ > /dev/null \
  && make -j4 \
  #> /dev/null \
  && make install 

# Install Eigen
WORKDIR /root/install
ARG EIGEN3_VERSION="5.0.1"
RUN curl -L https://gitlab.com/libeigen/eigen/-/archive/${EIGEN3_VERSION}/eigen-${EIGEN3_VERSION}.tar.gz > ${EIGEN3_VERSION} \
  && tar xzf ${EIGEN3_VERSION} > /dev/null 2>&1 \
  && cd eigen* \
  && mkdir build \
  && cd build \
  && cmake -DBUILD_TESTING=OFF -DEIGEN_BUILD_BLAS=OFF -DEIGEN_BUILD_LAPACK=OFF ../ \
  #> /dev/null \
  && make install > /dev/null 

# Install fmt
WORKDIR /root/install
ARG FMT_VERSION="12.1.0"
RUN curl -L https://github.com/fmtlib/fmt/archive/${FMT_VERSION}.tar.gz > fmt.tar.gz \
  && tar xzf fmt.tar.gz > /dev/null 2>&1 \
  && cd fmt-${FMT_VERSION} \
  && mkdir build \
  && cd build \
  && cmake -DBUILD_SHARED_LIBS=TRUE -DFMT_TEST=OFF -DFMT_DOC=OFF -DFMT_INSTALL=ON ../ \
  && make -j4 \
  # > /dev/null \
  && make install

# Install mp++
WORKDIR /root/install
ARG MPPP_VERSION="2.0.0"
RUN curl -L https://github.com/bluescarni/mppp/archive/v${MPPP_VERSION}.tar.gz > mppp.tar.gz \
  && tar xzf mppp.tar.gz > /dev/null 2>&1 \
  && cd mppp-${MPPP_VERSION} \
  && mkdir build \
  && cd build \
  && if [ "$ARCH" = "x86_64" ]; \
    then export CMAKE_PARAMS="-DMPPP_WITH_QUADMATH=yes"; \
    else export CMAKE_PARAMS=""; \
    fi \
  && cmake -DCMAKE_BUILD_TYPE=Release \
           -DMPPP_WITH_MPFR=yes \
           -DCMAKE_CXX_STANDARD=17 \
           -DMPPP_WITH_BOOST_S11N=ON \
           -DMPPP_WITH_FMT=ON \
           $CMAKE_PARAMS \
           ../ \
  #> /dev/null 2>&1 \
  && make -j4 \
  #> /dev/null 2>&1 \
  && make install

# Install NLopt
WORKDIR /root/install
ARG NLOPT_VERSION="2.11.0"
# NOTE: use alternative mirror as the one from the original webpage is faulty.
RUN curl -L  https://github.com/stevengj/nlopt/archive/v${NLOPT_VERSION}.tar.gz > NLopt-${NLOPT_VERSION}.tar.gz \
  && tar xzf NLopt-${NLOPT_VERSION}.tar.gz \
  && cd nlopt-${NLOPT_VERSION} \
  && mkdir build \
  && cd build \
  && cmake -DNLOPT_GUILE=OFF -DNLOPT_MATLAB=OFF -DNLOPT_OCTAVE=OFF -DNLOPT_PYTHON=OFF -DNLOPT_JAVA=OFF -DNLOPT_SWIG=OFF ../ > /dev/null \
  && make -j4 \
  # > /dev/null \
  && make install > /dev/null

# Install spdlog 
WORKDIR /root/install
ARG SPDLOG_VERSION="1.17.0"
RUN curl -L https://github.com/gabime/spdlog/archive/refs/tags/v${SPDLOG_VERSION}.tar.gz  > spdlog-${SPDLOG_VERSION}.tar.gz \
  && tar xvf spdlog-${SPDLOG_VERSION}.tar.gz > /dev/null 2>&1 \
  && cd spdlog-${SPDLOG_VERSION} \
  && mkdir build \
  && cd build \
  && cmake -DSPDLOG_FMT_EXTERNAL=ON -DSPDLOG_BUILD_SHARED=ON -DSPDLOG_BUILD_EXAMPLE=OFF ../ \
  && make -j4 \
    # > /dev/null \
  && make install

# Install sleef 
WORKDIR /root/install
ARG SLEEF_VERSION="3.9.0"
RUN curl -L https://github.com/shibatch/sleef/archive/${SLEEF_VERSION}.tar.gz  > sleef-${SLEEF_VERSION}.tar.gz \
  && tar xvf sleef-${SLEEF_VERSION}.tar.gz > /dev/null 2>&1 \
  && cd sleef-${SLEEF_VERSION} \
  && mkdir build \
  && cd build \
  && cmake ../ -DSLEEF_BUILD_TESTS=no -DSLEEF_BUILD_SHARED_LIBS=yes \
  && make -j4 \
    # > /dev/null \
  && make install

# Install pybind11 
WORKDIR /root/install
ARG PYBIND11_VERSION="3.1.0"
RUN curl -L https://github.com/pybind/pybind11/archive/v${PYBIND11_VERSION}.tar.gz  > pybind11-${PYBIND11_VERSION}.tar.gz \
  && tar xvf pybind11-${PYBIND11_VERSION}.tar.gz > /dev/null 2>&1 \
  && cd pybind11-${PYBIND11_VERSION} \
  && mkdir build \
  && cd build \
  && cmake ../ -DPYBIND11_TEST=no \
  && make -j4 \
    # > /dev/null \
  && make install

# Final stage.
FROM docker.io/pagmo2/llvm_${MANYLINUXIMG}_${ARCH}

# 2. Copy the entire /usr/local contents from the builder.
COPY --from=builder /usr/local/ /usr/local/

# 3. Update the linker cache.
RUN ldconfig
