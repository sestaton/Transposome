#!/bin/bash

export PATH=$PATH:/home/travis/build/sestaton/Transposome/mgblast
export PATH=$PATH:/home/travis/build/sestaton/Transposome/mgblast/ncbi/bin

perl Makefile.PL && make && make test
