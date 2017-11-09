use 5.010;
use strict;
use warnings;
use Transposome::Analysis::Pipeline;

use aliased 'Transposome::Test::TestFixture';
use Test::More tests => 8;

#my $program  = File::Spec->catfile('blib', 'bin', 'transposome');
my $seqfile  = File::Spec->catfile('t', 'test_data', 't_reads.fas.gz');
my $repeatdb = File::Spec->catfile('t', 'test_data', 't_db.fas');
#my $outdir   = File::Spec->catdir('t', 'test_transposome_cli_out');
#my $script   = "perl -Mblib $program";

my $test = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1
);

my $conf = $test->config_constructor;
my ($conf_file) = @$conf;

my $tobj = Transposome::Analysis::Pipeline->new( config => $conf_file );
ok( $tobj->isa("Transposome::Analysis::Pipeline"), 'Can create object for running analysis pipeline' );

ok( $tobj->can('run_blast'),         'Can do run_blast method with Transposome::Analysis::Pipeline'         );
ok( $tobj->can('find_pairs'),        'Can do find_pairs method with Transposome::Analysis::Pipeline'        );
ok( $tobj->can('make_clusters'),     'Can do make_clusters method with Transposome::Analysis::Pipeline'     );
ok( $tobj->can('annotate_clusters'), 'Can do annotate_clusters method with Transposome::Analysis::Pipeline' );
ok( $tobj->can('get_blastdb'),       'Can do get_blastdb method with Transposome::Analysis::Pipeline'       );
ok( $tobj->can('get_cluster_files'), 'Can do get_cluster_files method with Transposome::Analysis::Pipeline' );
ok( $tobj->can('get_cluster_data'),  'Can do get_cluster_data method with Transposome::Analysis::Pipeline'  );

unlink glob("t/transposome_*"); 