#!/bin/bash

#export PATH=$PATH:`pwd`/mgblast
#export PATH=$PATH:`pwd`/mgblast/ncbi/bin
export PATH=$PATH:/home/travis/build/sestaton/Transposome/build/ci/bin

perl Makefile.PL && make && make test
