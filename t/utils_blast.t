#!/usr/bin/env perl

use strict;
use warnings;
use lib qw(../blib/lib t/lib);
use TestUtils;

use Test::More tests => 1;

my $test = TestUtils->new( build_proper => 1, destroy => 1 );
ok( $test->blast_constructor, 'Can build proper mgblast data for testing' );

done_testing();
