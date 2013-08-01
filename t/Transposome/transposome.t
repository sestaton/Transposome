#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use lib qw(../../blib/lib t/lib);
use Transposome;
use Transposome::PairFinder;
use Transposome::Cluster;
use Transposome::SeqStore;
use Transposome::Annotation;
use TestUtils;

use Test::More tests => 12;

my $test = TestUtils->new( seq_file     => 't/test_data/t_reads.fas',
			   repeat_db    => 't/test_data/t_db.fas',
			   repeat_json  => 't/test_data/t_repeats.json',
			   destroy      => 0,
			   build_proper => 1 );

my $conf = $test->config_constructor;
my ($conf_file) = @$conf;

#my $trans_obj = Transposome->new_with_options();
my $trans_obj = Transposome->new( config => $conf_file );
ok ( $trans_obj->get_config, 'Configuration data loaded from file correctly' );
my $config = $trans_obj->get_config;

my $blast_res = Transposome::PairFinder->new( file              => $config->{blast_file},  
					      dir               => $config->{output_directory},
					      in_memory         => $config->{in_memory},
					      percent_identity  => $config->{percent_identity},
					      fraction_coverage => $config->{fraction_coverage} );

my ($idx_file, $int_file, $hs_file) = $blast_res->parse_blast;

my $cluster = Transposome::Cluster->new( file            => $int_file,
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
my $memstore = Transposome::SeqStore->new( file => $config->{sequence_file}, in_memory => $config->{in_memory} );
my ($seqs, $seqct) = $memstore->store_seq;
ok( $seqct == 70, 'Correct number of sequences stored' );
ok( ref($seqs) eq 'HASH', 'Correct data structure for sequence store' );

diag("\nTrying to merge clusters...\n");

my ($cls_dir_path, $cls_with_merges_path, $cls_tot) = $cluster->merge_clusters($vertex, $seqs, 
                                                                               $read_pairs, $config->{report_file}, $uf);

ok( defined($cls_dir_path), 'Can successfully merge communities based on paired-end information' );
ok( $cls_tot == 46, 'The expected number of reads went into clusters' );

diag("\nStarting cluster annotation...\n");

my $annotation = Transposome::Annotation->new( database  => $config->{repeat_database},
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

system("rm -rf $config->{output_directory} $config->{report_file} $config->{blast_file} t_rep** $conf_file");
