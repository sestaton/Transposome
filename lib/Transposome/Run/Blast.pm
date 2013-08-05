package Blast;

use 5.012;
use Moose;
use File::Basename;
use namespace::autoclean;
use IPC::System::Simple qw(system capture EXIT_ANY);
use Time::HiRes qw(gettimeofday);
use File::Temp;
use File::Path qw(make_path);
use Path::Class::File;
use Try::Tiny;
use SeqIO;

with 'File', 
     'Types';

=head1 SYNOPSIS

    use Transposome::Run::Blast;

    my $blast = Transposome::Run::Blast->new( file      => 'myseqs.fas',
                                              dir       => 'transposome_results_out',
                                              threads   => 1,
                                              cpus      => 1,
                                              seq_num   => 50_000 );

=cut

has 'aln_num' => (
    is        => 'ro',
    isa       => 'Int',
    predicate => 'has_aln_num',
    lazy      => 1,
    default   => 90000000,
    );

has 'desc_num' => (
    is        => 'ro',
    isa       => 'Int',
    predicate => 'has_desc_num',
    lazy      => 1,
    default   => 90000000,
    );

has 'cpus' => (
    is        => 'ro',
    isa       => 'Int',
    predicate => 'has_cpus',
    lazy      => 1,
    default   => 1,
    );

has 'threads' => (
    is        => 'ro',
    isa       => 'Int',
    predicate => 'has_threads',
    lazy      => 1,
    default   => 1,
    );

has 'seq_num' => (
    is        => 'ro',
    isa       => 'Int',
    predicate => 'has_seq_num',
    required  => 1,
    );

has 'percent_identity' => (
    is        => 'ro',
    isa       => 'Num',
    predicate => 'has_percent_identity',
    lazy      => 1,
    default   => 85.0,
    );


=head1 METHODS

=cut

=head2 make_mgblastdb

 Title : make_mgblastdb
 
 Usage   : my $mgblastdb = $blast->make_mgblastdb;
           
 Function: Creates a BLAST database in the Legacy BLAST format
           for doing an all vs. all BLAST with the program mgblast.

                                                                   Return_type
 Returns : In order, 1) the blast database                         Scalar

 Args    : None. This is a class method called on a 
           Transposome::Run::Blast object.

=cut 

sub make_mgblastdb {
    my ($self) = @_;

    my $file  = $self->file->absolute;
    my $fname = $self->file->basename;
    my $dir   = $self->dir->absolute; 
    my $db    = $fname."_allvall_mgblastdb";
    unless (-d $self->dir) {
	make_path($self->dir, {verbose => 0, mode => 0771,});
    }
    my $db_path = Path::Class::File->new($dir, $db);
    unlink $db_path if -e $db_path;

    my $exit_value;
    try {
        $exit_value = system([0..5],"formatdb -p F -i $file -t $db -n $db_path 2>&1 > /dev/null");
    }
    catch {
        warn "\n[ERROR]: Unable to make mgblast database. Exited with exit value: $exit_value.";
        warn "[ERROR]: Here is the exception: $_\nCheck your Legacy BLAST installation. Exiting.\n";
        exit(1);
    };

    return $db_path;
}

#sub process_all_blasts {
#    my ($self) = @_;

#    my $t0 = gettimeofday();
#    #$cpu = defined($cpu) ? $cpu : '1';          # we are going to set defaults this way
#    #$thread = defined($thread) ? $thread : '1'; # to work with Perl versions released prior to 5.10

#    my $file = $self->file->absolute;
#    my $cpu = $self->cpus;
#    my $thread = $self->threads;
#    my $numseqs = $self->seq_num;
#    my $outfile = $self->file->relative;
#    $outfile .= "_allvall_blast.bln";
#    my ($seq_files, $seqct) = $self->_split_reads($file, $outfile, $numseqs);

#    open my $out, '>>', $outfile or die "\n[ERROR]: Could not open file: $outfile\n"; 

#    my $pm = Parallel::ForkManager->new($thread);
#    $pm->run_on_finish( sub { my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_ref) = @_;
#			      for my $bl (sort keys %$data_ref) {
#				  open my $report, '<', $bl or die "\n[ERROR]: Could not open file: $bl\n";
#				  print $out $_ while <$report>;
#				  close $report;
#				  unlink $bl;
#			      }
#			      my $t1 = gettimeofday();
#			      my $elapsed = $t1 - $t0;
#			      my $time = sprintf("%.2f",$elapsed/60);
#			      say basename($ident)," just finished with PID $pid and exit code: $exit_code in $time minutes";
#			} );

