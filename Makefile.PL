use 5.012;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;
use Cwd;
use File::Spec;
use File::Copy qw(copy move);
use autodie    qw(open);

my $root   = getcwd();
my $srcdir = "src";
my $bindir = File::Spec->catdir($root, 'bin');
my $bldbin = File::Spec->catdir($root, 'build', 'ci', 'bin');
my $mgbl  = "mgblast";
my $fmtdb = "formatdb";
my $conv  = "louvain_convert";
my $comm  = "louvain_community";
my $hier  = "louvain_hierarchy";

my $convbin = File::Spec->catfile($bindir, $conv);
my $commbin = File::Spec->catfile($bindir, $comm);
my $hierbin = File::Spec->catfile($bindir, $hier);
my $mgbld   = File::Spec->catfile($bldbin, $mgbl);
my $fmtbld  = File::Spec->catfile($bldbin, $fmtdb);
my $mgbin   = File::Spec->catfile($bindir, $mgbl);
my $fmtbin  = File::Spec->catfile($bindir, $fmtdb);

my $make_log = "comm_make_log";
chdir $srcdir;
system("make all 2> $make_log") == 0
    or die "make failed: $?";

open my $err, '<', $make_log;
while (<$err>) {
    chomp;
    if (/error/i) {
	say "\n[ERROR]: Encountered problems trying to compile source.";
	say "Contact the author if you are unable to resolve this issue.\n";
	say "Here are the errors: $_. Exiting.\n";
	close $err;
	unlink $make_log;
	system("make clean 2>&1 > /dev/null") == 0
	    or die "make failed: $?";
	exit(1);
    }
}
close $err;
unlink $make_log;

move $conv, $convbin or die "move failed: $!";
move $comm, $commbin or die "move failed: $!";
move $hier, $hierbin or die "move failed: $!";
system("make clean 2>&1 > /dev/null") == 0
    or die "make failed: $?";

chdir $root;
copy $mgbld,  $mgbin or die "copy failed: $!";
copy $fmtbld, $fmtbin or die "copy failed: $!";
chmod 0755, $mgbin;
chmod 0755, $fmtbin;

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
	'aliased'                          => 0,
	'autodie'                          => 0,
    },
    INST_SCRIPT => 'blib/bin',
    EXE_FILES => [ 'bin/louvain_convert', 'bin/louvain_community', 'bin/louvain_hierarchy', 
		   'bin/transposome', 'bin/mgblast', 'bin/formatdb' ],
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Transposome-* bin/louvain_* bin/formatdb bin/mgblast' },
    test  => { TESTS => 't/*.t' },
);

