package Transposome::SeqUtil;

use 5.010;
use Moose;
use DBI;
use Cwd;
use Tie::Hash::DBD;
use Transposome::SeqFactory;
use feature 'say';
use namespace::autoclean;

with 'Transposome::Role::File',
     'Transposome::Role::Types';

=head1 NAME

Transposome::SeqUtil - Utilities for handling Fasta/q sequence files.

=head1 VERSION

Version 0.12.1

=cut

our $VERSION = '0.12.1';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

For storing all sequences:

    use Transposome::SeqUtil;

    my $sequtil = Transposome::SeqUtil->new( file      => 'myseqs.fas',
                                             in_memory => 1,
                                           );
    my ($seqs, $seqct) = $sequtil->store_seq;

    ...

For sampling a sequence file:

use Transposome::SeqUtil;

    my $sequtil = Transposome::SeqUtil->new( file        => 'myseqs.fas',
                                             sample_size => 500_000,
                                           );

    $sequtil->sample_seq;

=cut

has 'in_memory' => (
    is         => 'ro',
    isa        => 'Bool',
    predicate  => 'has_in_memory',
    lazy       => 1,
    default    => 0,
);

has 'sample_size' => (
    is        => 'ro',
    isa       => 'ModNum',
    predicate => 'has_sample_size',
    coerce    => 1,
);

has 'seed' => (
    is        => 'ro',
    isa       => 'Int',
    predicate => 'has_seed',
    lazy      => 1,
    default   => 11,
);

has 'no_store' => (
    is        => 'ro',
    isa       => 'Bool',
    predicate => 'has_no_store',
    lazy      => 1,
    default   => 0,
);

# this attribute is for dealing with IDs from different platforms (e.g., Illumina, Roche, etc.)
has 'seqtype' => (
    is        => 'ro',
    isa       => 'Str',
    lazy      => 1,
    default   => undef,
    reader    => 'get_seqtype',
    predicate => 'has_seqtype',
);

=head1 METHODS

=head2 store_seq

 Title   : store_seq
 Usage   : my ($seqs, $seq_ct) = $seq_store->store_seq;
          
 Function: Take a FASTA or FASTQ file and return a reference
           to a data structure containing the sequences, along
           with the total sequence count.

                                                               Return_type
 Returns : In order, 1) a hash containing the id, sequence     HashRef 
                        mappings for each FASTA/Q record
                     2) the sequence count                     Scalar
                     3) the DBM file if the indexing is        Scalar
                        not done in memory
                                                               Arg_type
 Args    : A sequence file                                     Scalar


=cut

sub store_seq {
    my $self = shift;
    my %seqhash;
    my $dbh;
    my $seq_dbm;
   
    my $cwd = getcwd();
    my $dir = $self->dir || $cwd; 

    unless ($self->in_memory) {
	$seq_dbm = File::Spec->catfile($dir, "transposome_seqstore.dbm");
        unlink $seq_dbm if -e $seq_dbm;

        my $dbh = DBI->connect("dbi:SQLite:dbname=$seq_dbm", undef, undef, {
            PrintError       => 0, 
            RaiseError       => 1,
            AutoCommit       => 1,
            FetchHashKeyName => 'NAME_lc',
            synchronous      => 0,
            journal_mode     => 'TRUNCATE'
        });

	tie %seqhash, "Tie::Hash::DBD", $dbh;
    }

    my %args = (
	file   => $self->file->relative,
	format => $self->format, 
    );

   if ($self->has_seqtype && $self->get_seqtype =~ /illumina/i) {
       $args{seqtype} = $self->get_seqtype;
   }

    my $seqio = Transposome::SeqFactory->new( %args )->make_seqio_object;

    while (my $seq = $seqio->next_seq) {
	$self->inc_counter if $seq->has_seq;
	$seqhash{$seq->get_id} = $seq->get_seq;
    }

    if ($self->in_memory) {
	return (\%seqhash, $self->counter);
    }
    else {
	return (\%seqhash, $self->counter, $seq_dbm);
    }
}

=head2 sample_seq

 Title   : sample_seq
 Usage   : my ($seqs, $seq_ct) = $sequtil->sample_seq;
          
 Function: Take a Fasta or Fastq file and return a reference
           to a data structure containing the sequences, along
           with the total sequence count.

                                                               Return_type
 Returns : In order, 1) a hash containing the id, sequence     HashRef 
                        mappings for each Fasta/q record
                     2) the sequence count                     Scalar

           If the object is created with the argument
           "no_store => 1" then calling this method causes
           the sequences to simply be written to STDOUT.
                                                               Arg_type
 Args    : A sequence file                                     Scalar

=cut

sub sample_seq {
    my $self = shift;
    # get method vars from class attributes
    my $filename = $self->file->relative;   # file to sample
    my $format   = $self->format;           # sequence format
    my $k        = $self->sample_size;      # sample size
    my $seed     = $self->seed;             # random seed
    my $n        = 0;                       # number of records seen
    my @sample;
    my %seqhash;

    my $seqio_fa;
    if ($self->has_fh) {
        $seqio_fa = Transposome::SeqFactory->new( fh => $filename, format => $format )->make_seqio_object;
    }
    else {
        $seqio_fa = Transposome::SeqFactory->new( file => $filename, format => $format )->make_seqio_object;
    }

    srand($seed);
    while (my $seq = $seqio_fa->next_seq) {
	$n++;
	push @sample, { $seq->get_id => $seq->get_seq };
	last if $n == $k;
    }

    if ($k > $n) {
	warn "\n[ERROR]: Sample size $k is larger than the number of sequences ($n).";  
	warn "Pick a smaller sample size. Exiting.\n";
    }
    else {
        while (my $seq = $seqio_fa->next_seq) {
	    my $i = int rand $n++;
	    if ($i < @sample) {
		$sample[$i] = { $seq->get_id => $seq->get_seq };
	    }
	}

        for my $seq (@sample) {
	    for my $h (keys %$seq) {
		if ($self->no_store) {
		    say join "\n", ">".$h, $seq->{$h};
		}
		else {
		    $self->inc_counter if $seq->{$h};
		    $seqhash{$h} = $seq->{$h};
		}
	    }
	}   
        return (\%seqhash, $self->counter) unless $self->no_store;
    }   
}   

=head1 AUTHOR

S. Evan Staton, C<< <evan at evanstaton.com> >>

=head1 BUGS

Please report any bugs or feature requests through the project site at 
L<https://github.com/sestaton/Transposome/issues>. I will be notified,
and there will be a record of the issue. Alternatively, I can also be 
reached at the email address listed above to resolve any questions.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::SeqUtil


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2017 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
