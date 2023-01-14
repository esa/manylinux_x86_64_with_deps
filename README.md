# manylinux image with added dependencies for pagmo2+ 
This repo contains the Docker file used to build the manylinux image used to distribute in PyPi pagmo2 development team software.

 * llvm
 * tbb
 * Eigen3
 * CMake
 * Boost Libraries 
 * NLopt
 * Ipopt
 * gmp
 * mpfr 
 * sleef
 * abseil
 * obake
 * mppp
 * pybind11
 * lapack and blas
 * mumps
 * ASL
 * fmt
 * spdlog
 * symengine

 check the dockerfile for the exact versions used.
 
 # Manual upload to dockerhub
 To build the image just type (after having cloned this repo and in its root)
 ```
 docker build ./ -f ./Dockerfile228 -t pagmo2/manylinux228_x86_64_with_deps:latest
 ```
 Once this is done, to inspect the image with a bash log-in type:
 ```
 docker run -it pagmo2/manylinux228_x86_64_with_deps:latest /bin/bash
 ```
 When happy, to push the image in Dockerhub, login with the pagmo2 user 
 ```
 docker login
 ```
 and push
 ```
 docker push pagmo2/manylinux228_x86_64_with_deps
 ```
