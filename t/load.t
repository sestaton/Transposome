#!/usr/bin/env perl

use 5.012;
use strict;
use warnings FATAL => 'all';
use lib qw(../blib/lib);
use Test::More tests => 6;

BEGIN {
    use_ok( 'Transposome' ) || print "Bail out!\n";
    use_ok( 'Transposome::SeqUtil' ) || print "Bail out!\n";
    use_ok( 'Transposome::SeqIO' ) || print "Bail out!\n";
    use_ok( 'Transposome::Cluster' ) || print "Bail out!\n";
    use_ok( 'Transposome::Annotation' ) || print "Bail out!\n";
    use_ok( 'Transposome::PairFinder' ) || print "Bail out!\n";
}

diag( "Testing Transposome $Transposome::VERSION, Perl $], $^X" );
