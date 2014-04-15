#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use File::Spec;
use File::Basename;
use File::Path qw(make_path remove_tree);
use Module::Path qw(module_path);
use lib qw(../blib/lib t/lib);
use Transposome::PairFinder;
use TestUtils;
use Transposome::Cluster;
use Transposome::SeqUtil;

use Test::More tests => 51;

my $infile = 't/test_data/t_reads.fas';
my $outdir = 't/cluster_t';
my $report = 'cluster_test_rep.txt';
my $test   = TestUtils->new( build_proper => 1, destroy => 0 );
my $blast  = $test->blast_constructor;
my ($blfl) = @$blast;

my $blast_res = Transposome::PairFinder->new(
    file              => $blfl,
    dir               => $outdir,
    in_memory         => 1,
    percent_identity  => 90.0,
    fraction_coverage => 0.55
);

my ( $idx_file, $int_file, $hs_file ) = $blast_res->parse_blast;

my $path    = module_path("Transposome::Cluster");
my $file    = Path::Class::File->new($path);
my $pdir    = $file->dir;
my $bdir    = Path::Class::Dir->new("$pdir/../../bin");
my $realbin = $bdir->resolve;

my $cluster = Transposome::Cluster->new(
    file            => $int_file,
    dir             => $outdir,
    merge_threshold => 2,
    cluster_size    => 1,
    bin_dir         => $realbin
);

ok( $cluster->louvain_method, 'Can perform clustering with Louvain method' );

#diag("Trying Louvain clustering now, this may take a couple of seconds...");
my $comm = $cluster->louvain_method;
ok( defined($comm), 'Can successfully perform clustering' );

my $cluster_file = $cluster->make_clusters( $comm, $idx_file );
ok( defined($cluster_file),
    'Can successfully make communities following clusters' );

{
    local $/ = '>';

    open my $in, '<', "$outdir/$cluster_file";
    while ( my $line = <$in> ) {
        $line =~ s/>//g;
        next if !length($line);
        my ( $clsid, $seqids ) = split /\n/, $line;
        my ( $id,    $seqct )  = split /\s/, $clsid;
        my @ids = split /\s+/, $seqids;
        my $clsct = scalar @ids;

        if ( $seqct > 1 ) {
            ok( $seqct == $clsct, 'Correct number of reads in clusters' );
        }
    }
    close $in;
}

my ( $read_pairs, $vertex, $uf ) =
  $cluster->find_pairs( $cluster_file, $report );
ok( defined($read_pairs), 'Can find split paired reads for merging clusters' );

#diag("Indexing sequences, this will take a few seconds...");
my $memstore = Transposome::SeqUtil->new( file => $infile, in_memory => 1 );
my ( $seqs, $seqct ) = $memstore->store_seq;

#diag("Trying to merge clusters...");
my ( $cls_dir_path, $cls_with_merges_path, $singletons_file_path, $cls_tot ) =
  $cluster->merge_clusters( $vertex, $seqs, $read_pairs, $report, $uf );

{
    local $/ = '>';

    open my $in, '<', $cls_with_merges_path;
    while ( my $line = <$in> ) {
        $line =~ s/>//g;
        next if !length($line);
        my ( $clsid, $seqids ) = split /\n/, $line;
        my ( $id,    $seqct )  = split /\s/, $clsid;
        my @ids = split /\s+/, $seqids;
        my $clsct = scalar @ids;
        ok( $seqct == $clsct, 'Correct number of reads in merged clusters' );
    }
    close $in;
}

ok( defined($cls_dir_path),
    'Can successfully merge communities based on paired-end information' );
is( $cls_tot, 46, 'The expected number of reads went into clusters' );

my $repfile = File::Spec->catfile( $outdir, $report );
open my $rep, '<', $repfile;

my ( $g1, $g0, $cls11, $cls12, $cls21, $cls22, $reads1, $reads2, $mems1,
    $mems2 );
while (<$rep>) {
    chomp;
    if (/^# Cluster connections/) {
        my $first = <$rep>;
        chomp $first;
        my $second = <$rep>;
        chomp $second;
        ( $cls11, $cls12, $reads1 ) = split /\t/, $first;
        ( $cls21, $cls22, $reads2 ) = split /\t/, $second;
        is( $reads1, $reads2,
            'Expected number of reads went into each cluster grouping' );
    }
    if (/^# Cluster groupings/) {
        my $first = <$rep>;
        chomp $first;
        my $second = <$rep>;
        chomp $second;
        ( $g0, $mems1 ) = split /\t/, $first;
        ( $g1, $mems2 ) = split /\t/, $second;
        my $cg0 = $cls11 . "," . $cls12;
        my $cg1 = $cls12 . "," . $cls11;
        my $cg2 = $cls21 . "," . $cls22;
        my $cg3 = $cls22 . "," . $cls21;
        like( $mems1, qr/$cg0|$cg1|$cg2|$cg3/,
            'Expected clusters were joined (1)' );
        like( $mems2, qr/$cg0|$cg1|$cg2|$cg3/,
            'Expected clusters were joined (2)' );
    }
}
close $rep;

my $single_ct = 0;
my ($singles_file) = glob("$cls_dir_path/singletons*.fas");
open my $singfh, '<', $singles_file;

while (<$singfh>) {
    $single_ct++ if /^>/;
}
close $singfh;

is( $single_ct, 24, 'Expected number of reads went into singletons file' );
is( $cls_tot + $single_ct, 70, 'Expected number of reads went into clusters and singletons file' );

END {
    remove_tree( $outdir, { safe => 1 } );
    unlink $blfl;
}
