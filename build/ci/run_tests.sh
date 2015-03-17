#!/bin/bash

#export PATH=$PATH:/home/travis/build/sestaton/Transposome/bin

perl Makefile.PL && make && prove -bv t/11-annotation.t
