#!perl -T
use 5.012;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 6;

BEGIN {
    use_ok( 'Transposome' ) || print "Bail out!\n";
    use_ok( 'Transposome::SeqStore' ) || print "Bail out!\n";
    use_ok( 'Transposome::Util' ) || print "Bail out!\n";
    use_ok( 'Transposome::Cluster' ) || print "Bail out!\n";
    use_ok( 'Transposome::Annotation' ) || print "Bail out!\n";
    use_ok( 'Transposome::PairFinder' ) || print "Bail out!\n";
}

diag( "Testing Transposome $Transposome::VERSION, Perl $], $^X" );
