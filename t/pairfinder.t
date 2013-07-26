#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use Data::Dump qw(dd);
use PairFinder;
use TestUtils;
use Test::More tests => 2;

my $outdir = 'pairfinder_t';
my $test = TestUtils->new( build_proper => 1, destroy => 0 );
ok( $test->blast_constructor, 'Can build proper mgblast data for testing' );

my $blast = $test->blast_constructor;
my ($blfl) = @$blast;

my $mem_test = PairFinder->new( file              => $blfl,    
				dir               => $outdir,                                                                              
				in_memory         => 1,                                                                                              
				percent_identity  => 90.0,                                                                                           
				fraction_coverage => 0.55 );

ok( $mem_test->parse_blast, 'Can build in memory database and parse blast' );
#my ($idx_file, $int_file, $hs_file) = $mem_test->parse_blast;
