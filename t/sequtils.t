#!/usr/bin/env perl

use strict;
use warnings;
use TestUtils;
use SeqIO;

use Test::More tests => 2;

my $test = TestUtils->new( build_all => 1, destroy => 1 );

ok( $test->fasta_constructor, 'Can build Fasta data for testing' );
ok( $test->fastq_constructor, 'Can build Fastq data for testing' );
