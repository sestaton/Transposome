#!/bin/bash

export PATH=$PATH:/home/travis/build/sestaton/Transposome/build/ci/bin

ls -la /home/travis/build/sestaton/Transposome/ci/bin

perl Makefile.PL && make && make test
