use 5.010;
use strict;
use warnings;
use File::Spec;
use File::Basename;
use File::Path          qw(make_path remove_tree);
use Module::Path        qw(module_path);
use IPC::System::Simple qw(system EXIT_ANY);
use Transposome::PairFinder;
use Transposome::Cluster;
use Transposome::SeqUtil;
use Transposome::Annotation;

use aliased 'Transposome::Test::TestFixture';
use Test::Most tests => 56;

my $seqfile = File::Spec->catfile('t', 'test_data', 't_reads.fas.gz');
my $outdir  = File::Spec->catdir('t', 'annotation_t');
my $report  = 'cluster_test_rep.txt';
my $db_fas  = File::Spec->catfile('t', 'test_data', 't_db.fas');
my $db      = File::Spec->catfile('t', 'test_data', 't_db_blastdb');

my $tf_obj_keep = TestFixture->new(
    seq_file         => $seqfile,
    seq_format       => 'fasta',
    repeat_db        => $db_fas,
    output_directory => $outdir,
    destroy          => 0,
    build_proper     => 1
);

my $keep_conf = $tf_obj_keep->config_constructor;
my ($keep_conf_file) = @$keep_conf;

my $test   = TestFixture->new( build_proper => 1, destroy => 0 );
my $blast  = $test->blast_constructor;
my ($blfl) = @$blast;

my $test2   = TestFixture->new( build_proper => 1, destroy => 0, exclude => 'blast_evalue' );
my $blast2  = $test2->blast_constructor;
my ($blfl2) = @$blast2;

test_annotation( $blfl, $keep_conf_file );
# remove results and test annotation without specifying evalue in configuration
remove_tree( $outdir, { safe => 1} );
test_annotation( $blfl2, $keep_conf_file );

