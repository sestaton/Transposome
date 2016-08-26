#!/bin/bash

#export PATH=$PATH:/home/travis/build/sestaton/Transposome/bin

perl Makefile.PL && make && cover -test -report coveralls

#make test
