use 5.012;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;
use autodie qw(open);

BEGIN {
    chdir("src");
    system("make all 2> comm_make_errs");
    open my $err, '<', "comm_make_errs";
    while (<$err>) {
	chomp;
	if (/error/i) {
	    say "\n[ERROR]: Encountered problems trying to compile source.";
	    say "Contact the author if you are unable to resolve this issue.\n";
	    say "Here are the errors: $_. Exiting.\n";
	    close $err;
	    unlink("comm_make_errs");
	    system("make clean 2>&1 > /dev/null");
	    exit(1);
	}
    }
    close $err;
    unlink("comm_make_errs");
    system("cp louvain_convert ../bin; cp louvain_community ../bin; cp louvain_hierarchy ../bin;");
    system("make clean 2>&1 > /dev/null");
    chdir("..");
    system("chmod +x bin/transposome");
}

WriteMakefile(
    NAME             => 'Transposome',
    AUTHOR           => q{S. Evan Staton <statonse@gmail.com>},
    VERSION_FROM     => 'lib/Transposome.pm',
    ABSTRACT_FROM    => 'lib/Transposome.pm',
    LICENSE          => 'MIT',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.012,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 6.5503,
    },
    BUILD_REQUIRES => {
        'Test::Most' => 0,
    },
    PREREQ_PM => {
        'Moose'                            => 2.0802,
	'MooseX::Getopt'                   => 0.56,
	'MooseX::Getopt::Usage'            => 0.14,
	'MooseX::Log::Log4perl'            => 0.46,
        'MooseX::Types::Path::Class'       => 0.06,
	'MooseX::Types'                    => 0.38,
	'Method::Signatures'               => 20131010,
	'namespace::autoclean'             => 0.13,
	'Try::Tiny'                        => 0.12,
	'IPC::System::Simple'              => 1.21,
	'DBD::SQLite'                      => 1.44,
	'Tie::Hash::DBD'                   => 0.13,
	'Module::Path'                     => 0.09,
	'Path::Class'                      => 0.32,
	'YAML::Tiny'                       => 1.62,
	'Parallel::ForkManager'            => 0.7,
	'Log::Log4perl'                    => 1.40,
	'DateTime'                         => 1.03,
	'Lingua::EN::Inflect'              => 0,
	'DBM::Deep'                        => 0,
	'File::Path'                       => 0,
	'Graph'                            => 0,
	'File::Path'                       => 0,
    },
    INST_SCRIPT => 'blib/bin',
    EXE_FILES => [ 'bin/louvain_convert', 'bin/louvain_community', 'bin/louvain_hierarchy', 'bin/transposome' ],
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Transposome-* bin/louvain_*' },
    test  => { TESTS => 't/*.t t/Transposome/*.t' },
);

