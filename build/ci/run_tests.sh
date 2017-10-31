#!/bin/bash

#export PATH=$PATH:/home/travis/build/sestaton/Transposome/bin

perl Makefile.PL && make 
#&& cover -test -report coveralls
prove -bv t/09-megablast.t
#make test
