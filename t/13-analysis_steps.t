#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use Cwd;
use File::Find;
use File::Spec;
use File::Path          qw(remove_tree);
use Capture::Tiny       qw(capture);
use IPC::System::Simple qw(system);
use Transposome;
use Transposome::Run::Blast;

use aliased 'Transposome::Test::TestFixture';
use Test::More tests => 17;

my $program  = File::Spec->catfile('bin', 'transposome');
my $seqfile  = File::Spec->catfile('t', 'test_data', 't_reads.fas.gz');
my $repeatdb = File::Spec->catfile('t', 'test_data', 't_db.fas');
my $outdir   = File::Spec->catdir('t', 'test_transposome_cli_out');
my $script   = "perl -Iblib/lib $program";

my $test = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1
);

my $conf = $test->config_constructor;
my ($conf_file) = @$conf;
my $trans_obj = Transposome->new( config => $conf_file );
ok( $trans_obj->get_configuration, 'Configuration data loaded from file correctly' );
my $config = $trans_obj->get_configuration;

my $cwd = getcwd();
my $bin = File::Spec->catdir($cwd, 'bin');
local $ENV{PATH} = "$bin:$ENV{PATH}";

# run each analysis method
my $allok = full_analysis($script, $conf_file);
my $blastdb = blast_analysis($script, $conf_file, $outdir);
my ($int_file, $idx_file, $edge_file) = findpairs_analysis($script, $conf_file, $outdir, $blastdb);
my ($clsdir, $seqtot, $clstot) = cluster_analysis($script, $conf_file, $outdir, $int_file, $idx_file, $edge_file);
my $annotok = annotation_analysis($script, $conf_file, $outdir, $clsdir, $seqtot, $clstot);

# clean up
remove_tree( $outdir, { safe => 1 } );
unlink $conf_file;

#
# Methods
#
sub full_analysis {
    my ($script, $conf_file) = @_;

    my ($stdout, $stderr, @res) = capture { system([0..5], "$script --config $conf_file"); };

    ok( -d $outdir, 'Output of Transposome created' );

    # just check if the application completed without errors
    for my $line (split /^/, $stderr) {
	chomp $line;
	if ($line =~ /Transposome completed at/) {
	    like( $line, qr/Transposome completed at/, 
		  'Transposome CLI application completed successfully' );
	}
    }

    my @results;
    find( sub { push @results, $File::Find::name if -f and /\.tgz$/ }, $outdir );
    is( scalar(@results), 2, 'Output directories compressed successfully' );
    
    remove_tree( $outdir, { safe => 1 } );
    unlink glob "t/transposome_mgblast*";
    return $stderr;
}

sub blast_analysis {
    my ($script, $conf_file, $outdir) = @_;

    $script .= " --analysis blast --config $conf_file";
    my ($stdout, $stderr, @res) = capture { system([0..5], "$script"); };

    my @files;
    find( sub {
	push @files, $File::Find::name if -f and /\.bln$/
	  }, $outdir );

    my $blastdb = shift @files;
    ok( -s $blastdb, 'Can run BLAST analysis' );
    return $blastdb;
}

sub findpairs_analysis {
    my ($script, $conf_file, $outdir, $blastdb) = @_;

    $script .= " --analysis findpairs --config $conf_file --blastdb $blastdb";
    my ($stdout, $stderr, @res) = capture { system([0..5], "$script"); };

    my @files;
    find( sub {
        push @files, $File::Find::name if -f and /\.int$|\.idx$|\.edges$/
          }, $outdir );

    my ($int_file, $idx_file, $edge_file);
    for my $idfile (@files) {
	like( $idfile, qr/\.int$|\.idx$|\.edges$/, 'Can create mapping file for clustering' );
	ok( -s $idfile, 'Mapping file for clustering has nonzero size' );
	$int_file = $idfile if $idfile =~ /\.int$/;
	$idx_file = $idfile if $idfile =~ /\.idx$/;
	$edge_file = $idfile if $idfile =~ /\.edges$/;
    }
    return ($int_file, $idx_file, $edge_file);
}

sub cluster_analysis {
    my ($script, $conf_file, $outdir, $int_file, $idx_file, $edge_file) = @_;

    $script .= " --analysis cluster --config $conf_file";
    $script .= " -int $int_file -idx $idx_file -edges $edge_file";
    my ($stdout, $stderr, @res) = capture { system([0..5], "$script"); };
    
    my (@files, @dirs, @fastas);
    find( sub { push @dirs, $File::Find::name if -d and /cls_fasta_files/ }, $outdir );
    my $clsdir = shift @dirs;

    find( sub { push @files, $File::Find::name if -f and /\.txt$|\.cls$|\.log$/ }, $outdir );
    find( sub { push @fastas, $File::Find::name if -f and /\.fas$/ }, $clsdir );
    my $singles_file;

    my ($clstot, $singtot);
    for my $fas (@fastas) {
	if ($fas =~ /singletons_(\d+)\.fas$/) {
	    $singtot = $1;
	    $singles_file = $fas;
	}
	elsif ($fas =~ /(\d+)\.fas$/) {
	    $clstot += $1;
	}
    }
    my $seqtot = $clstot + $singtot;

    is( $seqtot,  70, 'Correct number of sequences analyzed' );
    is( $clstot,  48, 'Correct number of sequences clustered' );
    is( $singtot, 22, 'Correct number of singleton sequences' );
    is( @files,    4, 'Correct number of log files generated' );
    is( @fastas,  19, 'Correct number of clusters produced' );

    return ($clsdir, $seqtot, $clstot);
}

sub annotation_analysis {
    my ($script, $conf_file, $outdir, $clsdir, $seqct, $cls_tot) = @_;

    $script .= " --analysis annotation --config $conf_file --clsdir $clsdir -seqct $seqct -clsct $cls_tot";

    my ($stdout, $stderr, @res) = capture { system([0..5], "$script"); };
    #say $stderr;

    my @files;
    find( sub { push @files, $File::Find::name if -f and /\.tgz$/ }, $outdir );

    is( @files, 2, 'Expected compressed results directories produced' );
    return $stderr;
}
