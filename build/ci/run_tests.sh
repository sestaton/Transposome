#!/bin/bash

#export PATH=$PATH:/home/travis/build/sestaton/Transposome/bin

perl Makefile.PL && make && /home/travis/build/sestaton/Transposome/blib/lib && prove -lv t/11-annotation.t

#make test