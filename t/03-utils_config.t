#!/usr/bin/env perl

use strict;
use warnings;
use lib qw(../blib/lib t/lib);
use TestUtils;

use Test::More tests => 2;

my $test = TestUtils->new( seq_file     => 'test_data/t_reads.fas',
			   repeat_db    => 'test_data/t_db.fas',
			   destroy      => 1,
                           build_proper => 1 );

ok( $test->config_constructor, 'Can build all configuration data for testing' );

my $test2 = TestUtils->new( seq_file     => 'test_data/t_reads.fas',
                            repeat_db    => 'test_data/t_db.fas',
                            destroy      => 0,
                            build_proper => 1 );

my $conf = $test2->config_constructor;
my ($conf_file) = @$conf;

ok( defined($conf_file), 'Correctly build configuration data for testing' );

system("rm t/transposome_mgblast_* t/transposome_config_*");
