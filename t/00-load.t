#!/usr/bin/env perl

use 5.012;
use strict;
use warnings FATAL => 'all';
use lib qw(../blib/lib);
use Test::More tests => 12;

BEGIN {
    use_ok('Transposome') || print "[Error]: Could not load Transposome.\n";
    use_ok('Transposome::SeqUtil')
      || print "[Error]: Could not load Transposome::SeqUtil.\n";
    use_ok('Transposome::SeqIO')
      || print "[Error]: Could not load Transposome::SeqIO.\n";
    use_ok('Transposome::Cluster')
      || print "[Error]: Could not load Transposome::Cluster.\n";
    use_ok('Transposome::Annotation')
      || print "[Error]: Could not load Transposome::Annotation.\n";
    use_ok('Transposome::PairFinder')
      || print "[Error]: Could not load Transposome::PairFinder.\n";
    use_ok('Transposome::Run::Blast')
      || print "[Error]: Could not load Transposome::Run::Blast.\n";
}

diag("Testing Transposome $Transposome::VERSION, Perl $], $^X");

##See if we can load mgblast, formatdb, and blastn, which are required
my @path = split /:|;/, $ENV{PATH};

say "PATH: ",$ENV{PATH};

my $ex = 0;
for my $p (@path) {
    my $bl = $p . "/" . "blastn";
    my $mb = $p . "/" . "makeblastdb";
    if ( -e $bl && -x $bl ) {
        $ex++;
        say "We have blasn";
        ok( -e $bl && -x $bl, 'blastn exists and is executable' );
    }
    if ( -e $mb && -x $mb ) {
        $ex++;
        say "We have mbdb";
        ok( -e $mb, 'makeblastdb exists' );
    }
    my $mg = $p . "/" . "mgblast";
    my $fd = $p . "/" . "formatdb";
    #my $mg = 'mgblast';
    #my $fd = 'formatdb';

    if ( -e $fd && -x $fd ) { 
        $ex++;
        say "formatdb";
        #ok( -e $mg && -x $mg, 'mgblast exists and is executable' );
        ok( -e $fd && -x $fd, 'formatdb exists and is executable' );
        #$ex++;
    }
    if ( -e $mg && -x $mg ) {
       $ex++;
       say "We have mgblast";
       ok( -e $mg && -x $mg, 'mgblast exists and is executable' ); 
    }
}

is( $ex, 4,
    'All required external programs for clustering and analysis exist and appear usable'
);
