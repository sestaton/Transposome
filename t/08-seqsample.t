#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use lib qw(../blib/lib t/lib);
use TestUtils;
use Transposome::SeqUtil;
use Transposome::SeqIO;

use Test::More tests => 14;

my $test = TestUtils->new( build_proper => 1, destroy => 0 );

my $fa_arr = $test->fasta_constructor;
my $fq_arr = $test->fastq_constructor;

my ($seqct, $stdoutct, $stdoutct2, $seqs) = (0, 0, 0, {});

for my $fa (@$fa_arr) {
    my $seqio = Transposome::SeqIO->new( file => $fa);
    my $fh = $seqio->get_fh;
    while (my $seq = $seqio->next_seq($fh)) {
	if ($seq->has_id && $seq->has_seq && !$seq->has_qual) {
	    my $memstore = Transposome::SeqUtil->new( file => $fa, sample_size => 2 );
	    ($seqs, $seqct) = $memstore->sample_seq;
	    ok( $seqct == 2, 'There correct number of Fasta sequences were sampled');
	    my $idct = scalar (keys %$seqs);
	    ok( $seqct == $idct, 'The same number of Fasta sequences were sampled and stored');
	}
    }

    my $memstore2 = Transposome::SeqUtil->new( file => $fa, sample_size => 2 , no_store => 1);
    open STDOUT, '>', 'seqsample_t.out';
    $memstore2->sample_seq;

    my $seqio2 = Transposome::SeqIO->new( file => 'seqsample_t.out' );
    my $fh2 = $seqio2->get_fh;
    while (my $seq2 = $seqio2->next_seq($fh2)) {
	$stdoutct++ if $seq2->has_seq;
    }
    ok( $seqct == $stdoutct, 'The same number of Fasta sequences sampled and stored as written to STDOUT' );
    system("rm seqsample_t.out");

    unlink $fa;
    $seqct = 0;
    $stdoutct = 0;
}

for my $fq (@$fq_arr) {
    my $seqio = Transposome::SeqIO->new( file => $fq);
    my $fh = $seqio->get_fh;
    while (my $seq = $seqio->next_seq($fh)) {
        if ($seq->has_id && $seq->has_seq && $seq->has_qual) {
            my $memstore = Transposome::SeqUtil->new( file => $fq, sample_size => 2 );
	    ($seqs, $seqct) = $memstore->sample_seq;
	    ok( $seqct == 2, 'There correct number of Fastq sequences were sampled');
	    my $idct = scalar (keys %$seqs);
	    ok( $seqct == $idct, 'The same number of Fastq sequences were sampled and stored');
        }
    }
    my $memstore2 = Transposome::SeqUtil->new( file => $fq, sample_size => 2 , no_store => 1);
    open STDOUT, '>', 'seqsample_t.out';
    $memstore2->sample_seq;

    my $seqio2 = Transposome::SeqIO->new( file => 'seqsample_t.out' );
    my $fh2 = $seqio2->get_fh;
    while (my $seq2 = $seqio2->next_seq($fh2)) {
        $stdoutct++ if $seq2->has_seq;
    }
    ok( $seqct == $stdoutct, 'The same number of Fastq sequences sampled and stored as written to STDOUT' );
    system("rm seqsample_t.out");

    unlink $fq;
    $seqct = 0;
    $stdoutct = 0;
}

done_testing();
