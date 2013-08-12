#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use File::Spec;
use File::Basename;
use File::Path qw(make_path);
use Module::Path qw(module_path);
use IPC::System::Simple qw(system EXIT_ANY);
use lib qw(../blib/lib t/lib);
use Transposome::PairFinder;
use TestUtils;
use Transposome::Cluster;
use Transposome::SeqUtil;
use Transposome::Annotation;

use Test::More tests => 17;

my $infile = 't/test_data/t_reads.fas';
my $outdir = 't/pairfinder_t';
my $report = 't/cluster_test_rep.txt';
my $db_fas = 't/test_data/t_db.fas';
my $db     = 't/test_data/t_db_blastdb';

my $test = TestUtils->new( build_proper => 1, destroy => 0 );
my $blast = $test->blast_constructor;
my ($blfl) = @$blast;

my $blast_res = Transposome::PairFinder->new( file              => $blfl,  
					      dir               => $outdir,
					      in_memory         => 1,
					      percent_identity  => 90.0,
					      fraction_coverage => 0.55 );


my ($idx_file, $int_file, $hs_file) = $blast_res->parse_blast;

my $path = module_path("Transposome::Cluster");
my $file = Path::Class::File->new($path);
my $pdir = $file->dir;
my $bdir = Path::Class::Dir->new("$pdir/../../bin");
my $realbin = $bdir->resolve;

my $cluster = Transposome::Cluster->new( file            => $int_file,
					 dir             => $outdir,
					 merge_threshold => 2,
					 cluster_size    => 1,
                                         bin_dir         => $realbin );

ok( $cluster->louvain_method, 'Can perform clustering with Louvain method' );
my $comm = $cluster->louvain_method;
ok( defined($comm), 'Can successfully perform clustering' );

my $cluster_file = $cluster->make_clusters($comm, $idx_file);
ok( defined($cluster_file), 'Can successfully make communities following clusters' );

my ($read_pairs, $vertex, $uf) = $cluster->find_pairs($cluster_file, $report);
ok( defined($read_pairs), 'Can find split paired reads for merging clusters' );

my $memstore = Transposome::SeqUtil->new( file => $infile, in_memory => 1 );
my ($seqs, $seqct) = $memstore->store_seq;
is( $seqct, 70, 'Correct number of sequences stored' );
ok( ref($seqs) eq 'HASH', 'Correct data structure for sequence store' );

my ($cls_dir_path, $cls_with_merges_path, $cls_tot) = $cluster->merge_clusters($vertex, $seqs, 
                                                                               $read_pairs, $report, $uf);

ok( defined($cls_dir_path), 'Can successfully merge communities based on paired-end information' );
is( $cls_tot, 46, 'The expected number of reads went into clusters' );

my $annotation = Transposome::Annotation->new( database  => $db_fas,
					       dir       => $outdir,
					       file      => $report );

ok( defined($annotation), 'new() returned something correctly' );
ok( $annotation->isa('Transposome::Annotation'), 'new() returned an object of the right class' );
#ok( $annotation->file->isa('Path::Class::File'), 'file attribute set to the correct type' );

ok( $annotation->has_makeblastdb_exec, 'Can make blast database for annotation' );
ok( $annotation->has_blastn_exec, 'Can perform blastn for annotation' );

my ($anno_rp_path, $anno_sum_rep_path, $total_readct,                                                                           
    $rep_frac, $blasts, $superfams) = $annotation->annotate_clusters($cls_dir_path, $seqct, $cls_tot);

like( $total_readct, qr/\d+/, 'Returned the expected type for the total number of reads clustered' );
is( $total_readct, 46, 'Correct number of reads annotated' );
is( $total_readct, $cls_tot, 'Same number of reads clustered and annotated' );
ok( ref($blasts) eq 'ARRAY', 'Correct data structure returned for creating annotation summary (1)' );
ok( ref($superfams) eq 'ARRAY', 'Correct data structure returned for creating annotation summary (2)' );

$annotation->clusters_annotation_to_summary($anno_rp_path, $anno_sum_rep_path, $total_readct,
                                            $seqct, $rep_frac, $blasts, $superfams, $report);

END {
    system("rm -rf $outdir $blfl t/cluster_test_rep* $db");
}

done_testing();
