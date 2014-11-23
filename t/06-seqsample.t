#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use IPC::System::Simple qw(capture);
use Transposome::SeqUtil;
use Transposome::SeqIO;

use aliased 'Transposome::Test::TestUtils';
use Test::More tests => 8;

my $seqfile  = 'seqsample_t.out';
my $seqfile2 = 'seqsample2_t.out';
my $test = TestUtils->new( build_proper => 1, destroy => 0 );

my $fa_arr = $test->fasta_constructor;
my $fq_arr = $test->fastq_constructor;

my ( $seqct, $seqsamp, $stdoutct, $stdoutct2, $seqs ) = ( 0, 0, 0, 0, {} );

for my $fa (@$fa_arr) {
    my $memstore =
	Transposome::SeqUtil->new( file => $fa, sample_size => 2 );
    ( $seqs, $seqct ) = $memstore->sample_seq;
    is( $seqct, 2,
	'There correct number of Fasta sequences were sampled' );
    my $idct = scalar( keys %$seqs );
    is( $seqct, $idct,
	'The same number of Fasta sequences were sampled and stored' );

    my $memstore2 =
      Transposome::SeqUtil->new( file => $fa, sample_size => 2, no_store => 1 );
    {
        local *STDOUT;
        open STDOUT, '>', $seqfile;
        $memstore2->sample_seq;
    }

    my $seqio2 = Transposome::SeqIO->new( file => $seqfile );
    while ( my $seq2 = $seqio2->next_seq ) {
        $stdoutct++ if $seq2->has_seq;
    }
    is( $seqct, $stdoutct,
        'The same number of Fasta sequences sampled and stored as written to STDOUT'
    );
    unlink $seqfile;

    my $memstore3 =
	Transposome::SeqUtil->new( file => $fa, sample_size => 7, no_store => 1 );
    {
        local *STDOUT;
	local *STDERR;
        open STDOUT, '>', $seqfile;
	open STDERR, '>', $seqfile2; 
        $memstore3->sample_seq;
    }

    open my $sf2, '<', $seqfile2;
    while (<$sf2>) {
	next if ! /\S/;
	if (/^(\[ERROR\])/) {
	    like( $1, qr/[ERROR]/, 'Warn on Fasta sample size being too large' );
	}
    }
    close $sf2;
    unlink $seqfile;
    unlink $seqfile2;
    unlink $fa;

    $seqct    = 0;
    $stdoutct = 0;
}

for my $fq (@$fq_arr) {
    my $memstore =
	Transposome::SeqUtil->new( file => $fq, sample_size => 2 );
    ( $seqs, $seqct ) = $memstore->sample_seq;
    is( $seqct, 2,
	'There correct number of Fastq sequences were sampled' );
    my $idct = scalar( keys %$seqs );
    is( $seqct, $idct,
	'The same number of Fastq sequences were sampled and stored' );

    my $memstore2 =
	Transposome::SeqUtil->new( file => $fq, sample_size => 2, no_store => 1 );
    {
        local *STDOUT;
        open STDOUT, '>', $seqfile;
        $memstore2->sample_seq;
    }
    
    my $seqio2 = Transposome::SeqIO->new( file => $seqfile );
    while ( my $seq2 = $seqio2->next_seq ) {
        $stdoutct++ if $seq2->has_seq;
    }
    ok(
       $seqct == $stdoutct,
       'The same number of Fastq sequences sampled and stored as written to STDOUT'
       );
    unlink $seqfile;

    my $memstore3 =
	Transposome::SeqUtil->new( file => $fq, sample_size => 7, no_store => 1 );
    {
        local *STDOUT;
        local *STDERR;
        open STDOUT, '>', $seqfile;
        open STDERR, '>', $seqfile2; 
        $memstore3->sample_seq;
    }

    open my $sf2, '<', $seqfile2;
    while (<$sf2>) {
        next if ! /\S/;
        if (/^(\[ERROR\])/) {
            like( $1, qr/[ERROR]/, 'Warn on Fastq sample size being too large' );
        }
    }
    close $sf2;
    unlink $seqfile;
    unlink $seqfile2;
    unlink $fq;

    $seqct    = 0;
    $stdoutct = 0;
}

done_testing();
