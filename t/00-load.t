#!/usr/bin/env perl

use 5.012;
use strict;
use warnings FATAL => 'all';
use lib qw(../blib/lib);
use Test::More tests => 12;

BEGIN {
    use_ok( 'Transposome' ) || print "Bail out!\n";
    use_ok( 'Transposome::SeqUtil' ) || print "Bail out!\n";
    use_ok( 'Transposome::SeqIO' ) || print "Bail out!\n";
    use_ok( 'Transposome::Cluster' ) || print "Bail out!\n";
    use_ok( 'Transposome::Annotation' ) || print "Bail out!\n";
    use_ok( 'Transposome::PairFinder' ) || print "Bail out!\n";
    use_ok( 'Transposome::Run::Blast' ) || print "Bail out!\n";
}

diag( "Testing Transposome $Transposome::VERSION, Perl $], $^X" );

##See if we can load mgblast, formatdb, and blastn, which are required
my @path = split /:|;/, $ENV{PATH};

my $ex = 0;
for my $p (@path) {
    my $bl = $p."/"."blastn";
    my $mb = $p."/"."makeblastdb";
    if (-e $bl && -x $bl && $bl =~ /ncbi/) {
	$ex++;
	ok(-e $bl && -x $bl, 'blastn exists and is executable');
    }
    if (-e $mb) {
	$ex++;
	ok(-e $mb, 'makeblastdb exists');
    }
    my $mg = $p."/"."mgblast";
    my $fd = $p."/"."formatdb";

    if (-e $mg && -x $mg && -e $fd && -x $fd) {
	$ex++;
	ok(-e $mg && -x $mg, 'mgblast exists and is executable');
	ok(-e $fd && -x $fd, 'formatdb exists and is executable');
	$ex++;
    }
}

is($ex, 4, 'All required external programs for clustering and analysis exist and appear usable');
