package Transposome::SeqUtil;

use 5.012;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use DB_File;
use vars qw($DB_BTREE &R_DUP);  
use Carp;
use Transposome::SeqIO;

with 'MooseX::Log::Log4perl',
     'Transposome::Role::File',
     'Transposome::Role::Types';

=head1 NAME

Transposome::SeqUtil - Utilities for handling Fasta/q sequence files.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

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

subtype 'ModNum'
    => as 'Num'
    => where { /\_/ || /\d+/ };

coerce 'ModNum',
    from 'Str',
    via { $_ =~ s/\_//g; 0+$_ };

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
    predicate => 'has_sample',
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

=head1 METHODS

=head2 store_seq

 Title   : store_seq
 Usage   : my ($seqs, $seq_ct) = $seq_store->store_seq;
          
 Function: Take a Fasta or Fastq file and return a reference
           to a data structure containing the sequences, along
           with the total sequence count.

                                                               Return_type
Returns : In order, 1) a hash containing the id, sequence      HashRef 
                        mappings for each Fasta/q record
                     2) the sequence count                     Scalar

                                                               Arg_type
 Args    : A sequence file                                     Scalar


=cut

sub store_seq {
    my ($self) = @_;
 
    my %seqhash;
    unless ($self->in_memory) {
        $DB_BTREE->{cachesize} = 100000;
        $DB_BTREE->{flags} = R_DUP;
        my $seq_dbm = "transposome_seqstore.dbm";
        unlink $seq_dbm if -e $seq_dbm;
        tie %seqhash, 'DB_File', $seq_dbm, O_RDWR|O_CREAT, 0666, $DB_BTREE
            or die "\nERROR: Could not open DBM file $seq_dbm: $!\n";
    }

    if (-e $self->file) {
	my $filename = $self->file->relative;
	my $seqio = Transposome::SeqIO->new( file => $filename );
	my $fh = $seqio->get_fh;
	while (my $seq = $seqio->next_seq($fh)) {
	    $self->inc_counter if $seq->has_seq;
	    $seqhash{$seq->get_id} = $seq->get_seq;
	}
	return(\%seqhash, $self->counter);
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
    my ($self) = @_;

    my $filename = $self->file->relative;
    my $k = $self->sample_size;
    my $seed = $self->seed;
    my $n = 0;
    my @sample;
    my %seqhash;

    my $seqio_fa = Transposome::SeqIO->new( file => $filename );
    my $seqfh = $seqio_fa->get_fh;

    srand($seed);
    while (my $seq = $seqio_fa->next_seq($seqfh)) {
	$n++;
	push @sample, {$seq->get_id => $seq->get_seq};
	last if $n == $k;
    }

    while (my $seq = $seqio_fa->next_seq($seqfh)) {
	my $i = int rand $n++;
	if ($i < scalar @sample) {
	    $sample[$i] = {$seq->get_id => $seq->get_seq};
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

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests through the project site at 
L<https://github.com/sestaton/Transposome/issues>. I will be notified,
and there will be a record of the issue. Alternatively, I can also be 
reached at the email address listed above to resolve any questions.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::SeqUtil


=head1 LICENSE AND COPYRIGHT

Copyright 2013 S. Evan Staton.

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

__PACKAGE__->meta->make_immutable;
