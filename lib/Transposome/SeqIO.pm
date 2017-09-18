package Transposome::SeqIO;

use 5.010;
use Moose;
use namespace::autoclean;
#use Class::Load;

with 'Transposome::Role::File';

=head1 NAME

Transposome::SeqIO - Base class for reading FASTA/Q data.

=head1 VERSION

Version 0.11.3

=cut

our $VERSION = '0.11.3';

=head1 SYNOPSIS

    ## Don't use Transposome::SeqIO directly, use as below.
    use Transposome::SeqFactory;

    my $trans_obj = Transposome::SeqFactory->new( file => $infile )->make_seqio_object;

    while (my $seq = $trans_obj->next_seq) {
         # do something interesting with $seq
    }

=cut

has 'id' => (
    is        => 'rw',
    isa       => 'Str',
    reader    => 'get_id',
    writer    => 'set_id',
    predicate => 'has_id',
    clearer   => 'clear_id',
);

has 'seq' => (
    is        => 'rw',
    isa       => 'Str',
    reader    => 'get_seq',
    writer    => 'set_seq',
    predicate => 'has_seq',
    clearer   => 'clear_seq',
);

has 'qual' => (
    is        => 'rw',
    lazy      => 1,
    default   => undef,
    reader    => 'get_qual',
    writer    => 'set_qual',
    predicate => 'has_qual',
    clearer   => 'clear_qual',
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

=head2 set_id_per_encoding

Title   : set_id_per_encoding

Usage   : my $idpair = $obj->set_id_per_encoding($id);
          
Function: Try to determine format of sequence files
          and preserve paired-end information.
                                                               Return_type
Returns : A corrected sequence header if Illumina              Scalar
          Illumina 1.8+ is detected                           
        
                                                               Arg_type
Args    : A sequence header                                    Scalar

=cut

sub set_id_per_encoding {
    my $self = shift;
    my ($id) = @_;
    if ($id =~ /(\S+)\s+(\d):?\S+/) {
        return $1."/".$2;
    }
    elsif ($id =~ /(\S+)/) {
        return $1;
    }
    else {
        return '';
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

    perldoc Transposome::SeqIO


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2017 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