#    for my $seqs (@$seq_files) {
#	$pm->start($seqs) and next;
#	my $blast_out = run_blast($seqs,$database,$cpu,$blast_program,$blast_format,$num_alignments,$num_descriptions,$evalue);
#	$blasts{$blast_out} = 1;
#    
#	unlink($seqs);
#	$pm->finish(0, \%blasts);
#    }

#    $pm->wait_all_children;

#    close($out);

#    my $t2 = gettimeofday();
#    my $total_elapsed = $t2 - $t0;
#    my $final_time = sprintf("%.2f",$total_elapsed/60);

#    print "\n========> Finihsed running BLAST on $seqct sequences in $final_time minutes\n";
#}

#sub run_blast {
#    my ($self, $subseq_file, $database, $cpu,,
#        $num_alignments, $num_descriptions,
#         $warn) = @_;

    ## use file routines from MooseX::Types::Path::Class
#    my ($dbfile,$dbdir,$dbext) = fileparse($database, qr/\.[^.]*/);
#    my ($subfile,$subdir,$subext) = fileparse($subseq_file, qr/\.[^.]*/);

#    my $suffix;
#    if ($blast_format == 8) {
#        $suffix = ".bln";
#    }
#    elsif ($blast_format == 7) {
#        $suffix = ".blastxml";
#    }
#    elsif ($blast_format == 0) {
#        $suffix = ".$blast_program";
#    }
#    my $subseq_out = $subfile."_".$dbfile.$suffix;

#    my ($blast_cmd, $exit_value);
#    my $blast_cmd = . "mgblast ".
#                    "-i $subseq_file ".
#                    "-d $database ".
#                    "-F \"m D\" ".
#                    "-D 4 ".
#                    "-p 85 ".
#                    "-W18 ".
#                    "-UT ".
#                    "-X40 ".
#                    "-KT ".
#                    "-JF ".
#                    "-v90000000 ".
#                    "-b90000000 ".
#                    "-C50 ".
#                    "-H 30 ".
#                    "-o $subseq_out ".
#                    "-a $cpu ";

#    try {
#        $exit_value = system([0..5],$blast_cmd);
#    }
#    catch {
#        "\nERROR: BLAST exited with exit value $exit_value. Here is the exception: $_\n";
#    };

#    return $subseq_out;
#}

sub _split_reads {
    my ($self, $infile, $outfile, $numseqs) = @_;

    my ($iname, $ipath, $isuffix) = fileparse($infile, qr/\.[^.]*/);
    
    my $out;
    my $count = 0;
    my $fcount = 1;
    my @split_files;
    $iname =~ s/\.fa.*//;     # clean up file name like seqs.fasta.1
    
    my $cwd = getcwd();

    my $tmpiname = $iname."_".$fcount."_XXXX";
    my $fname = File::Temp->new( TEMPLATE => $tmpiname,
                                 DIR      => $cwd,
                                 SUFFIX   => ".fasta",
                                 UNLINK   => 0);

    open $out, '>', $fname or die "\nERROR: Could not open file: $fname\n";
    
    push @split_files, $fname;
    open my $in, '<', $infile or die "\nERROR: Could not open file: $infile\n";
    my @aux = undef;

    if (-e $self->file) {
        my $filename = $self->file->basename;
        my $seqio = SeqIO->new( file => $filename );
        my $fh = $seqio->get_fh;
        while (my $seq = $seqio->next_seq($fh)) {

	    if ($count % $numseqs == 0 && $count > 0) {
		$fcount++;
		$tmpiname = $iname."_".$fcount."_XXXX";
		my $fname = File::Temp->new( TEMPLATE => $tmpiname,
					     DIR      => $cwd,
					     SUFFIX   => ".fasta",
					     UNLINK   => 0);
		
		open $out, '>', $fname or die "\nERROR: Could not open file: $fname\n";
		
		push @split_files, $fname;
	    }
	    #say $out join "\n", ">".$name, $seq;
	    say $out join "\n", ">".$seq->id, $seq->seq;
	    $count++;
	}
    }
    close $in; close $out;
    return (\@split_files, $count);
}

__PACKAGE__->meta->make_immutable;

1;
