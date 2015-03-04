#!/usr/bin/env perl

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
use Test::More tests => 20;

my $seqfile = File::Spec->catfile('t', 'test_data', 't_reads.fas.gz');
my $outdir  = File::Spec->catdir('t', 'annotation_t');
my $report  = 'cluster_test_rep.txt';
my $db_fas  = File::Spec->catfile('t', 'test_data', 't_db.fas');
my $db      = File::Spec->catfile('t', 'test_data', 't_db_blastdb');

my $test   = TestFixture->new( build_proper => 1, destroy => 0 );
my $blast  = $test->blast_constructor;
my ($blfl) = @$blast;

my $blast_res = Transposome::PairFinder->new(
    file              => $blfl,
    dir               => $outdir,
    in_memory         => 1,
    percent_identity  => 90.0,
    fraction_coverage => 0.55,
    verbose           => 0,
);

my ( $idx_file, $int_file, $hs_file ) = $blast_res->parse_blast;

my $path    = module_path("Transposome::Cluster");
my $file    = Path::Class::File->new($path);
my $pdir    = $file->dir;
my $bdir    = Path::Class::Dir->new("$pdir/../../bin");
my $realbin = $bdir->resolve;

my $cluster = Transposome::Cluster->new(
    file            => $int_file,
    dir             => $outdir,
    merge_threshold => 2,
    cluster_size    => 1,
    bin_dir         => $realbin,
    verbose         => 0,
);

ok( $cluster->louvain_method, 'Can perform clustering with Louvain method' );
my $comm = $cluster->louvain_method;
ok( defined($comm), 'Can successfully perform clustering' );

my $cluster_file = $cluster->make_clusters( $comm, $idx_file );
ok( defined($cluster_file),
    'Can successfully make communities following clusters' );

my ( $read_pairs, $vertex, $uf ) =
  $cluster->find_pairs( $cluster_file, $report );
ok( defined($read_pairs), 'Can find split paired reads for merging clusters' );

my $memstore = Transposome::SeqUtil->new( file => $seqfile, in_memory => 1 );
my ( $seqs, $seqct ) = $memstore->store_seq;
is( $seqct, 70, 'Correct number of sequences stored' );
ok( ref($seqs) eq 'HASH', 'Correct data structure for sequence store' );

my $cluster_data =
    $cluster->merge_clusters({ graph_vertices         => $vertex,
			       sequence_hash          => $seqs,
			       read_pairs             => $read_pairs,
			       cluster_log_file       => $report,
			       graph_unionfind_object => $uf });

ok( defined($cluster_data->{cluster_directory}),
    'Can successfully merge communities based on paired-end information' );
is( $cluster_data->{total_cluster_num}, 46, 'The expected number of reads went into clusters' );

my $annotation = Transposome::Annotation->new(
    database => $db_fas,
    dir      => $outdir,
    file     => $report,
    threads  => 1,
    cpus     => 1,
    verbose  => 0,
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
is( $annotation_results->{total_sequence_num}, 46, 'Correct number of reads annotated' );
is( $annotation_results->{total_sequence_num}, $cluster_data->{total_cluster_num}, 
    'Same number of reads clustered and annotated' );
ok( ref($annotation_results->{cluster_blast_reports}) eq 'ARRAY',
    'Correct data structure returned for creating annotation summary (1)' );
ok( ref($annotation_results->{cluster_superfamilies}) eq 'ARRAY',
    'Correct data structure returned for creating annotation summary (2)' );

$annotation->clusters_annotation_to_summary( $annotation_results );

END {
    remove_tree( $outdir, { safe => 1 } );
    unlink glob("t/cluster_test_rep*");
    unlink $blfl;
    unlink $db;
}

done_testing();
