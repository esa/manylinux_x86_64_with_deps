FROM quay.io/pypa/manylinux2010_x86_64

# If there was a file .patches in the github root, it would be copied, may be useful in the future
#COPY ./patches ./patches 

# We place ourself in some safe location to do all installations
RUN cd \
  && mkdir install
WORKDIR /root/install

# Installing TBB
ARG TBB_VERSION="2019_U5"
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
ARG CMAKE_VERSION="3.12.0"
RUN curl -L https://github.com/Kitware/CMake/archive/v${CMAKE_VERSION}.tar.gz > v${CMAKE_VERSION} \
  && tar xzf v${CMAKE_VERSION} > /dev/null 2>&1 \
  && cd CMake-${CMAKE_VERSION}/ \
  && ./configure > /dev/null \
  && gmake -j2 > /dev/null \
  && gmake install > /dev/null \
  && cd ..

# Install Eigen
ARG EIGEN3_VERSION="3.3.4"
RUN curl -L https://bitbucket.org/eigen/eigen/get/${EIGEN3_VERSION}.tar.gz > ${EIGEN3_VERSION} \
  && tar xzf ${EIGEN3_VERSION} > /dev/null 2>&1 \
  && cd eigen* \
  && mkdir build \
  && cd build \
  && cmake ../ > /dev/null \
  && make install > /dev/null \
  && cd .. \
  && cd ..

# Install Boost
ARG BOOST_VERSION="1.67.0"
# Boost libraries download
RUN curl -L http://dl.bintray.com/boostorg/release/${BOOST_VERSION}/source/boost_`echo ${BOOST_VERSION}|tr "." "_"`.tar.bz2 > boost_`echo ${BOOST_VERSION}|tr "." "_"`.tar.bz2 \
  && tar xjf boost_`echo ${BOOST_VERSION}|tr "." "_"`.tar.bz2 \
  && cd boost_`echo ${BOOST_VERSION}|tr "." "_"`

# Make the non python boost libraries and install headers
RUN cd boost_`echo ${BOOST_VERSION}|tr "." "_"` \
  && sh bootstrap.sh  > /dev/null \
  && ./bjam --toolset=gcc link=shared threading=multi cxxflags="-std=c++11" variant=release --with-date_time --with-test --with-system --with-iostreams --with-timer --with-regex --with-chrono --with-serialization -j2 install > /dev/null

# We copy the jam file into the boost directory. We could change WORKDIR, but its not straight forward to use ${BOOST_VERSION} and convert it in the correct directory name.
COPY ./project-config.jam ./project-config.jam
RUN cd boost_`echo ${BOOST_VERSION}|tr "." "_"` \
  && cp ../project-config.jam ./

# We make the library for python 37m
RUN cd boost_`echo ${BOOST_VERSION}|tr "." "_"` \
  && ./bjam --toolset=gcc link=shared threading=multi cxxflags="-std=c++11" variant=release --with-python python=3.7 -j2 install > /dev/null

# We make the library for python 36m 
RUN cd boost_`echo ${BOOST_VERSION}|tr "." "_"` \
  && ./bjam --toolset=gcc link=shared threading=multi cxxflags="-std=c++11" variant=release --with-python python=3.6 -j2 install > /dev/null

# We make the library for python 27m 
RUN cd boost_`echo ${BOOST_VERSION}|tr "." "_"` \ 
  && ./bjam --toolset=gcc link=shared threading=multi cxxflags="-std=c++11" variant=release --with-python python=2.7 -j2 install > /dev/null

# We make the library for python 27mu (NOTE: we define in project-config version 2.6 to be pointing to the python27mu directories, thus we need to rename the libraries at the end)
RUN cd boost_`echo ${BOOST_VERSION}|tr "." "_"` \
  && ./bjam --toolset=gcc link=shared threading=multi cxxflags="-std=c++11" variant=release --with-python python=2.6 -j2 install > /dev/null \
  && rm /usr/local/lib/libboost_python26.so \ 
  && mv /usr/local/lib/libboost_python26.so.${BOOST_VERSION} /usr/local/lib/libboost_python27mu.so.${BOOST_VERSION} \
  && ln -s /usr/local/lib/libboost_python27mu.so.${BOOST_VERSION} /usr/local/lib/libboost_python27mu.so

# Install NLopt
ARG NLOPT_VERSION="2.4.2"
# NOTE: use alternative mirror as the one from the original webpage is faulty.
RUN curl -L  http://pkgs.fedoraproject.org/repo/pkgs/NLopt/NLopt-${NLOPT_VERSION}.tar.gz/d0b8f139a4acf29b76dbae69ade8ac54/NLopt-${NLOPT_VERSION}.tar.gz > NLopt-${NLOPT_VERSION}.tar.gz \
  && tar xzf NLopt-${NLOPT_VERSION}.tar.gz \
  && cd nlopt-${NLOPT_VERSION} \
  && ./configure --enable-shared --disable-static > /dev/null \
  && make -j2 install > /dev/null \
  && cd ..

# Download Ipopt 
ARG IPOPT_VERSION="3.12.13"
RUN curl -L  http://www.coin-or.org/download/source/Ipopt/Ipopt-${IPOPT_VERSION}.tgz > ipopt.tgz \
  && gunzip ipopt.tgz \
  && tar -xvf ipopt.tar > /dev/null \
  && mv Ipopt* ipopt

# Install Third PartyDeps for Ipopt
WORKDIR /root/install/ipopt
RUN yum install -y wget > /dev/null \
RUN ls \ 
  && cd ThirdParty/Blas/ \
  &&  ./get.Blas > /dev/null\
  &&  cd ../Lapack \
  && ./get.Lapack > /dev/null\
  && cd ../ASL \
  && ./get.ASL > /dev/null\
  && cd ../Mumps \
  && ./get.Mumps > /dev/null

# Install Ipopt (ADD_CFLAGS and friends are there to avoid the compilation error: undefined reference to 'clock_gettime' and 'clock_settime')
RUN export CXXFLAGS=-lrt \
  && export LD_FLAGS=-lrt \
  && ADD_CFLAGS=-lrt; ./configure > /dev/null \
  && make > /dev/null \ 
  && make install > /dev/null \
  && cp -r include /usr/local \
  && cp -r lib /usr/local

