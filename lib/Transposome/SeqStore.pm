package Transposome::SeqStore;

use 5.012;
use Moose;
use namespace::autoclean;
use DB_File;
use vars qw($DB_BTREE &R_DUP);  
use Carp;
use Transposome::SeqIO;

with 'Transposome::Role::File',
     'Transposome::Role::Types';

=head1 NAME

Transposome::SeqStore - Store sequences on disk or in memory.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use Transposome::SeqStore;

    my $seq_store = Transposome::SeqStore->new( file  => 'myseqs.fas',
                                                in_memory => 1,
                                               );

=cut

has 'in_memory' => (
    is         => 'ro',
    isa        => 'Bool',
    predicate  => 'has_in_memory',
    lazy       => 1,
    default    => 0,
    );

=head1 METHODS

=head2 store_seq

 Title   : store_seqs
 Usage   : my ($seqs, $seq_ct) = $seq_store->store_seq;
          
 Function: Take a Fasta or Fastq file and return a reference
           to a data structure containing the sequences, along
           with the total sequence count.

                                                               Data_type
 Returns : A hash containing the id => sequence mappings       HashRef
           for each Fasta/q record

 Args    : A sequence file and the option of specifying        Scalar
           the analysis to be done in memory

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
            or croak "\nERROR: Could not open DBM file $seq_dbm: $!\n";
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

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests through the project site at 
L<https://github.com/sestaton/Transposome/issues>. I will be notified,
and there will be a record of the issue. Alternatively, I can also be 
reached at the email address listed above to resolve any questions.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::SeqStore


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
