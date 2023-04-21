Transposome
===========

Annotation of transposable element families from unassembled sequence reads

Build|Coverage|Github Version
---|---|---
[![CI](https://github.com/sestaton/Transposome/actions/workflows/main.yml/badge.svg)] | [![codecov](https://codecov.io/gh/sestaton/Transposome/branch/master/graph/badge.svg?token=SVO175KAI1)](https://codecov.io/gh/sestaton/Transposome) | [![GitHub version](https://badge.fury.io/gh/sestaton%2FTransposome.svg)](https://badge.fury.io/gh/sestaton%2FTransposome) 

### What is Transposome?

Transposome is a command line application to annotate [transposable elements](http://en.wikipedia.org/wiki/Transposable_element) from paired-end whole genome shotgun data. There are many tools to estimate the mathematical nature of repeats from short sequence reads. There are also a number of tools for analyzing repeats directly from a genome assembly. This tool allows you to infer the abundance of repeat types in the genome without a reference genome sequence. The output files make it easy to quickly summarize genomic abundance by transposable element class, superfamily, family, or any other level of the repeat taxonomy.

There is also a Perl API which allows you to build custom analysis pipelines, repeat stages of the analysis, or test a range of parameter values for each phase of Transposome (see the [API Tutorial](https://github.com/sestaton/Transposome/wiki/API-Tutorial) page for more information and the [transposome-scripts](https://github.com/sestaton/transposome-scripts) repository).

**RECOMMENDED USAGE**

With [Docker](https://www.docker.com/), you can create a container to run Transposome with the following command:

    docker run -it --name transposome-con sestaton/transposome

If you cannot use Docker, please see the [INSTALL](https://github.com/sestaton/Transposome/blob/master/INSTALL.md) file included with this distribution to install Transposome on various operating systems.

**BASIC USAGE**

Following installation (or starting a Docker container), get the Transposome configuration file:

    curl -sL https://git.io/bPVv > transposome_config.yml 

Next, edit the configuration file by specifying the location of data files and parameters for analysis. Note that if you downloaded manually, a configuration file can be found in the 'config' directory, or the configuration file on the [Quick Start](https://github.com/sestaton/Transposome/wiki/Quick-Start) page can be copied into a text editor and saved locally. It makes no difference which way you create the configuration file, though the `curl` method is faster.

Then, simply run the `transposome` program, specifying your configuration file:

    transposome --config transposome_config.yml

The name of the configuration file does not matter, this is just an example. Though, the format is important. It is also possible to [run individual steps of the analysis](https://github.com/sestaton/Transposome/wiki/Running-some-or-all-of-the-analysis-steps) from the command line. See the [Quick Start](https://github.com/sestaton/Transposome/wiki/Quick-Start) wiki page for more details.

**ADVANCED USAGE**

It is possible to run only one part of the Transposome package, the clustering methods for example, or create 
your own analysis methods to plug into Transposome. In addition, you can extend existing methods.

For all available methods, simply type `perldoc` followed by the name of the class you are interested in 
using. For example,

    perldoc Transposome::Cluster

Available classes are: 

    Transposome
    Transposome::Annotation
    Transposome::Cluster
    Transposome::PairFinder
    Transposome::SeqFactory
    Transposome::SeqUtil
    Transposome::Run::Blast
                      

**SUPPORT AND DOCUMENTATION**

You can get usage information at the command line with the following command:

    perldoc transposome 

The `transposome` program will also print a diagnostic help message when executed with no arguments.

You can also look for information at:

    Transposome wiki
        https://github.com/sestaton/Transposome/wiki

    Transposome issue tracker
        https://github.com/sestaton/Transposome/issues

**CITATION**

Transposome is published in the journal *Bioinformatics*, and if you use this software in your work please use the following citation:

    Staton SE, and Burke JM. 2015. Transposome: A toolkit for annotation of transposable element families from unassembled sequence reads
        Bioinformatics, 31:1827-1829.

**LICENSE AND COPYRIGHT**

Copyright (C) 2013-2023 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: http://www.opensource.org/licenses/mit-license.php

