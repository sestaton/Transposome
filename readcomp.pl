#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use File::Spec;
use blib;
use Transposome::SeqIO;
#use IO::File;

my $file = File::Spec->catfile('t', 'test_data', 't_reads.fas.gz');
#say $file;
my $seqio_fa = Transposome::SeqIO->new( file => $file );
while ( my $seq = $seqio_fa->next_seq ) {
    say join "\n", $seq->get_id, $seq->get_seq;
}

#my $reader = IO::File->new($ARGV[0], 'r');
