FROM quay.io/pypa/manylinux1_x86_64

# If there was a file .patches in the github root, it would be copied, may be useful in the future
#COPY ./patches ./patches 

# We place ourself in some safe location to do all installations
RUN cd \
  && mkdir install \
  && cd install

ARG CMAKE_VERSION="3.12.0"
ARG EIGEN3_VERSION="3.3.4"
ARG BOOST_VERSION="1.67.0"
ARG NLOPT_VERSION="2.4.2"
ARG TBB_VERSION="2019_U5"

# Installing TBB
RUN curl -L https://github.com/01org/tbb/archive/${TBB_VERSION}.tar.gz > tbb.tar.gz \
  && tar xvf tbb.tar.gz > /dev/null 2>&1 \
  && cd tbb-${TBB_VERSION} \
  && make > /dev/null 2>&1 \
  && cd build \
  && mv *_release release \
  && mv *_debug debug \
  && cd release \
  && cp libtbb* /usr/lib64/ \
  && cd ../debug \
  && cp libtbb* /usr/lib64/ \
  && ldconfig \
  && cd ../../include/ \
  && cp -r tbb /usr/local/include/ \
  && cd ../../

# Install CMake
RUN curl -L https://github.com/Kitware/CMake/archive/v${CMAKE_VERSION}.tar.gz > v${CMAKE_VERSION} \
  && tar xzf v${CMAKE_VERSION} > /dev/null 2>&1 \
  && cd CMake-${CMAKE_VERSION}/ \
  && ./configure > /dev/null \
  && gmake -j2 > /dev/null \
  && gmake install > /dev/null \
  && cd ..

# Install Eigen
RUN curl -L https://bitbucket.org/eigen/eigen/get/${EIGEN3_VERSION}.tar.gz > ${EIGEN3_VERSION} \
  && tar xzf ${EIGEN3_VERSION} > /dev/null 2>&1 \
  && cd eigen* \
  && mkdir build \
  && cd build \
  && cmake ../ > /dev/null \
  && make install > /dev/null \
  && cd .. \
  && cd ..