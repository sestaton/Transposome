#!/bin/bash

export PATH=$PATH:/home/travis/build/sestaton/Transposome/build/ci/bin

echo "PATH: "
ls -la /home/travis/build/sestaton/Transposome/build/ci/bin

echo "FULL PATH TO EXE: "
./home/travis/build/sestaton/Transposome/build/ci/bin/mgblast

echo "ATTEMPT TO EX CMD: "
mgblast

perl Makefile.PL && make && make test
