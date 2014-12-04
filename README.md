Transposome
===========

Annotation of transposable element families from unassembled sequence reads

[![Build Status](https://travis-ci.org/sestaton/Transposome.png?branch=master)](https://travis-ci.org/sestaton/Transposome)

### What is Transposome?

Transposome is a command line application to annotate [transposable elements](http://en.wikipedia.org/wiki/Transposable_element) from paired-end whole genome shotgun data. There are many tools to estimate the mathematical nature of repeats from short sequence reads. There are also a number of tools for analyzing repeats directly from a genome assembly. This tool allows you to infer the abundance of repeat types in the genome without a reference genome sequence. The output files make it easy to quickly summarize genomic abundance by transposable element class, superfamily, family, or any other level of the repeat taxonomy.

There is also a Perl API which allows you to build custom analysis pipelines, repeat stages of the analysis, or test a range of parameter values for each phase of Transposome (see the [API Tutorial](https://github.com/sestaton/Transposome/wiki/API-Tutorial) page for more information and the [transposome-scripts](https://github.com/sestaton/transposome-scripts) repository).

**DEPENDENCIES**

To use Transposome, you will need Perl version 5.12 (or greater) installed but it is very simple to upgrade Perl with a tool called perlbrew. A [step-by-steop set of instructions](https://github.com/sestaton/Transposome/wiki/Installing-dependencies#installing-perl) is provided for installing a newer Perl version. That wiki page also explains the commands below.

**INSTALLATION**

The following commands will install Transposome (assuming Ubuntu/Debian as the OS):

    apt-get install -y build-essential lib32z1 git ncbi-blast+
    curl -L cpanmin.us | perl - git://github.com/sestaton/Transposome.git

For RHEL/Fedora:

    yum groupinstall "Development Tools"
    yum install -y glibc.i686 gcc-c++ git ncbi-blast+
    curl -L cpanmin.us | perl - git://github.com/sestaton/Transposome.git

If you run into issues, it may be easier to download the latest [release](https://github.com/sestaton/Transposome/releases) and install manually (see the [troubleshooting](https://github.com/sestaton/Transposome/wiki/Troubleshooting) page for more information) with the following commands.

    tar xzf Transposome.tar.gz
    cd Transposome
    perl Makefile.PL
    make
    make test
    make install 

Updating your installation can be achieved by simply running the same commands. Please report any issues.

**BASIC USAGE**

Following installation, fill out the sample configuration file in the 'config' directory
in the Transposome distribution, specifying the location of data files and parameters for analysis.

Then, simply run the `transposome` program, specifying your configuration file:

    transposome --config transposome_config.yml

The name of the configuration file does not matter, this is just an example. Though, the format is important. See the [Quick Start](https://github.com/sestaton/Transposome/wiki/Quick-Start) wiki page for more details.

**ADVANCED USAGE**

It is possible to run only one part of the Transposome package, the clustering methods for example, or create 
your own analysis methods to plug into Transposome. In addition, you can extend existing methods.

For all available methods, simply type `perldoc` followed by the name of the class you are interested in 
using. For example,

    perldoc Transposome::Cluster

Available classes are: 

    Transposome::Annotation
    Transposome::Cluster
    Transposome::PairFinder
    Transposome::SeqIO
    Transposome::SeqUtil
    Transposome::Run::Blast
                      

**SUPPORT AND DOCUMENTATION**

After installing, you can find documentation for the Transposome package with the
`perldoc` command.

    perldoc Transposome

If you are not interested in using Transposome programmatically or inspecting the class methods, simply type
`perldoc` followed by the name of main program to run the full analysis.

    perldoc transposome 

The `transposome` program will also print a diagnostic help message when executed with no arguments.

You can also look for information at:

    Transposome wiki
        https://github.com/sestaton/Transposome/wiki

    Transposome issue tracker
        https://github.com/sestaton/Transposome/issues

**CITATION**

A manuscript is in review, but for now please use the following citation: 
[![DOI](https://zenodo.org/badge/5565/sestaton/Transposome.png)](http://dx.doi.org/10.5281/zenodo.11303)

    Staton SE, and Burke JM. 2014. Transposome: Annotation of transposable element families
         from unassembled sequence reads. doi:10.5281/zenodo.11303

**LICENSE AND COPYRIGHT**

Copyright (C) 2013-2014 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: http://www.opensource.org/licenses/mit-license.php

