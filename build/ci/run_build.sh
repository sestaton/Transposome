#!/bin/bash

wget sourceforge.net/projects/gicl/files/mgblast.tar.gz
cd mgblast
make && make install

sudo apt-get install libdb-dev libdb++-dev ncbi-blast+

perl Makefile.PL && make test