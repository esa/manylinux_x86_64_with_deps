# manylinux2010 docker image with added dependencies
This repo contains essentially a Docker file able to build a new image starting from the manylinux2010_x86_64 and adding
 * tbb
 * Eigen3
 * CMake
 * Boost Libraries
 * NLopt
 * Ipopt
 * gmp
 * mpfr 
 
 # Use
 To build the image just type (after having cloned this repo and in its root)
 ```
 docker build ./ -t pagmo2/manylinux2010_x86_64_with_deps:latest
 ```
 Once this is done, to inspect the image with a bash log-in type:
 ```
 docker run -it pagmo2/manylinux2010_x86_64_with_deps:latest bash
 ```
 When happy, to push the image in Dockerhub, login with the pagmo2 user 
 ```
 docker login
 ```
 and push
 ```
 docker push pagmo2/manylinux2010_x86_64_with_deps
 ```