#
# methods
#
sub test_annotation {
    my ($blfl, $keep_conf_file) = @_;
    my $blast_res = Transposome::PairFinder->new(
       config            => $keep_conf_file,
       file              => $blfl,
       dir               => $outdir,
       in_memory         => 1,
       percent_identity  => 90.0,
       fraction_coverage => 0.55,
       verbose           => 0,
       log_to_screen     => 0
    );

    my ( $idx_file, $int_file, $hs_file ) = $blast_res->parse_blast;
    
    my $path    = module_path("Transposome::Cluster");
    my $file    = Path::Class::File->new($path);
    my $pdir    = $file->dir;
    my $bdir    = Path::Class::Dir->new("$pdir/../../bin");
    my $realbin = $bdir->resolve;
    
    my $cluster = Transposome::Cluster->new(
       config          => $keep_conf_file,
       file            => $int_file,
       dir             => $outdir,
       merge_threshold => 0.029,
       cluster_size    => 1,
       bin_dir         => $realbin,
       verbose         => 0,
       log_to_screen   => 0
    );

    ok( $cluster->louvain_method, 'Can perform clustering with Louvain method' );
    my $comm = $cluster->louvain_method;
    ok( defined($comm), 'Can successfully perform clustering' );
    
    my $cluster_file = $cluster->make_clusters( $comm, $idx_file );
    ok( defined($cluster_file),
    'Can successfully make communities following clusters' );
    
    my $memstore = Transposome::SeqUtil->new( file => $seqfile, in_memory => 1 );
    my ( $seqs, $seqct ) = $memstore->store_seq;
    is( $seqct, 70, 'Correct number of sequences stored' );
    ok( ref($seqs) eq 'HASH', 'Correct data structure for sequence store' );

    my $pair_data =
        $cluster->find_pairs({ cluster_file     => $cluster_file, 
                               cluster_log_file => $report,
                               total_seq_num    => $seqct });
    
    ok( defined($pair_data->{read_pairs}), 'Can find split paired reads for merging clusters' );
    
    my %merge_args = (
        graph_vertices         => $pair_data->{graph_vertices},
        sequence_hash          => $seqs,
        read_pairs             => $pair_data->{read_pairs},
        cluster_log_file       => $report,
        graph_unionfind_object => $pair_data->{graph_unionfind_object},
    );
    
    my $cluster_data =
        $cluster->merge_clusters(\%merge_args);
    
    ok( defined($cluster_data->{cluster_directory}),
	'Can successfully merge communities based on paired-end information' );
    is( $cluster_data->{total_cluster_num}, 46, 'The expected number of reads went into clusters' );
    
    my $annotation = Transposome::Annotation->new(
       config        => $keep_conf_file,
       database      => $db_fas,
       dir           => $outdir,
       file          => $report,
       threads       => 1,
       cpus          => 1,
       verbose       => 0,
       log_to_screen => 0
    );

    ok( defined($annotation), 'new() returned something correctly' );
    ok(
       $annotation->isa('Transposome::Annotation'),
       'new() returned an object of the right class'
       );
    ok(
       $annotation->file->isa('Path::Class::File'),
       'file attribute set to the correct type'
       );
    ok(
       $annotation->database->isa('Path::Class::File'),
       'database attribute set to the correct type'
       );
    ok(
       $annotation->dir->isa('Path::Class::Dir'),
       'file attribute set to the correct type'
       );
    
    ok(
       $annotation->has_makeblastdb_exec,
       'Can make blast database for annotation'
       );
    ok( $annotation->has_blastn_exec, 'Can perform blastn for annotation' );
    
    my $annotation_results
	= $annotation->annotate_clusters({
	    cluster_directory  => $cluster_data->{cluster_directory}, 
	    singletons_file    => $cluster_data->{singletons_file}, 
	    total_sequence_num => $seqct, 
	    total_cluster_num  => $cluster_data->{total_cluster_num} });

    like( $annotation_results->{total_sequence_num}, qr/\d+/,
	  'Returned the expected type for the total number of reads clustered' );
    is( $annotation_results->{total_annotated_num}, 46, 'Correct number of reads annotated' );
    is( $annotation_results->{total_annotated_num}, $cluster_data->{total_cluster_num}, 
	'Same number of reads clustered and annotated' );
    ok( ref($annotation_results->{cluster_blast_reports}) eq 'ARRAY',
	'Correct data structure returned for creating annotation summary (1)' );
    ok( ref($annotation_results->{cluster_superfamilies}) eq 'HASH',
	'Correct data structure returned for creating annotation summary (2)' );

    ## test if annotation reports are generated correctly
    my ($annoct, $anno_sumct) = (0, 0);
    $annotation->clusters_annotation_to_summary( $annotation_results );
    
    my $anno_rp_path = $annotation_results->{annotation_report};
    my $anno_sum_rep_path = $annotation_results->{annotation_summary};
    
    ok( -s $anno_rp_path, 'Annotation report created' );
    ok( -s $anno_sum_rep_path, 'Annotation summary report created' );
    
    open my $annorep, '<', $anno_rp_path;
    open my $annosum, '<', $anno_sum_rep_path;
    $annoct++ while (<$annorep>);
    close $annorep;

    my @families = sort qw(RLG_wily RLG_teda RLG_X); #RLG_rewu
    my @anno_fams;
    while (<$annosum>) {
	$anno_sumct++;
	chomp;
	my @f = split /\t/;
	next if /^ReadNum/i;
	push @anno_fams, $f[3];
    }
    close $annosum;

    ## this is a test introduced in v0.09.2 to ensure all the annotations are logged
    ok( $annoct > 2, 'All annotations written to report file' );
    ok( $anno_sumct > 2, 'Summary annotations written to file' );

    ## check if the family mapping succeeded 
    @anno_fams = sort @anno_fams;
    #use Data::Dump::Color;
    #dd \@families; dd \@anno_fams;
    is_deeply( \@families, \@anno_fams, 'All TE families correctly annotated' );

    ## added in v0.11.1 to test getting superfamily and family name from IDs
    my $family   = shift @families;
    $family     .= '_some33othername'; 
    my $famname  = $annotation->map_family_name($family);
    my $sfamname = $annotation->map_superfamily_name($family);
    ok( $family eq 'RLG_X_some33othername', 'Generated expected ID for testing' );
    ok( $famname eq 'RLG_X', 'Returned expected results from map_family_name() method' );
    ok( $sfamname eq 'Gypsy', 'Returned expected results from map_superfamily_name() method' );

}
    
END {
    remove_tree( $outdir, { safe => 1 } );
    unlink glob("t/cluster_test_rep*");
    unlink glob("t/*.bln");
    unlink $db;
    unlink $keep_conf_file;
}

done_testing();
