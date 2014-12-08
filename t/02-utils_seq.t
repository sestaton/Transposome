#!/usr/bin/env perl

use strict;
use warnings;
use autodie qw(open);

use aliased 'Transposome::Test::TestFixture';
use Test::More tests => 10;

my ($fact, $fqct) = (0, 0);

my $test = TestFixture->new( build_all => 1, destroy => 1 );
ok( $test->fasta_constructor, 'Can build all Fasta data for testing' );
ok( $test->fastq_constructor, 'Can build all Fastq data for testing' );

my $test2 = TestFixture->new( build_proper => 1, destroy => 1 );
ok( $test2->fasta_constructor, 'Can build proper Fasta data for testing' );
ok( $test2->fastq_constructor, 'Can build proper Fastq data for testing' );

my $test3 = TestFixture->new( build_proper => 1, destroy => 0 );
my $fa_arr = $test3->fasta_constructor;
for my $fa ( @$fa_arr ) {
    open my $fafh, '<', $fa;
    while (<$fafh>) {
	$fact++ if /^>/;
    }
    close $fafh;
    unlink $fa;
    is( $fact, 6, 'Correct number of proper Fasta sequences written' );
    $fact = 0;
}

my $fq_arr = $test3->fastq_constructor;
for my $fq ( @$fq_arr ) {
    open my $fqfh, '<', $fq;
    while (<$fqfh>) {
	$fqct++ if /^\@HWI/;
    }
    close $fqfh;
    unlink $fq;
    is( $fqct, 6, 'Correct number of proper Fastq sequences written' );
    $fqct = 0;
}

my $test4 = TestFixture->new( build_problematic => 1, destroy => 1 );
ok( $test4->fasta_constructor,
    'Can build Fasta data with problems for testing' );
ok( $test4->fastq_constructor,
    'Can build Fastq data with problems for testing' );

my $test5 = TestFixture->new( build_problematic => 1, destroy => 0 );
my $fa_arr2 = $test5->fasta_constructor;
for my $fa ( @$fa_arr2 ) {
    open my $fafh, '<', $fa;
    while (<$fafh>) {
        $fact++ if /^>/;
    }
    close $fafh;
    unlink $fa;
    is( $fact, 2, 'Correct number of problematic Fasta sequences written' );
    $fact = 0;
}

my $fq_arr2 = $test5->fastq_constructor;
for my $fq ( @$fq_arr2 ) {
    open my $fqfh, '<', $fq;
    while (<$fqfh>) {
        $fqct++ if /^\+$/;
    }
    close $fqfh;
    unlink $fq;
    is( $fqct, 2, 'Correct number of problematic Fastq sequences written' );
    $fqct = 0;
}

done_testing();
