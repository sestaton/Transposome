#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use Blast;

my $blast = Blast->new( file      => 'Phoeb_330164_interl.fasta',
			dir       => 'transposome_results_out',
			threads   => 1,
			cpus      => 1,
			seq_num   => 50_000 );

my $blastdb = $blast->make_mgblastdb;

say $blastdb;
