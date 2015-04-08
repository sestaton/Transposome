#!/usr/bin/env perl

##TODO: it would be better to name these tests something descriptive..
use strict;
use warnings;
use File::Spec;
use Transposome;

use aliased 'Transposome::Test::TestFixture';
use Test::Most tests => 7;

my $seqfile  = File::Spec->catfile('t', 'test_data', 't_reads.fas.gz');
my $repeatdb = File::Spec->catfile('t', 'test_data', 't_db.fas');
 
my $test = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 1,
    build_proper => 1
);

ok( $test->config_constructor, 'Can build all configuration data for testing' );

my $test2 = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1
);

my $test2_conf = $test2->config_constructor;
my ($test2_conf_file) = @$test2_conf;

ok( defined($test2_conf_file), 'Correctly build configuration data for testing' );

my $test3 = TestFixture->new(
    seq_file     => 'test_seqfile', # does not exist
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,      
    destroy      => 0,
    build_proper => 1
);

my $test3_conf = $test3->config_constructor;
my ($test3_conf_file) = @$test3_conf;

my $trans_obj3 = Transposome->new( config => $test3_conf_file );

dies_ok { $trans_obj3->get_configuration } 'Correctly handled missing sequence file in configuration';

my $test4 = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => 'test_db',      # does not exist
    destroy      => 0,
    build_proper => 1
);

my $test4_conf = $test4->config_constructor;
my ($test4_conf_file) = @$test4_conf;

my $trans_obj4 = Transposome->new( config => $test4_conf_file );

dies_ok { $trans_obj4->get_configuration } 'Correctly handled missing repeat database file in configuration';

my $test5 = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1,
    exclude      => 'sequence_num',
);

my $test5_conf = $test5->config_constructor;
my ($test5_conf_file) = @$test5_conf;

ok( defined($test5_conf_file), 'Correctly build configuration data without sequence_num' );

my $test6 = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1,
    exclude      => 'cpu',
);

my $test6_conf = $test6->config_constructor;
my ($test6_conf_file) = @$test6_conf;

ok( defined($test6_conf_file), 'Correctly build configuration data without cpu' );

my $test7 = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1,
    exclude      => 'blast_evalue',
);

my $test7_conf = $test7->config_constructor;
my ($test7_conf_file) = @$test7_conf;

ok( defined($test7_conf_file), 'Correctly build configuration data without blast_evalue' );

my $test8 = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1,
    exclude      => 'merge_threshold',
);

my $test8_conf = $test8->config_constructor;
my ($test8_conf_file) = @$test8_conf;

ok( defined($test8_conf_file), 'Correctly build configuration data without merge_threshold' );

unlink glob("t/transposome_mgblast_*"); 
unlink glob("t/transposome_config_*");

