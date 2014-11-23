#!/usr/bin/env perl

use strict;
use warnings;
use File::Spec;
use Transposome;

use aliased 'Transposome::Test::TestUtils';
use Test::Most tests => 4;

my $seqfile  = File::Spec->catfile('t', 'test_data', 't_reads.fas');
my $repeatdb = File::Spec->catfile('t', 'test_data', 't_db.fas');
 
my $test = TestUtils->new(
    seq_file     => $seqfile,
    repeat_db    => $repeatdb,
    destroy      => 1,
    build_proper => 1
);

ok( $test->config_constructor, 'Can build all configuration data for testing' );

my $test2 = TestUtils->new(
    seq_file     => $seqfile,
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1
);

my $test2_conf = $test2->config_constructor;
my ($test2_conf_file) = @$test2_conf;

ok( defined($test2_conf_file), 'Correctly build configuration data for testing' );

my $test3 = TestUtils->new(
    seq_file     => 'test_seqfile', # does not exist
    repeat_db    => $repeatdb,      
    destroy      => 0,
    build_proper => 1
);

my $test3_conf = $test3->config_constructor;
my ($test3_conf_file) = @$test3_conf;

my $trans_obj3 = Transposome->new( config => $test3_conf_file );

dies_ok { $trans_obj3->get_configuration } 'Correctly handled missing sequence file in configuration';

my $test4 = TestUtils->new(
    seq_file     => $seqfile,
    repeat_db    => 'test_db',      # does not exist
    destroy      => 0,
    build_proper => 1
);

my $test4_conf = $test4->config_constructor;
my ($test4_conf_file) = @$test4_conf;

my $trans_obj4 = Transposome->new( config => $test4_conf_file );

dies_ok { $trans_obj4->get_configuration } 'Correctly handled missing repeat database file in configuration';

system("rm t/transposome_mgblast_* t/transposome_config_*");
