#!/bin/bash

wget sourceforge.net/projects/gicl/files/mgblast.tar.gz
cd mgblast
make
sudo make install
cd ..

sudo apt-get install libdb-dev libdb++-dev ncbi-blast+

perl Makefile.PL && make test