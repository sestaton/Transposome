package Transposome::Run::Blast;

use 5.012;
use Moose;
use Cwd;
use File::Basename;
use Method::Signatures;
use IPC::System::Simple qw(system capture EXIT_ANY);
use Time::HiRes qw(gettimeofday);
use POSIX qw(strftime);
use File::Temp;
use File::Path qw(make_path);
use Path::Class::File;
use Parallel::ForkManager;
use Try::Tiny;
use Transposome::SeqIO;
use namespace::autoclean;

with 'MooseX::Log::Log4perl',
     'Transposome::Role::File', 
     'Transposome::Role::Types',
     'Transposome::Role::Util';

=head1 NAME

Transposome::Run::Blast - Run all vs. all BLAST to generate graph edges.

=head1 VERSION

Version 0.07.3

=cut

our $VERSION = '0.07.3';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    use Transposome::Run::Blast;

    my $blast = Transposome::Run::Blast->new( file      => 'myseqs.fas',
                                              dir       => 'transposome_results_out',
                                              threads   => 1,
                                              cpus      => 1,
                                              seq_num   => 50_000,
                                              report    => 'blastpm.out' );

   my $blast_file = $blast->run_allvall_blast;

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

has 'seq_num' => (
    is        => 'ro',
    isa       => 'Num',
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

has 'min_overlap' => (
    is        => 'ro',
    isa       => 'Int',
    predicate => 'has_min_overlap',
    lazy      => 1,
    default   => 50,
);

has 'max_mismatch' => (
    is        => 'ro',
    isa       => 'Int',
    predicate => 'has_max_mismatch',
    lazy      => 1,
    default   => 30,
);

has 'formatdb_exec' => (
    is        => 'rw',
    isa       => 'Str',
    reader    => 'get_formatdb_exec',
    writer    => 'set_formatdb_exec',
    predicate => 'has_formatdb_exec',
);

has 'mgblast_exec' => (
    is        => 'rw',
    isa       => 'Str',
    reader    => 'get_mgblast_exec',
    writer    => 'set_mgblast_exec',
    predicate => 'has_mgblast_exec',
);

method BUILD (@_) {
    my @path = split /:|;/, $ENV{PATH};

    for my $p (@path) {
	my $mg = File::Spec->catfile($p, 'mgblast');
	my $fd = File::Spec->catfile($p, 'formatdb');

        if (-e $mg && -x $mg) {
            $self->set_mgblast_exec($mg);
        }
        elsif (-e $fd && -x $fd) {
            $self->set_formatdb_exec($fd);
        }
    }

    try {
        die unless $self->has_mgblast_exec;
    }
    catch {
        $self->log->error("Unable to find mgblast. Check your PATH to see that it is installed. Exiting.")
	    if Log::Log4perl::initialized();
	exit(1);
    };

    try {
        die unless $self->has_formatdb_exec;
    }
    catch {
        $self->log->error("Unable to find formatdb. Check your PATH to see that it is installed. Exiting.")
	    if Log::Log4perl::initialized();
	exit(1);
    };
}

=head1 METHODS

=cut

=head2 run_allvall_blast

 Title : run_allvall_blast
 
 Usage   : my $blast_file = $blast->run_allvall_blast;
           
 Function: Runs all vs. all blast comparison of sequence
           data using mgblast. The output of this blast
           is the input to the clustering methods.
           
                                                                   Return_type
 Returns : File name of the blast_results                          Scalar

 Args    : None. This is a class method called
           on a Transposome::Run::Blast object.

=cut 

method run_allvall_blast {
    my $t0      = gettimeofday();
    my $dir     = $self->dir->absolute;
    my $file    = $self->file->absolute;
    my $cpu     = $self->cpus;
    my $thread  = $self->threads;
    my $numseqs = $self->seq_num;
    my $outfile = $self->file->basename;
    
    $outfile =~ s/\.fa.*//;
    $outfile .= "_allvall_blast.bln";
    make_path($dir, {verbose => 0, mode => 0771,});
    my $out_path = Path::Class::File->new($dir, $outfile);

    # log results
    my $st = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("======== Transposome::Run::Blast::run_allvall_blast started at: $st. Results from mgblast processes to follow.")
	if Log::Log4perl::initialized();

    my ($seq_files, $seqct) = $self->_split_reads($numseqs);
    
    my $database = $self->_make_mgblastdb;
    my $files_ct = @$seq_files;
    my %blasts;

    open my $out, '>>', $out_path or die "\n[ERROR]: Could not open file: $out_path\n";

    my $pm = Parallel::ForkManager->new($thread);
    $pm->run_on_finish( sub { my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_ref) = @_;
			      for my $bl (sort keys %$data_ref) {
				  open my $report, '<', $bl or die "\n[ERROR]: Could not open file: $bl\n";
				  print $out $_ while <$report>;
				  close $report;
				  unlink $bl;
			      }
			      my $t1 = gettimeofday();
			      my $elapsed = $t1 - $t0;
			      my $time = sprintf("%.2f",$elapsed/60);
			      my $base = basename($ident);
			      $self->log->info("$base just finished with PID $pid and exit code: $exit_code in $time minutes.") 
				  if Log::Log4perl::initialized();
			} );

    for my $seqs (@$seq_files) {
	$pm->start($seqs) and next;
	my $blast_out = $self->_run_blast($seqs, $database, $cpu);
	$blasts{$blast_out} = 1;
    
	unlink $seqs;
	$pm->finish(0, \%blasts);
    }

    $pm->wait_all_children;
    close $out;

    my $t2 = gettimeofday();
    my $total_elapsed = $t2 - $t0;
    my $final_time = sprintf("%.2f",$total_elapsed/60);

    $self->log->info("======== Transposome::Run::Blast::run_allvall_blast finished running mgblast on $seqct sequences in $final_time minutes.")
	if Log::Log4perl::initialized();

    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("======== Transposome::Run::Blast::run_allvall_blast completed at: $ft. Final output file is: $outfile.")
	if Log::Log4perl::initialized();
    
    unlink glob("$database*");
    return $out_path;
}

