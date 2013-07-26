#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use File::Spec;
use File::Basename;
use File::Path qw(make_path);
use Data::Dump qw(dd);
use PairFinder;
use TestUtils;
use Cluster;

use Test::More tests => 2;

my $outdir = 'pairfinder_t';
my $test = TestUtils->new( build_proper => 1, destroy => 0 );
my $blast = $test->blast_constructor;
my ($blfl) = @$blast;

my $blast_res = PairFinder->new( file              => $blfl,  
				 dir               => $outdir,                                                                              
				 in_memory         => 1,                                                                                              
				 percent_identity  => 90.0,                                                                                           
				 fraction_coverage => 0.55 );


my ($idx_file, $int_file, $hs_file) = $blast_res->parse_blast;

my $cluster = Cluster->new( file   =>  $int_file,
			    dir    =>  $outdir );

ok( $cluster->louvain_method, 'Can perform clusterin with Louvain method' );

diag("\nTrying Louvain clustering now, this may take a couple of seconds...\n");

my $comm = $cluster->louvain_method;

ok( defined($comm), 'Can successfully perform clustering' );

system("rm -rf $outdir $blfl");
