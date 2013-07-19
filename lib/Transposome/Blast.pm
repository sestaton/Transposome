package Blast;

use 5.012;
use Moose;
#use File::Basename;  # Moose equivalent, oh yeah, my file type
use namespace::autoclean;
use SeqIO;
with 'Types', 'File';

=head1 SYNOPSIS

    use Transposome::Blast;

    my $blast_obj = Transposome::Blast->new( file       => 'myseqs.fas',
                                             seq_num    => 1_000_000,
                                             aln_num    => 250,
                                             desc_num   => 500, 
                                             cpus       => 2, 
                                             threads    => 12,
                                            );

=head1 ATTRIBUTES

'file'  - Takes the name of a Fasta/q file as the argument.


=cut

has cpus => (
    is      => 'ro',
    is      => 'Int',
    default => 1,
    );

has threads => (
    is      => 'ro',
    isa     => 'Int',
    default => 1,
    );

has seq_num => (
    is   => 'ro',
    isa  => 'Int',
    );

=head1 METHODS

=cut

sub run_allvall_blast {
    my ($self, $infile, $seq_num) = @_;
    
    my $database = $self->_make_db($infile);
   
    my ($seq_files, $seqct) = $self->_split_reads($infile,$numseqs);

    open my $out, '>>', $outfile or die "\nERROR: Could not open file: $outfile\n"; 

    my $pm = Parallel::ForkManager->new($thread);
    $pm->run_on_finish( sub { my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_ref) = @_;
			      for my $bl (sort keys %$data_ref) {
				  open my $report, '<', $bl or die "\nERROR: Could not open file: $bl\n";
				  print $out $_ while <$report>;
				  close $report;
				  unlink $bl;
			      }
			      my $t1 = gettimeofday();
			      my $elapsed = $t1 - $t0;
			      my $time = sprintf("%.2f",$elapsed/60);
			      print basename($ident)," just finished with PID $pid and exit code: $exit_code in $time minutes\n";
			} );
    
    for my $seqs (@$seq_files) {
	$pm->start($seqs) and next;
	my $blast_out = $self->_run_blast($seqs,$database,$cpu);
	$blasts{$blast_out} = 1;
    
	unlink $seqs;
	$pm->finish(0, \%blasts);
    }
    
    $pm->wait_all_children;

    close $out;
    
}

sub _make_db {
    my ($self, $file) = @_;
    #my $formadb_cmd = $self->formatdb;
    my $basename = $file->file->basename;
    my $db = $basename."_blastdb";
    unlink $db if -e $db;
    my $formatdb_cmd = "formatdb -p F -i $file -n $db";
    my $exit_value;
    try {
	$exit_value = system([0..5], $formdb_cmd);
    }
    catch {
	 say "\nERROR: formatdb exited with exit value $exit_value. Here is the exception: $_\n";
    };
    return $db;
}

sub _run_blast {
    my ($self, $subseq_file, $database) = @_;
    
    my $cpus = $self->cpus;
    my $dbfile = $database->file->basename;
    my $subfile = $subseq_file->file->basename;
    my $suffix = ".bln";
    my $subseq_out = $subfile."_".$dbfile.$suffix;

    my ($niceload, $blast_cmd, $exit_value);
    $niceload  = "niceload --noswap --hard --run-mem 10g";
    my $blast_cmd = "$niceload ".
                    "mgblast ".
                    "-i $subseq_file ".
                    "-d $database ".
                    "-F \"m D\" ".
                    "-D 4 ".
                    "-p 85 ".
                    "-W18 ".
                    "-UT ".
                    "-X40 ".
                    "-KT ".
                    "-JF ".
                    "-v90000000 ".
                    "-b90000000 ".
                    "-C50 ".
                    "-H 30 ".
                    "-o $subseq_out ".
                    "-a $cpus ";

    try {
        $exit_value = system([0..5],$blast_cmd);
    }
    catch {
        "\nERROR: mgblast exited with exit value $exit_value. Here is the exception: $_\n";
    };

    return $subseq_out;
}

sub _split_reads {
    my ($self, $infile, $numseqs) = @_;

    #my ($iname, $ipath, $isuffix) = fileparse($infile, qr/\.[^.]*/);
    my $iname = $infile->file->basename;
    my $ipath = $infile->file->dir;

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

	say $out join "\n", ">".$seq->id, $seq->seq;
	$count++;
    }
    close $in; close $out;
    return (\@split_files, $count);
}

__PACKAGE__->meta->make_immutable;

1;
