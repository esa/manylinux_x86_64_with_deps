ARG ARCH=x86_64
ARG MANYLINUXIMG
FROM docker.io/pagmo2/llvm_${MANYLINUXIMG}_${ARCH}

# We install all dependencies in a somehow decreasing order of compile length as to
# allow for downstream modifications to be efficient.

# Install openssl.
RUN yum -y install perl-IPC-Cmd perl-Pod-Html
WORKDIR /root/install
ARG OPENSSL_VERSION="3.4.1"
RUN curl -L https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz > openssl.tar.gz \
  && tar xvzf openssl.tar.gz \
  && cd openssl-${OPENSSL_VERSION} \
  && ./Configure \
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
ARG BOOST_VERSION="1.86.0"
# Boost libraries download
RUN curl -L https://archives.boost.io/release/${BOOST_VERSION}/source/boost_`echo ${BOOST_VERSION}|tr "." "_"`.tar.bz2 > boost_`echo ${BOOST_VERSION}|tr "." "_"`.tar.bz2 \
  && tar xjf boost_`echo ${BOOST_VERSION}|tr "." "_"`.tar.bz2 \
  && cd boost_`echo ${BOOST_VERSION}|tr "." "_"`
# Make the boost libraries,  install headers
RUN cd boost_`echo ${BOOST_VERSION}|tr "." "_"` \
  && sh bootstrap.sh \
  # > /dev/null \
  && ./b2 --toolset=gcc link=shared threading=multi cxxflags="-std=c++11" variant=release \
  --with-date_time --with-test --with-system --with-filesystem --with-iostreams --with-timer --with-regex --with-chrono --with-serialization --with-charconv -j4 install
  # > /dev/null

# Install Lapack and blas (4 IPOPT)
WORKDIR /root/install
RUN yum install -y lapack-devel 
#\ > /dev/null 

# Install ASL (4 IPOPT)
WORKDIR /root/install
RUN git clone https://github.com/coin-or-tools/ThirdParty-ASL.git
RUN cd ThirdParty-ASL && ./get.ASL && ./configure && make -j4 && make install

# Install MUMPS (4 IPOPT)
WORKDIR /root/install
RUN git clone https://github.com/coin-or-tools/ThirdParty-Mumps.git
RUN cd ThirdParty-Mumps && ./get.Mumps && ./configure && make && make install

# Download Ipopt 
WORKDIR /root/install
ARG IPOPT_VERSION="3.14.16"
RUN curl -L  https://github.com/coin-or/Ipopt/archive/releases/${IPOPT_VERSION}.tar.gz > ipopt.tar.gz \
  && tar -xvf ipopt.tar.gz > /dev/null \
  && mv Ipopt* ipopt

# Install Ipopt (ADD_CFLAGS and friends are there to avoid the compilation error: undefined reference to 'clock_gettime' and 'clock_settime')
RUN cd ipopt && ./configure && make -j4 && make install

# Install mpfr
WORKDIR /root/install
ARG MPFR_VERSION="4.2.1"
RUN curl -L http://www.mpfr.org/mpfr-${MPFR_VERSION}/mpfr-${MPFR_VERSION}.tar.gz > mpfr-${MPFR_VERSION}.tar.gz \
  && tar xvf mpfr-${MPFR_VERSION}.tar.gz > /dev/null 2>&1 \
  && cd mpfr-${MPFR_VERSION} \
  && ./configure > /dev/null 2>&1 \
  && make -j4 \
  #> /dev/null 2>&1 \
  && make install > /dev/null 2>&1

# Installing TBB
WORKDIR /root/install
# NOTE: pin to 2021.10.0 for now due to this bug:
# https://github.com/oneapi-src/oneTBB/issues/1417
ARG TBB_VERSION="2021.10.0"
RUN curl -L https://github.com/oneapi-src/oneTBB/archive/refs/tags/v${TBB_VERSION}.tar.gz > tbb.tar.gz \
  && tar xvf tbb.tar.gz > /dev/null 2>&1 \
  && cd oneTBB-${TBB_VERSION} \
  && mkdir build \
  && cd build \
  && cmake -DTBB_TEST=OFF ../ > /dev/null \
  && make -j4 \
  #> /dev/null \
  && make install 

# Install Eigen
WORKDIR /root/install
ARG EIGEN3_VERSION="3.4.0"
RUN curl -L https://gitlab.com/libeigen/eigen/-/archive/${EIGEN3_VERSION}/eigen-${EIGEN3_VERSION}.tar.gz > ${EIGEN3_VERSION} \
  && tar xzf ${EIGEN3_VERSION} > /dev/null 2>&1 \
  && cd eigen* \
  && mkdir build \
  && cd build \
  && cmake ../ \
  #> /dev/null \
  && make install > /dev/null 

# Install fmt
WORKDIR /root/install
ARG FMT_VERSION="11.0.2"
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
           -DMPPP_WITH_FMT=yes \
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
ARG NLOPT_VERSION="2.7.1"
# NOTE: use alternative mirror as the one from the original webpage is faulty.
RUN curl -L  https://github.com/stevengj/nlopt/archive/v${NLOPT_VERSION}.tar.gz > NLopt-${NLOPT_VERSION}.tar.gz \
  && tar xzf NLopt-${NLOPT_VERSION}.tar.gz \
  && cd nlopt-${NLOPT_VERSION} \
  && mkdir build \
  && cd build \
  && cmake -DNLOPT_GUILE=OFF -DNLOPT_MATLAB=OFF -DNLOPT_OCTAVE=OFF ../ > /dev/null \
  && make -j4 \
  # > /dev/null \
  && make install > /dev/null

# Install spdlog 
WORKDIR /root/install
ARG SPDLOG_VERSION="1.14.1"
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
ARG SLEEF_VERSION="3.7"
RUN curl -L https://github.com/shibatch/sleef/archive/${SLEEF_VERSION}.tar.gz  > sleef-${SLEEF_VERSION}.tar.gz \
  && tar xvf sleef-${SLEEF_VERSION}.tar.gz > /dev/null 2>&1 \
  && cd sleef-${SLEEF_VERSION} \
  && mkdir build \
  && cd build \
  && LDFLAGS="-lrt ${LDFLAGS}"; cmake ../ -DSLEEF_BUILD_TESTS=no -DSLEEF_BUILD_SHARED_LIBS=yes \
  && make -j4 \
    # > /dev/null \
  && make install

# Install pybind11 
WORKDIR /root/install
ARG PYBIND11_VERSION="2.13.6"
RUN curl -L https://github.com/pybind/pybind11/archive/v${PYBIND11_VERSION}.tar.gz  > pybind11-${PYBIND11_VERSION}.tar.gz \
  && tar xvf pybind11-${PYBIND11_VERSION}.tar.gz > /dev/null 2>&1 \
  && cd pybind11-${PYBIND11_VERSION} \
  && mkdir build \
  && cd build \
  && cmake ../ -DPYBIND11_TEST=no \
  && make -j4 \
    # > /dev/null \
  && make install

# Making sure the new libraries (in /usr/local/lib) can be found
RUN ldconfig