=head2 _make_mgblastdb

 Title : _make_mgblastdb
 
 Usage   : This is private method, do not use it directly.
           
 Function: Creates a BLAST database in the Legacy BLAST format
           for doing an all vs. all BLAST with the program mgblast.

                                                                   Return_type
 Returns : In order, 1) the blast database                         Scalar

 Args    : None. This is a class method called on a 
           Transposome::Run::Blast object.

=cut 

method _make_mgblastdb {
    my $file  = $self->file->absolute;
    my $fname = $self->file->basename;
    my $dir   = $self->dir->absolute; 
    my $formatdb = $self->get_formatdb_exec;
    $fname =~ s/\.fa.*//;
    my $db    = $fname."_allvall_mgblastdb";
    my $db_path = Path::Class::File->new($dir, $db);
    unlink $db_path if -e $db_path;

    try {
        system([0..5],"$formatdb -p F -i $file -t $db -n $db_path 2>&1 > /dev/null");
    }
    catch {
        $self->log->error("Unable to make mgblast database.")
	    if Log::Log4perl::intialized();
        $self->log->error("Here is the exception: $_\nCheck your Legacy BLAST installation. Exiting.")
	    if Log::Log4perl::intialized();
        exit(1);
    };

    return $db_path;
}

=head2 _run_blast

 Title : _run_blast
 
 Usage   : This is private method, do not use it directly.
           
 Function: Runs the program mgblast on each subset of sequences
           based on the conditions set when creating the object.

                                                                   Return_type
 Returns : In order, 1) the blast output file                      Scalar

                                                                   Arg_type
 Args    : In order, 1) the file to run mgblast on                 Scalar
                     2) the database name                          Scalar
                     3) the number of CPUs for each mgblast job    Scalar

=cut 

