#!/usr/bin/env perl

use 5.012;
use strict;
use warnings FATAL => 'all';
use Test::More;

use lib qw(../blib/lib);
# Ensure a recent version of Test::Pod::Coverage and Pod::Coverage

my $min_tpc = 1.08;
my $min_pc = 0.18;
eval "use Test::Pod::Coverage $min_tpc; use Pod::Coverage $min_pc";
plan skip_all => "Test::Pod::Coverage $min_tpc and Pod::Coverage $min_pc required for testing POD coverage"
    if $@;

my $trustme = { trustme => [qr/^(EXIT_ANY)$/] };
pod_coverage_ok("Transposome");
pod_coverage_ok("Transposome::Annotation", $trustme);
pod_coverage_ok("Transposome::Cluster", $trustme);
pod_coverage_ok("Transposome::PairFinder");
pod_coverage_ok("Transposome::SeqIO");
pod_coverage_ok("Transposome::SeqUtil");
pod_coverage_ok("Transposome::Run::Blast");

done_testing();
