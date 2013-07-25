#!/usr/bin/env perl

use strict;
use warnings;
use Transposome::t::TestUtils;

use Test::More tests => 2;

my $test = TestUtils->new;

ok( $test->fasta_constructor(1), 'Can build Fasta data for testing' );
ok( $test->fastq_constructor(1), 'Can build Fastq data for testing' );
