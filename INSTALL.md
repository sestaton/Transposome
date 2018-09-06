**DEPENDENCIES**

To use Transposome, you will need Perl installed (version 5.10 or greater) and it is very simple to install Perl with a tool called perlbrew. A [step-by-step set of instructions](https://github.com/sestaton/Transposome/wiki/Installing-dependencies#installing-perl) is provided for installing a recent version of Perl. That wiki page also explains the commands below.

**INSTALLATION**

Note that the following commands assume a fresh cloud instance with no compilers or libraries installed. There are only a couple of steps, but please be advised that it can take a little while (perhaps 20 minutes) to compile the dependencies.

*For Ubuntu/Debian as the OS:*

    apt-get install -y build-essential lib32z1 git ncbi-blast+ curl
    curl -L cpanmin.us | perl - git://github.com/sestaton/Transposome.git

*For RHEL/Fedora:*

    yum groupinstall "Development Tools"
    yum install -y glibc.i686 gcc-c++ git ncbi-blast+
    curl -L cpanmin.us | perl - git://github.com/sestaton/Transposome.git

*Note for CentOS users:*

All of the above commands for RHEL will work on CentOS except for the ncbi-blast+ package. Please install this package separately from the [NCBI downloads page](http://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download) copying the binaries to somewhere in your PATH (e.g., /usr/local/bin), or for regular users, just extend your PATH to the location of the BLAST+ 'bin' directory.

If you run into issues with the above steps, it is likely that you are missing a dependency. In this case, download the latest [release](https://github.com/sestaton/Transposome/releases) and install manually (see the [troubleshooting](https://github.com/sestaton/Transposome/wiki/Troubleshooting) page for more information) with the following commands.

    tar xzf Transposome.tar.gz
    cd Transposome
    curl -L cpanmin.us | perl - --installdeps .
    perl Makefile.PL
    make
    make test
    make install

These steps will give a clear indication of any issues. Updating your installation can be achieved by simply running the same commands. Please report any issues.