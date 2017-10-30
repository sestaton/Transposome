use 5.010;
use strict;
use warnings;
use Cwd;
use Config;
use Transposome;
use Transposome::Log;
use Transposome::Analysis::Pipeline;
use IPC::System::Simple qw(system);
use File::Path          qw(make_path remove_tree);
use Capture::Tiny       qw(capture);
use File::Basename;
use File::Spec;
use File::Find;
use Getopt::Long;
use Pod::Usage;

use aliased 'Transposome::Test::TestFixture';
use Test::More tests => 4;

my $program  = File::Spec->catfile('bin', 'transposome');
my $seqfile  = File::Spec->catfile('t', 'test_data', 't_reads.fas.gz');
my $repeatdb = File::Spec->catfile('t', 'test_data', 't_db.fas');
my $outdir   = File::Spec->catdir('t', 'test_transposome_cli_out');
my $log      = File::Spec->catfile($outdir, 't_log.txt');

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
my $te_config_obj = $trans_obj->get_configuration;

my $cwd = getcwd();
my $bin = File::Spec->catdir($cwd, 'bin');
$ENV{PATH} = "$bin:$ENV{PATH}";

my $devtests = 0;
if (defined $ENV{TRANSPOSOME_ENV} && $ENV{TRANSPOSOME_ENV} eq 'development') {
    $devtests = 1;
}

SKIP: {
    skip 'skip development tests', 3 unless $devtests;

    unless ( -d $te_config_obj->{output_directory} ) {
    	   make_path( $te_config_obj->{output_directory}, {verbose => 0, mode => 0771,} );
    }

    run_full_analysis( $conf_file, $te_config_obj );

    ok( -d $outdir, 'Output of Transposome created' );
    my @results;
    find( sub { push @results, $File::Find::name if -f and /\.tgz$/ }, $outdir );
    is( scalar(@results), 2, 'Output directories compressed successfully' );

    # just check if the application completed without errors
    open my $in, '<', $log;
    while (my $line = <$in>) {
    	  chomp $line;
    	  if ($line =~ /Transposome completed at/) {
	     like( $line, qr/Transposome completed at/, 
	      	   'Transposome CLI application completed successfully' );
          }
     }
}

remove_tree( $outdir, { safe => 1 } );
unlink $conf_file;
unlink glob "t/transposome_mgblast*";
unlink "formatdb.log";

exit;
#
# Methods
#
sub run_full_analysis {
    my ($config_file, $te_config_obj) = @_;

    # Perform the all vs. all blast
    my ($blastdb, $t0, $log) = run_blast( $config_file, $te_config_obj );

    # parse mglblast results to find best scoring pairwise matches
    my $clsfiles = find_pairs( $config_file, $te_config_obj, $blastdb );
    #dd $clsfiles;

    # Cluster sequences and analyze groupings
    #$opts{idxfile}, $opts{intfile}, $opts{edgefile}
    my $cluster_data = make_clusters( $config_file, $te_config_obj, $clsfiles->{idx}, $clsfiles->{int}, $clsfiles->{edges} );

    # Annotate clusters and generate whole-genome summary of results
    annotate_clusters( $config_file, $te_config_obj, 
		       $cluster_data->{cluster_dir}, $cluster_data->{total_ct}, $cluster_data->{clustered_ct} );

    # Log summary of results
    my $log_obj = Transposome::Log->new( config => $config_file, log_to_screen => 0 );
    $log_obj->log_interval( $t0, $log );

    return;
}

sub run_blast {
    my ($config_file, $te_config_obj) = @_;

    my $log_obj = Transposome::Log->new( config => $config_file, log_to_screen => 0 );
    my ( $t0, $log ) = $log_obj->init_transposome( $te_config_obj );

    #my $cwd = getcwd();
    #my $bin = File::Spec->catdir($cwd, 'bin');
    #local $ENV{PATH} = "$bin:$ENV{PATH}";

    my @out = capture { system([0..5], 'transposome-bl', '--config', $config_file); };

    my $tobj = Transposome::Analysis::Pipeline->new( config => $config_file );
    my $blastdb = $tobj->get_blastdb($te_config_obj);

    return ($blastdb, $t0, $log);
}

sub find_pairs {
    my ($config_file, $te_config_obj, $blastdb) = @_;

    my @out = capture { system([0..5], 'transposome-pf', '--config', $config_file, '--blastdb', $blastdb); };

    my $tobj = Transposome::Analysis::Pipeline->new( config => $config_file );
    my $clsfiles = $tobj->get_cluster_files($te_config_obj);

    return $clsfiles;
}

sub make_clusters {
    my ($config_file, $te_config_obj, $idx, $int, $edges) = @_;

    #say STDERR join "\n", "DEBUG", $idx, $int, $edges;
    my @out = capture { system([0..5], 'transposome-cl', '--config', $config_file, '-int', $int, '-idx', $idx, '-edges', $edges); };

    my $tobj = Transposome::Analysis::Pipeline->new( config => $config_file );
    my $cluster_data = $tobj->get_cluster_data($te_config_obj);

    return $cluster_data;
}

sub annotate_clusters {
    my ($config_file, $te_config_obj, $clsdir, $seqct, $clsct) = @_;
    
    $clsdir =~ s/\/$//;
    my @out = capture { system([0..5], 'transposome-an', '--config', $config_file, '-clsdir', $clsdir, '-seqct', $seqct, '-clsct', $clsct); };

    return;
}

