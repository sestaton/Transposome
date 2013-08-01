Transposome
===========

Annotation of transposable element families from unassembled sequence reads





**INSTALLATION**

To install this module, run the following commands:

    perl Makefile.PL
    make
    make test
    make install

**BASIC USAGE**

Following successful installation, fill out the sample configuration file in the 'config' directory
in the Transposome distribution, specifying the location of data files and parameters for analysis.

Then, simply run the `transposome` program, specifying your configuration file:

    transposome --config transposome.yml

Note: The name of the configuration file does not matter, this is just an example. Though, the format is important.

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
    Transposome::SeqIO
    Transposome::SeqStore
                      

**SUPPORT AND DOCUMENTATION**

After installing, you can find documentation for this module with the
perldoc command.

    perldoc Transposome

You can also look for information at:

    RT, CPAN's request tracker (report bugs here)
        http://rt.cpan.org/NoAuth/Bugs.html?Dist=Transposome

    AnnoCPAN, Annotated CPAN documentation
        http://annocpan.org/dist/Transposome

    CPAN Ratings
        http://cpanratings.perl.org/d/Transposome

    Search CPAN
        http://search.cpan.org/dist/Transposome/


**LICENSE AND COPYRIGHT**

Copyright (C) 2013 S. Evan Staton

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
