package Transposome::SeqIO;

use 5.010;
use Moose;
use Method::Signatures;
use namespace::autoclean;
use Class::Load;

with 'Transposome::Role::File';

=head1 NAME

Transposome::SeqIO - Base class for reading Fasta/q data.

=head1 VERSION

Version 0.08.3

=cut

our $VERSION = '0.08.3';

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

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests through the project site at 
L<https://github.com/sestaton/Transposome/issues>. I will be notified,
and there will be a record of the issue. Alternatively, I can also be 
reached at the email address listed above to resolve any questions.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::SeqIO


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
