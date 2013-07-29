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
	    say "\n[ERROR]: Encountered problems trying to compile source. Contact the author if you are unable to resolve this issue.\n";
	    say "Here are the errors: $_. Exiting.\n";
	    close $err;
	    unlink("comm_make_errs");
	    exit(1);
	}
    }
    close $err;
    unlink("comm_make_errs");
    chdir("..");
    system("cp src/convert bin; cp src/community bin; cp src/hierarchy bin;");
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
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Moose'                      => 2.0802,
        'MooseX::Types::Path::Class' => 0.06,
	'namespace::autoclean'       => 0.13,
	'Try::Tiny'                  => 0.12,
	'IPC::System::Simple'        => 1.21,
	'DB_File'                    => 1.826,
	'DBM::Deep'                  => 0,
	'File::Path'                 => 0,
	'Graph::UnionFind'           => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Transposome-*' },
);