method _run_blast ($subseq_file, $database, Int $cpu) {
    my ($dbfile, $dbdir, $dbext)    = fileparse($database, qr/\.[^.]*/);
    my ($subfile, $subdir, $subext) = fileparse($subseq_file, qr/\.[^.]*/);
    my $suffix = ".bln";
    my $subseq_out   = Path::Class::File->new($dbdir, $subfile."_".$dbfile.$suffix);

    my $min_overlap  = $self->min_overlap;
    my $max_mismatch = $self->max_mismatch;
    my $pid          = $self->percent_identity;
    my $desc_num     = $self->desc_num;
    my $aln_num      = $self->aln_num;
    my $mgblast      = $self->get_mgblast_exec;

    my $exit_value;
    my @blast_cmd = "$mgblast ".           # program
                    "-i $subseq_file ".    # query
                    "-d $database ".       # db
                    "-F \"m D\" ".         # filter with dust
                    "-D 4 ".               # tab-delimited ouput
                    "-p $pid ".            # min percent identity of match 
                    "-W18 ".               # word size
                    "-UT ".                # use lowercase filtering
                    "-X40 ".               # Xdrop for gapped alignment                             
                    "-KT ".                # database slice
                    "-JF ".                # whether to believe the defline
                    "-v$desc_num ".        # number of descriptions to keep per query
                    "-b$aln_num ".         # number of alignments to keep per query
                    "-C$min_overlap ".     # minimum overlap for matches
                    "-H $max_mismatch ".   # maximum mismatch allowed for matches
                    "-o $subseq_out ".     # output file
                    "-a $cpu ";            # number of cpus assigned 

    try {
        $exit_value = system([0..5], @blast_cmd);
    }
    catch {
        $self->log->error("BLAST exited with exit value $exit_value. Here is the exception: $_.")
	    if Log::Log4perl::intialized();
    };

    return $subseq_out;
}

=head2 _split_reads

 Title : _split_reads
 
 Usage   : This is a private method, do not use it directly.
           
 Function: Splits the input into smaller pieces so
           that mgblast can be run concurrently on 
           each subset.
           
                                                                   Return_type
 Returns : In order, 1) an array of the split file names           ArrayRef
                     2) the total sequence count                   Scalar

                                                                   Arg_type
 Args    : The number of sequences to go into each                 Scalar
           subset 

=cut

method _split_reads (Int $numseqs) {
    my ($iname, $ipath, $isuffix) = fileparse($self->file->absolute, qr/\.[^.]*/);
    my $dir = $self->dir->absolute;

    my $out;
    my $count = 0;
    my $fcount = 1;
    my @split_files;
    $iname =~ s/\.fa.*//;     # clean up file name like seqs.fasta.1

    my $tmpiname = $iname."_".$fcount."_XXXX";
    my $fname = File::Temp->new( TEMPLATE => $tmpiname,
                                 DIR      => $dir,
                                 SUFFIX   => ".fasta",
                                 UNLINK   => 0);

    open $out, '>', $fname or die "\n[ERROR]: Could not open file: $fname\n";
    
    push @split_files, $fname;
    if (-e $self->file) {
        my $filename = $self->file->absolute;
        my $seqio = Transposome::SeqIO->new( file => $filename );
        while (my $seq = $seqio->next_seq) {

	    if ($count % $numseqs == 0 && $count > 0) {
		$fcount++;
		$tmpiname = $iname."_".$fcount."_XXXX";
		$fname = File::Temp->new( TEMPLATE => $tmpiname,
					  DIR      => $dir,
					  SUFFIX   => ".fasta",
					  UNLINK   => 0);
		
		open $out, '>', $fname or die "\n[ERROR]: Could not open file: $fname\n";
		
		push @split_files, $fname;
	    }

	    say $out join "\n", ">".$seq->get_id, $seq->get_seq;
	    $count++;
	}
    }
    close $out;
    return (\@split_files, $count);
}

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests through the project site at 
L<https://github.com/sestaton/Transposome/issues>. I will be notified,
and there will be a record of the issue. Alternatively, I can also be 
reached at the email address listed above to resolve any questions.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::Run::Blast


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2014 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
