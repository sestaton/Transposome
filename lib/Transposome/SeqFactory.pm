package Transposome::SeqFactory;

use 5.010;
use Moose;
use Method::Signatures;
use namespace::autoclean;
use Class::Load;

with 'Transposome::Role::File';

=head1 NAME

Transposome::SeqIO - Class for reading Fasta/q data.

=head1 VERSION

Version 0.08.3

=cut

our $VERSION = '0.08.3';

=head1 SYNOPSIS

    use Transposome::SeqFactory;

    my $trans_obj = Transposome::SeqFactory->new( file => $infile )->make_seqio_object;

    while (my $seq = $trans_obj->next_seq) {
         # do something interesting with $seq
    }

=cut

method make_seqio_object {
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
        #$self->log->error("Unable to set sequence format. '$unrecognized' is not recognized. Exiting.")
            #if Log::Log4perl::initialized();
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

Copyright (C) 2013-2014 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
