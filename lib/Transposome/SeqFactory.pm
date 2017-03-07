package Transposome::SeqFactory;

use 5.010;
use Moose;
use namespace::autoclean;
use Class::Load;

with 'Transposome::Role::File';

=head1 NAME

Transposome::SeqFactory - Class for constructing a Transposome::SeqIO object for reading FASTA/Q data.

=head1 VERSION

Version 0.10.1

=cut

our $VERSION = '0.10.1';

=head1 SYNOPSIS

    use Transposome::SeqFactory;

    my $trans_obj = Transposome::SeqFactory->new( file => $infile )->make_seqio_object;

    while (my $seq = $trans_obj->next_seq) {
         # do something interesting with $seq
    }

=cut

=head2 make_seqio_objectq

 Title   : make_seqio_object
 Usage   : my $seqio = $seqfactory_object->make_seqio_object;
           
 Function: Evaluate the arguments to the SeqFactory constructur and return
           a SeqIO object for reading sequence data.
                                                                            
 Returns : A Transposome::SeqIO object on which you can call methods                  
           representing the sequence, id, or quality scores (in the
           case of FASTQ). E.g.,
           
           while (my $seq = $trans_obj->next_seq) { 
               $seq->get_id;   # gets the sequence id
               $seq->get_seq;  # gets the sequence
               $seq->get_qual; # gets the quality scores
           }

           Each of the above methods an easy way of checking to see
           if that slot is set. E.g.,
           
           if ($seq->has_id)   { ... # is the id set? }
           if ($seq->has_seq)  { ... # is the seq set? }
           if ($seq->has_qual) { ... # is the qual set? This will be no for FASTA. }

 Args    : None. This is a class method called on a Transposome::SeqFactory object.
 
           my $seqio = Transposome::SeqFactory->new( file => $infile )->make_seqio_object;

=cut

sub make_seqio_object {
    my $self = shift;
    if ($self->format =~ /fasta/i) {
	Class::Load::load_class('Transposome::SeqIO::fasta');
	  return Transposome::SeqIO::fasta->new( fh   => $self->fh,   format => $self->format ) if defined $self->fh;
	  return Transposome::SeqIO::fasta->new( file => $self->file, format => $self->format ) if !defined $self->fh;
      }
    elsif ($self->format =~ /fastq/i) {
	Class::Load::load_class('Transposome::SeqIO::fastq');
	  return Transposome::SeqIO::fastq->new( fh   => $self->fh,   format => $self->format ) if defined $self->fh;
          return Transposome::SeqIO::fastq->new( file => $self->file, format => $self->format ) if !defined $self->fh;
      }
    else {
        my $unrecognized = $self->format;
        say STDERR "Unable to set sequence format. '$unrecognized' is not recognized. Exiting.";
        exit(1);
    }
};

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests through the project site at 
L<https://github.com/sestaton/Transposome/issues>. I will be notified,
and there will be a record of the issue. Alternatively, I can also be 
reached at the email address listed above to resolve any questions.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::SeqFactory


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2015 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
