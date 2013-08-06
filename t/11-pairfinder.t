#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use Data::Dump qw(dd);
use autodie qw(open);
use lib qw(../blib/lib t/lib);
use Transposome::PairFinder;
use TestUtils;

use Test::More tests => 498;

my $outdir = 't/transposome_pairfinder_t';
my $test = TestUtils->new( build_proper => 1, destroy => 0 );
ok( $test->blast_constructor, 'Can build proper mgblast data for testing' );
system("rm t/transposome_mgblast_*");

my $blast = $test->blast_constructor;
my ($blfl) = @$blast;

## test in-memory processing
my $mem_test = Transposome::PairFinder->new( file              => $blfl,    
					     dir               => $outdir,                                                                              
					     in_memory         => 1,                 
					     percent_identity  => 90.0, 
					     fraction_coverage => 0.55 );

ok( $mem_test->parse_blast, 'Can build in memory database and parse blast' );

my ($mem_idx_file, $mem_int_file, $mem_hs_file) = $mem_test->parse_blast;

my ($mem_idx_recct, $mem_int_recct, $mem_hs_recct, 
    $file_idx_recct, $file_int_recct, $file_hs_recct) = (0, 0, 0, 0, 0, 0);
open my $mem_idx, '<', $mem_idx_file;
open my $mem_int, '<', $mem_int_file;
open my $mem_hs, '<', $mem_hs_file;

while (<$mem_idx>) {
    chomp;
    my @f = split;
    ok( scalar @f == 2, 'Index file has the right number of fields' );
    ok( $f[1] =~ /\d+/, 'Parsed score correctly for blast pairs' );
    #TODO: Test for unique pairs
    $mem_idx_recct++;
}
close $mem_idx;

ok( $mem_idx_recct == 46, 'Correct number of unique pairs found in index' );

while (<$mem_int>) {
    chomp;
    my @f = split;
    ok( scalar @f == 3, 'Integer mapping of pairs has the right number of fields' );
    ok($f[0] =~ /\d+/,'Blast pairs mapped correctly to integer form' );
    ok($f[1] =~ /\d+/,'Blast pairs mapped correctly to integer form' );
    ok($f[2] =~ /\d+/,'Blast pairs mapped correctly to integer form' );
    #TODO: Test for unique pairs
    $mem_int_recct++;
}
close $mem_int;

ok( $mem_int_recct == 25, 'Correct number of unique pairs found in integer mapping' );

while (<$mem_hs>) {
    chomp;
    my @f = split;
    ok( scalar @f == 3, 'Integer mapping of pairs has the right number of fields' );
    ok($f[2] =~ /\d+/,'Blast pair score mapped parsed correctly' );
    #TODO: Test for unique pairs
    $mem_hs_recct++;
}
close $mem_hs;

ok( $mem_hs_recct == 25, 'Correct number of unique pairs found in ID mapping' );
ok( $mem_hs_recct == $mem_int_recct, 'Index and integer mapping files contain the same records' );

system("rm -rf t/$outdir");

## test on-file processing
my $file_test = Transposome::PairFinder->new( file              => $blfl,
					      dir               => $outdir,
					      in_memory         => 0,
					      percent_identity  => 90.0,
					      fraction_coverage => 0.55 );

ok( $file_test->parse_blast, 'Can build database on file and parse blast' );

my ($onfile_idx_file, $onfile_int_file, $onfile_hs_file) = $file_test->parse_blast;

open my $file_idx, '<', $onfile_idx_file;
open my $file_int, '<', $onfile_int_file;
open my $file_hs, '<', $onfile_hs_file;

while (<$file_idx>) {
    chomp;
    my @f = split;
    ok( scalar @f == 2, 'Index file has the right number of fields' );
    ok( $f[1] =~ /\d+/, 'Parsed score correctly for blast pairs' );
    #TODO: Test for unique pairs
    $file_idx_recct++;
}
close $file_idx;

ok( $file_idx_recct == 46, 'Correct number of unique pairs found in index' );

while (<$file_int>) {
    chomp;
    my @f = split;
    ok( scalar @f == 3, 'Integer mapping of pairs has the right number of fields' );
    ok($f[0] =~ /\d+/,'Blast pairs mapped correctly to integer form' );
    ok($f[1] =~ /\d+/,'Blast pairs mapped correctly to integer form' );
    ok($f[2] =~ /\d+/,'Blast pairs mapped correctly to integer form' );
    #TODO: Test for unique pairs
    $file_int_recct++;
}
close $file_int;

ok( $file_int_recct == 25, 'Correct number of unique pairs found in integer mapping' );

while (<$file_hs>) {
    chomp;
    my @f = split;
    ok( scalar @f == 3, 'Integer mapping of pairs has the right number of fields' );
    ok($f[2] =~ /\d+/,'Blast pair score mapped parsed correctly' );
    #TODO: Test for unique pairs
    $file_hs_recct++;
}
close $file_hs;

ok( $file_hs_recct == 25, 'Correct number of unique pairs found in ID mapping' );
ok( $file_hs_recct == $file_int_recct, 'Index and integer mapping files contain the same records' );

## check both processing methods agree
ok( $mem_idx_recct == $file_idx_recct, 'In-memory and on-file processing methods generated the same index' );
ok( $mem_int_recct == $file_int_recct, 'In-memory and on-file processing methods generated the integer mapping files' );
ok( $mem_hs_recct == $file_hs_recct, 'In-memory and on-file processing methods generated the same pair file with scores' );

END {
    system("rm -rf $outdir $blfl");
}

done_testing();
