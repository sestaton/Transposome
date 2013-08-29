#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use Module::Path qw(module_path);
use lib qw(../../blib/lib t/lib);
use Transposome;
use Transposome::PairFinder;
use Transposome::Cluster;
use Transposome::SeqUtil;
use Transposome::Annotation;
use Transposome::Run::Blast;
use TestUtils;

use Test::More tests => 32;

my $test = TestUtils->new( seq_file     => 't/test_data/t_reads.fas',
			   repeat_db    => 't/test_data/t_db.fas',
			   destroy      => 0,
			   build_proper => 1 );

my $conf = $test->config_constructor;
my ($conf_file) = @$conf;

my $trans_obj = Transposome->new( config => $conf_file );
ok ( $trans_obj->get_config, 'Configuration data loaded from file correctly' );
my $config = $trans_obj->get_config;

ok( defined($config->{sequence_file}), 'Can set sequence data for configuration' );
ok( defined($config->{output_directory}), 'Can set ouput directory for configuration' );
ok( defined($config->{in_memory}), 'Can set memory conditions for configuration' );
ok( $config->{in_memory} == 1, 'Can correctly set memory conditions for analysis' );

ok( defined($config->{percent_identity}), 'Can set percent identity for configuration' );
ok( defined($config->{fraction_coverage}), 'Can set fraction coverage for configuration' );
ok( defined($config->{merge_threshold}), 'Can set merge threshold for configuration' );
ok( $config->{percent_identity} == 90, 'Can correctly set percent identity for analysis' );
ok( $config->{fraction_coverage} == 0.55, 'Can correctly set fraction coverage for analysis' );
ok( $config->{merge_threshold} == 2, 'Can correctly set merge threshold for analysis' );

ok( defined($config->{cluster_size}), 'Can set cluster size for configuration' );
ok( defined($config->{blast_evalue}), 'Can set blast evalue for configuration' );
ok( $config->{cluster_size} == 1, 'Can correctly set cluster size for analysis' );
ok( $config->{blast_evalue} == 10, 'Can correctly set blast evalue for analysis' );

ok( defined($config->{repeat_database}), 'Can set repeat database for configuration' );

ok( defined($config->{report_file}), 'Can generate report file for configuration' );

my $blast = Transposome::Run::Blast->new( file      => $config->{sequence_file},
                                          dir       => $config->{output_directory},
                                          threads   => 1,
                                          cpus      => 1,
                                          seq_num   => $config->{sequence_num},
                                          report    => $config->{report_file} );

my $blastdb = $blast->run_allvall_blast;
ok( defined($blastdb), 'Can run all vs. all blast correctly' );

my $blast_res = Transposome::PairFinder->new( file              => $blastdb,  
					      dir               => $config->{output_directory},
					      in_memory         => $config->{in_memory},
					      percent_identity  => $config->{percent_identity},
					      fraction_coverage => $config->{fraction_coverage} );

my ($idx_file, $int_file, $hs_file) = $blast_res->parse_blast;
ok( defined($idx_file), 'Can parse all vs. all blast correctly' );
ok( defined($int_file), 'Can parse all vs. all blast correctly' );
ok( defined($hs_file),  'Can parse all vs. all blast correctly' );

my $path = module_path("Transposome::Cluster");
my $file = Path::Class::File->new($path);
my $pdir = $file->dir;
my $bdir = Path::Class::Dir->new("$pdir/../../bin");
my $realbin = $bdir->resolve;

my $cluster = Transposome::Cluster->new( file            => $int_file,
					 dir             => $config->{output_directory},
					 merge_threshold => $config->{merge_threshold},
					 cluster_size    => $config->{cluster_size},
                                         bin_dir         => $realbin );

my $comm = $cluster->louvain_method;
ok( defined($comm), 'Can successfully perform clustering' );

my $cluster_file = $cluster->make_clusters($comm, $idx_file);
ok( defined($cluster_file), 'Can successfully make communities following clusters' );

my ($read_pairs, $vertex, $uf) = $cluster->find_pairs($cluster_file, $config->{report_file});
ok( defined($read_pairs), 'Can find split paired reads for merging clusters' );

my $memstore = Transposome::SeqUtil->new( file => $config->{sequence_file}, in_memory => $config->{in_memory} );
my ($seqs, $seqct) = $memstore->store_seq;
ok( $seqct == 70, 'Correct number of sequences stored' );
ok( ref($seqs) eq 'HASH', 'Correct data structure for sequence store' );

my ($cls_dir_path, $cls_with_merges_path, $cls_tot) = $cluster->merge_clusters($vertex, $seqs, 
                                                                               $read_pairs, $config->{report_file}, $uf);

ok( defined($cls_dir_path), 'Can successfully merge communities based on paired-end information' );
ok( $cls_tot == 48, 'The expected number of reads went into clusters' );

my $annotation = Transposome::Annotation->new( database  => $config->{repeat_database},
					       dir       => $config->{output_directory},
					       file      => $config->{report_file},
                                               threads   => 1,
                                               cpus      => 1 );

my ($anno_rp_path, $anno_sum_rep_path, $total_readct,                                                                           
    $rep_frac, $blasts, $superfams) = $annotation->annotate_clusters($cls_dir_path, $seqct, $cls_tot);

ok( $total_readct == 48, 'Correct number of reads annotated' );
ok( $total_readct == $cls_tot, 'Same number of reads clustered and annotated' );
ok( ref($blasts) eq 'ARRAY', 'Correct data structure returned for creating annotation summary (1)' );
ok( ref($superfams) eq 'ARRAY', 'Correct data structure returned for creating annotation summary (2)' );

$annotation->clusters_annotation_to_summary($anno_rp_path, $anno_sum_rep_path, $total_readct,
                                            $seqct, $rep_frac, $blasts, $superfams, $config->{report_file});

system("rm -rf $config->{output_directory} $config->{report_file} t/transposome_mgblast* t_rep** $conf_file");

