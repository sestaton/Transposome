#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use Data::Dump qw(dd);
use TestUtils;
use SeqStore;
use SeqIO;

use Test::More tests => 24;

my $test = TestUtils->new( build_proper => 1, destroy => 0 );

my $fa_arr = $test->fasta_constructor;
my $fq_arr = $test->fastq_constructor;

for my $fa (@$fa_arr) {
    my $seqio = SeqIO->new( file => $fa);
    my $fh = $seqio->get_fh;
    while (my $seq = $seqio->next_seq($fh)) {
	if ($seq->has_id && $seq->has_seq && !$seq->has_qual) {
	    my $memstore = SeqStore->new( file => $fa, in_memory => 1 );
	    {
		my ($seqs, $seqct) = $memstore->store_seq;
		ok( $seqct == 3, 'There are exactly three Fasta sequences being stored in memory');
		my $idct = scalar (keys %$seqs);
		ok( $seqct == $idct, 'The same number of Fasta sequences were read and stored in memory');
	    }
	    my $diskstore = SeqStore->new( file => $fa, in_memory => 0 );
	    {
		my ($seqs, $seqct) = $diskstore->store_seq;
		ok( $seqct == 3, 'There are exactly three Fasta sequences being stored on file');
		my $idct = scalar (keys %$seqs);
		ok( $seqct == $idct, 'The same number of Fasta sequences were read and stored on file');
	    }
	}
    }
    unlink $fa;
}

for my $fq (@$fq_arr) {
    my $seqio = SeqIO->new( file => $fq);
    my $fh = $seqio->get_fh;
    while (my $seq = $seqio->next_seq($fh)) {
        if ($seq->has_id && $seq->has_seq && $seq->has_qual) {
            my $memstore = SeqStore->new( file => $fq, in_memory => 1 );
            {
                my ($seqs, $seqct) = $memstore->store_seq;
                ok( $seqct == 3, 'There are exactly three Fastq sequences being stored in memory');
                my $idct = scalar (keys %$seqs);
                ok( $seqct == $idct, 'The same number of Fastq sequences were read and stored in memory');
            }
            my $diskstore = SeqStore->new( file => $fq, in_memory => 0 );
            {
                my ($seqs, $seqct) = $diskstore->store_seq;
                ok( $seqct == 3, 'There are exactly three Fastq sequences being stored on file');
                my $idct = scalar (keys %$seqs);
                ok( $seqct == $idct, 'The same number of Fastq sequences were read and stored on file');
            }
        }
    }
    unlink $fq;
}

done_testing();
