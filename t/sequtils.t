#!/usr/bin/env perl

use strict;
use warnings;
use lib qw(../blib/lib ../t/lib);
use TestUtils;
use Data::Dump qw(dd);

use Test::More tests => 7;

my $test = TestUtils->new( build_all => 1, destroy => 1 );
ok( $test->fasta_constructor, 'Can build all Fasta data for testing' );
ok( $test->fastq_constructor, 'Can build all Fastq data for testing' );

my $test2 = TestUtils->new( build_proper => 1, destroy => 1 );
ok( $test2->fasta_constructor, 'Can build proper Fasta data for testing' );
ok( $test2->fastq_constructor, 'Can build proper Fastq data for testing' );

my $test3 = TestUtils->new( build_problematic => 1, destroy => 1 );
ok( $test3->fasta_constructor, 'Can build Fasta data with problems for testing' );
ok( $test3->fastq_constructor, 'Can build Fastq data with problems for testing' );

my $test4 = TestUtils->new( build_proper => 1, destroy => 1 );
ok( $test4->blast_constructor, 'Can build proper mgblast data for testing' );

done_testing();
