#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use Transposome;
use Data::Dump qw(dd);
use Test::More tests => 11;
use PairFinder;
use Cluster;
use SeqStore;
use Annotation;

my $trans_obj = Transposome->new_with_options();

my $config = $trans_obj->get_config;

my $blast_res = PairFinder->new( file              => $config->{blast_file},  
				 dir               => $config->{output_directory},
				 in_memory         => $config->{in_memory},
				 percent_identity  => $config->{percent_identity},
				 fraction_coverage => $config->{fraction_coverage} );

my ($idx_file, $int_file, $hs_file) = $blast_res->parse_blast;

my $cluster = Cluster->new( file            => $int_file,
			    dir             => $config->{output_directory},
			    merge_threshold => $config->{merge_threshold},
			    cluster_size    => $config->{cluster_size} );

diag("\nTrying Louvain clustering now, this may take a couple of seconds...\n");
my $comm = $cluster->louvain_method;
ok( defined($comm), 'Can successfully perform clustering' );

my $cluster_file = $cluster->make_clusters($comm, $idx_file);
ok( defined($cluster_file), 'Can successfully make communities following clusters' );

my ($read_pairs, $vertex, $uf) = $cluster->find_pairs($cluster_file, $config->{report_file});
ok( defined($read_pairs), 'Can find split paired reads for merging clusters' );

diag("\nIndexing sequences, this will take a few seconds...\n");
my $memstore = SeqStore->new( file => $config->{sequence_file}, in_memory => $config->{in_memory} );
my ($seqs, $seqct) = $memstore->store_seq;
ok( $seqct == 70, 'Correct number of sequences stored' );
ok( ref($seqs) eq 'HASH', 'Correct data structure for sequence store' );

diag("\nTrying to merge clusters...\n");

my ($cls_dir_path, $cls_with_merges_path, $cls_tot) = $cluster->merge_clusters($vertex, $seqs, 
                                                                               $read_pairs, $config->{report_file}, $uf);

ok( defined($cls_dir_path), 'Can successfully merge communities based on paired-end information' );
ok( $cls_tot == 46, 'The expected number of reads went into clusters' );

#diag("\nStarting cluster annotation...\n");
#my $exit_value = system(EXIT_ANY,"makeblastdb -in $db_fas -dbtype nucl -title $db -out $db 2>&1 > /dev/null");
#if ($exit_value > 0) {
#    say "\n[ERROR]: Unable to make blast database for testing. Exited with exit value: $exit_value.";
#    say "[ERROR]: Here is the exception: $_\nCheck your blast installation and try to get this test to pass before proceeding. Exiting.\n";
#    exit(1);
#};

my $annotation = Annotation->new( database  => $config->{repeat_database},
				  rb_json   => $config->{repeat_json_file},
				  dir       => $config->{output_directory},
				  file      => $config->{report_file} );

my ($anno_rp_path, $anno_sum_rep_path, $total_readct,                                                                           
    $rep_frac, $blasts, $superfams) = $annotation->annotate_clusters($cls_dir_path, $seqct, $cls_tot);

#ok( $annotation->annotate_clusters, 'Can load annotation methods and annotate clusters' );

#ok( $rep_frac == 0.000139324699240378, 'Calculated the correct repeat fraction from the test data' ); #changes?
ok( $total_readct == 46, 'Correct number of reads annotated' );
ok( $total_readct == $cls_tot, 'Same number of reads clustered and annotated' );
ok( ref($blasts) eq 'ARRAY', 'Correct data structure returned for creating annotation summary (1)' );
ok( ref($superfams) eq 'ARRAY', 'Correct data structure returned for creating annotation summary (2)' );

$annotation->clusters_annotation_to_summary($anno_rp_path, $anno_sum_rep_path, $total_readct,
                                            $seqct, $rep_frac, $blasts, $superfams, $config->{report_file});
