use 5.010;
use strict;
use warnings;
use File::Spec;
use File::Basename;
use File::Path   qw(make_path remove_tree);
use Module::Path qw(module_path);
use Transposome::PairFinder;
use Transposome::Cluster;
use Transposome::SeqUtil;

use aliased 'Transposome::Test::TestFixture';
use Test::More 'no_plan';

my $seqfile = File::Spec->catfile('t', 'test_data', 't_reads.fas.gz');
my $repeatdb = File::Spec->catfile('t', 'test_data', 't_db.fas');
my $outdir  = File::Spec->catdir('t', 'cluster_t');
my $report  = 'cluster_test_rep.txt';

my $test   = TestFixture->new( build_proper => 1, destroy => 0 );
my $blast  = $test->blast_constructor;
my ($blfl) = @$blast;

my $tf_obj_keep = TestFixture->new(
    seq_file         => $seqfile,
    seq_format       => 'fasta',
    repeat_db        => $repeatdb,
    output_directory => $outdir,
    destroy          => 0,
    build_proper     => 1
);

my $keep_conf = $tf_obj_keep->config_constructor;
my ($keep_conf_file) = @$keep_conf;

my $blast_res = Transposome::PairFinder->new(
    config            => $keep_conf_file,
    file              => $blfl,
    dir               => $outdir,
    in_memory         => 1,
    percent_identity  => 90.0,
    fraction_coverage => 0.55,
    verbose           => 0,
    log_to_screen     => 0
);

my ( $idx_file, $int_file, $hs_file ) = $blast_res->parse_blast;

my $path    = module_path("Transposome::Cluster");
my $file    = Path::Class::File->new($path);
my $pdir    = $file->dir;
my $bdir    = Path::Class::Dir->new("$pdir/../../bin");
my $realbin = $bdir->resolve;

my $in_memory = 1;
cluster_analysis($in_memory);

$in_memory = 0;
cluster_analysis($in_memory);
_clean_run($outdir);
unlink $keep_conf_file;

sub cluster_analysis {
    my ($in_memory) = @_;
    my $cluster = Transposome::Cluster->new(
        config          => $keep_conf_file,
	file            => $int_file,
	dir             => $outdir,
	merge_threshold => 0.029,   # 70 * 0.029 = 2
	cluster_size    => 1,
	bin_dir         => $realbin,
	verbose         => 0,
	in_memory       => $in_memory,
	log_to_screen   => 0
    );
    
    ok( $cluster->louvain_method, 'Can perform clustering with Louvain method' );
    
    my $comm = $cluster->louvain_method;
    ok( defined($comm), 'Can successfully perform clustering' );
    
    my $cluster_file = $cluster->make_clusters( $comm, $idx_file );
    ok( defined($cluster_file),
	'Can successfully make communities following clusters' );
    
    {
	local $/ = '>';
	
	my $cls = File::Spec->catfile($outdir, $cluster_file);
	open my $in, '<', $cls;
	while ( my $line = <$in> ) {
	    $line =~ s/>//g;
	    next if !length($line);
	    my ( $clsid, $seqids ) = split /\n/, $line;
	    my ( $id,    $seqct )  = split /\s/, $clsid;
	    my @ids = split /\s+/, $seqids;
	    my $clsct = scalar @ids;
	    
	    if ( $seqct > 1 ) {
		is( $seqct, $clsct, 'Correct number of reads in clusters' );
	    }
	}
	close $in;
    }
    
    my $memstore = Transposome::SeqUtil->new( file => $seqfile, in_memory => 1 );
    my ( $seqs, $seqct ) = $memstore->store_seq;

    my $pair_data =
	$cluster->find_pairs({ cluster_file     => $cluster_file, 
			       cluster_log_file => $report,
			       total_seq_num    => $seqct });

    ok( defined($pair_data->{read_pairs}), 'Can find split paired reads for merging clusters' );
    
    my %merge_args = (
        graph_vertices         => $pair_data->{graph_vertices},
        sequence_hash          => $seqs,
        read_pairs             => $pair_data->{read_pairs},
        cluster_log_file       => $report,
        graph_unionfind_object => $pair_data->{graph_unionfind_object},
    );
    
    if ($in_memory) {
        $merge_args{dbm_file} = $pair_data->{dbm_file};
    }  

    my $cluster_data =
	$cluster->merge_clusters(\%merge_args);
    
    {
	local $/ = '>';

	open my $in, '<', $cluster_data->{merged_cluster_file};
	while ( my $line = <$in> ) {
	    $line =~ s/>//g;
	    next if !length($line);
	    my ( $clsid, $seqids ) = split /\n/, $line;
	    my ( $id,    $seqct )  = split /\s/, $clsid;
	    my @ids = split /\s+/, $seqids;
	    my $clsct = scalar @ids;
	    is( $seqct, $clsct, 'Correct number of reads in merged clusters' );
	}
	close $in;
    }
    
    ok( defined($cluster_data), 'Returned data from cluster merging process' );
    ok( ref($cluster_data) eq 'HASH', 'Returned the correct data type from cluster merging' );

    ok( defined($cluster_data->{cluster_directory}),
	'Can successfully merge communities based on paired-end information' );
    is( $cluster_data->{total_cluster_num}, 46, 'The expected number of reads went into clusters' );
    my $repfile = File::Spec->catfile($outdir, $report);
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
	    #my $second = <$rep>;
	    #chomp $second;
	    ( $g0, $mems1 ) = split /\t/, $first;
	    #( $g1, $mems2 ) = split /\t/, $second;
	    #my $cg0 = $cls11 . "," . $cls12;
	    #my $cg1 = $cls12 . "," . $cls11;
	    #my $cg2 = $cls21 . "," . $cls22;
	    #my $cg3 = $cls22 . "," . $cls21;
	    my $cg = join ",", $cls11, $cls12, $cls21, $cls22;
	    $cg = join ",", sort { $a cmp $b } split /,/, $cg;
	    $mems1 = join ",", sort { $a cmp $b } split /,/, $mems1;
	    #say STDERR "DEBUG: $mems1 => $cg";
	    
	    like( $mems1, qr/$cg/, #qr/$cg0|$cg1|$cg2|$cg3/,
		  'Expected clusters were joined (1)' );
	    #like( $mems2, qr/$cg0|$cg1|$cg2|$cg3/,
		  #'Expected clusters were joined (2)' );
	}
    }
    close $rep;
    
    my $single_ct = 0;
    my $cluster_dir = $cluster_data->{cluster_directory};
    
    my ($singles_file) = glob("$cluster_dir/singletons*.fas");
    ok( defined($singles_file), 'Produced a file of singleton reads' );
    open my $singfh, '<', $singles_file;
    
    while (<$singfh>) {
	$single_ct++ if /^>/;
    }
    close $singfh;
    
    is( $single_ct, 24, 'Expected number of reads went into singletons file' );
    is( $cluster_data->{total_cluster_num} + $single_ct, 70, 
	'Expected number of reads went into clusters and singletons file' );
}

sub _clean_run {
    my ($outdir) = @_;
    remove_tree( $outdir, { safe => 1 } );
    unlink glob("t/*.bln");
}
