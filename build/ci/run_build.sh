#!/bin/bash

## Fetch mgblast and modify the makefile for the location of NCBI Toolkit
wget sourceforge.net/projects/gicl/files/mgblast.tar.gz && tar xzf mgblast.tar.gz
cd mgblast
dir=`pwd`
sed "s,NCBIDIR = .*,NCBIDIR = $dir/ncbi," Makefile > Makefile.bak
mv Makefile.bak Makefile

## Fetch and compile NCBI Toolkit, including deps
sudo apt-get -y install csh xorg-dev openbox lesstif2-dev
wget ftp://ftp.ncbi.nih.gov/toolbox/ncbi_tools/old/20060507/ncbi.tar.gz && tar xzf ncbi.tar.gz

## This needs to be run three times: http://www.cslu.ogi.edu/~zak/debianclusters/Installing_mpiBLAST
./ncbi/make/makedis.csh 2>&1 > /dev/null
./ncbi/make/makedis.csh 2>&1 > /dev/null
./ncbi/make/makedis.csh 2>&1 > /dev/null
# What kind of sorcery is this?

## Compile mgblast
make
cd ..

## Fetch legacy BLAST executables so we have formatdb
wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/release/2.2.14/blast-2.2.14-x64-linux.tar.gz
tar xzf blast-2.2.14-x64-linux.tar.gz

## Install BLAST+ and BerkeleyDB
sudo apt-get -y install libdb-dev libdb++-dev ncbi-blast+

