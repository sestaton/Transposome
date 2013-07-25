#!/usr/bin/env perl

use strict;
use warnings;
use Transposome::t::TestUtils;
use Transposome::SeqIO;

use Test::More tests => 35;

my $test = TestUtils2->new;
my $seq_num = 1;

ok( $test->fasta_constructor(1), 'Can build Fasta data for testing' );
ok( $test->fastq_constructor(1), 'Can build Fastq data for testing' );

my $fa_arr = $test->fasta_constructor(0);
my $fq_arr = $test->fastq_constructor(0);

for my $fa (@$fa_arr) {
    my $seqio_fa = SeqIO->new( file => $fa );
    my $seqfh = $seqio_fa->get_fh;
    while (my $seq = $seqio_fa->next_seq($seqfh)) {
	if ($seq->has_id) {
	    ok( $seq->has_id,     "Fasta sequence $seq_num has an ID" );
	}
	else {
	    ok( ! $seq->has_id,     "Fasta sequence $seq_num does not have an ID" );
	}
	if ($seq->has_seq) {
	    ok( $seq->has_seq,    "Fasta sequence $seq_num has a sequence" );
	}
	else {
	    ok( ! $seq->has_seq,    "Fasta sequence $seq_num does not have a sequence" );
	}
	if (! $seq->has_qual) {
	    ok( ! $seq->has_qual, "Fasta sequence $seq_num does not have quality scores" );
	}
	else {
	    ok( $seq->has_qual, "Fasta sequence $seq_num has quality scores" );
	}
    }
    unlink $fa;
    $seq_num++;
}

for my $fq (@$fq_arr) {
    my $seqio_fq = SeqIO->new( file => $fq );
    my $seqfh = $seqio_fq->get_fh;
    while (my $seq = $seqio_fq->next_seq($seqfh)) {
	if ($seq->has_id) {
	    ok( $seq->has_id,   "Fastq sequence $seq_num has an ID" );
	}
	else {
	    ok( ! $seq->has_id,   "Fastq sequence $seq_num does not have an ID" );
	}
	if ($seq->has_seq) {
	    ok( $seq->has_seq,  "Fastq sequence $seq_num has a sequence" );
	}
	else {
	    ok( ! $seq->has_seq,  "Fastq sequence $seq_num does not have a sequence" );
	}
	if ($seq->has_qual) {
	    ok( $seq->has_qual, "Fastq sequence $seq_num has quality scores" );
	}
	else {
	    ok( ! $seq->has_qual, "Fastq sequence $seq_num does not have quality scores" );
	}
    }
    unlink $fq;
    $seq_num++;
}
