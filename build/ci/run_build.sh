#!/bin/bash


## Fetch mgblast and modify the makefile for the location of NCBI Toolkit
wget sourceforge.net/projects/gicl/files/mgblast.tar.gz && tar xzf mgblast.tar.gz
cd mgblast
dir=`pwd`
sed "s,NCBIDIR = .*,NCBIDIR = $dir/ncbi," Makefile > Makefile.bak
mv Makefile.bak Makefile

#echo -e "CWD: $dir\n"

## Fetch and compile NCBI Toolkit, including deps
sudo apt-get -qq -y install csh xorg-dev openbox lesstif2-dev
wget ftp://ftp.ncbi.nih.gov/toolbox/ncbi_tools/old/20060507/ncbi.tar.gz && tar xzf ncbi.tar.gz

## Compile the NCBI Toolkit
./ncbi/make/makedis.csh 2>&1 > /dev/null

## Compile mgblast
make 

## Install BLAST+ and BerkeleyDB
sudo apt-get -qq -y install libdb-dev libdb++-dev ncbi-blast+

cp mgblast /usr/bin
cp ncbi/bin/formatdb /usr/bin
#export PATH=$PATH:/home/travis/build/sestaton/Transposome/mgblast:/home/travis/build/sestaton/Transposome/mgblast/ncbi/bin; 

#echo $PATH; 
#which mgblast 
#which formatdb 
#which blastn 
#which makeblastb