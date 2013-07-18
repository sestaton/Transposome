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

# We will actually construct this ... 
has database => (
    is      => 'ro',
    isa     => 'Str',
    );

has aln_num => (
    is      => 'ro',
    isa     => 'Int',
    default => 250,
    );

has desc_num => (
    is      => 'ro',
    isa     => 'Int',
    default => 500,
    );

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

sub run_blast {
    my ($self, $subseq_file, $database, $cpu, $blast_program,
        $blast_format, $num_alignments, $num_descriptions,
        $evalue, $warn) = @_;

    ## use file routines from MooseX::Types::Path::Class
    #my ($dbfile,$dbdir,$dbext) = fileparse($database, qr/\.[^.]*/);
    #my ($subfile,$subdir,$subext) = fileparse($subseq_file, qr/\.[^.]*/);
    my $dbfile = $database->file->basename;
    my $dbdir  = $database->file->dir;
    my $subfile = $subseq_file->file->basename;
    my $subdir = $subseq_file->file->dir;

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
                    "-a $cpu ";

    try {
        $exit_value = system([0..5],$blast_cmd);
    }
    catch {
        "\nERROR: BLAST exited with exit value $exit_value. Here is the exception: $_\n";
    };

    return $subseq_out;
}

sub split_reads {
    my ($self, $infile, $outfile, $numseqs) = @_;

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
    my @aux = undef;

    #if (-e $self->file) {
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
    #}
    close $in; close $out;
    return (\@split_files, $count);
}

__PACKAGE__->meta->make_immutable;

1;