sub usage {
    my $prog = basename($0);
    print STDERR <<END

USAGE: $prog [-c] [-a] [-int] [-idx] [-edges] [-bdb] [-clsdir] [-v] [-h] [-m]

Required:
    -c|config           :    The Transposome configuration file. This is all that is required to run
                             the full analysis. The options below are for individual analysis steps.

Options:
    -a|analysis         :    The type of analysis to perform (Default: all).
    -int|intfile        :    The file containing an index of each sequence 
                             (only required for the 'cluster' analysis).
    -idx|idxfile        :    The file containing an index mapping the sequence ID and the
                             ID used for clustering (only required for the 'cluster' analysis).
    -edges|edgefile     :    The file containing the best pairwise matches and
                             the score (only required for the 'cluster' analysis).
    -bdb|blastdb        :    The all-vs-all BLAST file (only required for the 'findpairs' analysis).
    -clsdir|clusterdir  :    The directory of FASTA files for each cluster 
                             (only required for the 'annotation' analysis).
    -seqct|sequencect   :    The total number of sequences used in the analysis.
                             (only required for the 'annotation' analysis).
    -clsct|clusteredct  :    The total number of clustered sequences.
                             (only required for the 'annotation' analysis).
    -v|version          :    Print the program version and exit.
    -h|help             :    Print a usage statement.
    -m|man              :    Print the full documentation.

Citation: Staton SE, and Burke JM. 2015. Transposome: A toolkit for annotation of transposable element 
          families from unassembled sequence reads. Bioinformatics, 31:1827-1829.

END
}

=head1 REQUIRED ARGUMENTS

=over 2

=item -c, --config

The Transposome configuration file.

=back 

=head1 OPTIONS

=over 2

=item -a, --analysis

The type of analysis to perform. Options are 'all', 'blast', 'findpairs', 'cluster', and 'annotation'. Default: all.

    Analysis type         Description

    all                   Run the full analysis from beginning to end, logging progress of each step.
    blast                 Run only the all-vs-all BLAST comparison.
    findpairs             Parse the all-vs-all BLAST report and find best scoring pairwise matches (to be used in graph construction).
    cluster               Perform the clustering step with the pairwise matches.
    annotation            Run the annotation procedures on a directory cluster FASTA files.

The BLAST step can be greatly accelerated by running on a machine with a large number of processors, but the 'findpairs' and 'cluster' steps often require a large amount of computer memory. For this reason, it is best to separate the steps so you can run the BLAST on a large cluster, then send the 'findpairs' and 'cluster' steps to a high memory machine.

Examples:

1) Run the full analysis. In this case, only the configuration file is required.

    transposome --config transposome_config.yml

2) Run just the BLAST step. Only the configuration file is required for this step.

    transposome --analysis blast --config transposome_config.yml

3) Run the 'findpairs' analysis step. For this analysis, the configuration file and an all-vs-all BLAST file is required.

    transposome --analysis findpairs --config transposome_config.yml --blastdb seqs_allvall_blastdb.bln

4) Run the 'cluster' analysis step. In addition to the configuration file, the three files generated by the 'findpairs' step are required. These files are explained in more detail below.

    transposome --analysis cluster --config transposome_config.yml -int seqs_matches.int -idx seqs_matches.idx -edges seqs_matches.edges

5) Run the 'annotation' analysis step. 

    transposome --analysis annotation --config transposome_config.yml -clsdir seqs_clustered_fasta_files -seqct 100000 -clsct 73400

=item -int, --intfile

The file containing the index of each sequence and match score. This is returned from the parse_blast method in the Transposome::Pairfinder class.

=item -idx, --idxfile

The file containing an index mapping the sequence ID and the sequence index used for clustering. This is returned from the parse_blast method in the Transposome::Pairfinder class.

=item -edges, --edgefile

The file containg the pairwise information for each best scoring match. This is returned from the parse_blast method in the Transposome::Pairfinder class.

=item -bdb, --blastdb

The all-vs-all BLAST report generated from the unassembled sequenc reads. This file is returned from the run_allvall_blast method in the Transposome::Run::Blast class.

=item -clsdir, --clusterdir

A directory containing the FASTA files for each cluster. The PATH to this directory is returned from the merge_clusters method in the Transposome::Cluster class.

=item -seqct, --sequencect

The total number of sequences used in the analysis. This is printed to STDERR and printed in the Results section of the log at the conclusion of the 'cluster' analysis. This option is only required for the separate 'annotation' analysis.

=item -clsct, --clusteredct

The total number of clustered sequences. This is printed to STDERR and printed in the Results section of the log at the conclusion of the 'cluster' analysis. This option is only required for the separate 'annotation' analysis.

=item -v, --version

Print the Transposome version and exit.

=item -h, --help

Print a usage statement. 

=item -m, --man

Print the full documentation.

=back

=head1 AUTHOR

S. Evan Staton, C<< <evan at evanstaton.com> >>

=head1 BUGS

Please report any bugs or feature requests through the project site at 
L<https://github.com/sestaton/Transposome/issues>. I will be notified,
and there will be a record of the issue. Alternatively, I can also be 
reached at the email address listed above to resolve any questions.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc transposome

=head1 CITATION

 Staton SE, and Burke JM. 2017. Transposome: A toolkit for annotation of transposable element 
           families from unassembled sequence reads, Bioinformatics, doi: 10.1093/bioinformatics/btv059

=head1 LICENSE AND COPYRIGHT

Copyright 2013-2017 S. Evan Staton.

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.


=cut
