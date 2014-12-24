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

#has 'format' => (
#    is        => 'ro',
#    isa       => 'Str',
#    predicate => 'has_format',
#    default   => 'fasta'
#);

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

Copyright 2013-2014 S. Evan Staton.

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

1;
