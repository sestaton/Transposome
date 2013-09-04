package Transposome::SeqIO;

use 5.012;
use Moose;
use Try::Tiny;
use Carp;
use namespace::autoclean;

with 'Transposome::Role::File';

=head1 NAME

Transposome::SeqIO - Class for reading Fasta/q data.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use Transposome::SeqIO;

    my $trans_obj = Transposome::SeqIO->new( file => $infile );
    my $fh = $trans_obj->get_fh;

    while (my $seq = $trans_obj->next_seq($fh)) {
         # do something interesting with $seq
    }

=cut

has 'id' => (
    is        => 'rw',
    isa       => 'Str',
    reader    => 'get_id',
    writer    => 'set_id',
    predicate => 'has_id',
    );

has 'seq' => (
    is        => 'rw',
    isa       => 'Str',
    reader    => 'get_seq',
    writer    => 'set_seq',
    predicate => 'has_seq',
    );

has 'qual' => (
    is        => 'rw',
    lazy      => 1,
    default   => undef,
    reader    => 'get_qual',
    writer    => 'set_qual',
    predicate => 'has_qual',
    );

=head1 METHODS

=head2 next_seq

 Title   : next_seq
 Usage   : while (my $seq = $trans_obj->next_seq($fh)) { ... };
           
 Function: Reads fasta/fastq files seamlessly without needing to 
           specify the format.
                                                                            
 Returns : A Transposome::SeqIO object on which you can call methods                  
           representing the sequence, id, or quality scores (in the
           case of fastq). E.g.,
           
           while (my $seq = $trans_obj->next_seq($fh)) { 
               $seq->get_id;   # gets the sequence id
               $seq->get_seq;  # gets the sequence
               $seq->get_qual; # gets the quality scores
           }

           Each of the above methods an easy way of checking to see
           if that slot is set. E.g.,
           
           if ($seq->has_id)   { ... # is the id set? }
           if ($seq->has_seq)  { ... # is the seq set? }
           if ($seq->has_qual) { ... # is the qual set? This will be no for Fasta. }

 Args    : Takes a file handle. You can get the file handle                 
           by calling the method 'get_fh' on a Transposome::SeqIO object. E.g.,
 
           my $trans_obj = Transposome::SeqIO->new( file => $infile );
           my $fh = $trans_obj->get_fh;

=cut

sub next_seq {
    my ($self, $fh) = @_;

    my $line = <$fh>;
    return unless defined $line;
    chomp $line;

    my (@seqs, @quals);
    if (substr($line, 0, 1) eq '>') {
        my $name = $self->_set_id_per_encoding($line);
        $self->set_id($name);
        
        my $sline = <$fh>;
        chomp $sline;

        my $seqline;
        if ($sline =~ /[ATCGNatcgn]/) {
            push @seqs, $sline;
            while ($seqline = <$fh>) {
                last if $seqline =~ />/;
                push @seqs, $seqline;
            }
        }
        seek $fh, -length($seqline), 1 if length $seqline;
        my $seq = join '', @seqs;
        $seq =~ s/>.*// if $seq =~ />/;
        $seq =~ s/\s//g;
        $self->set_seq($seq);

        return $self;
    }
    if (substr($line, 0, 1) eq '@') {
        my $name = $self->_set_id_per_encoding($line);
        my $id = $1 if $line =~ /^@(\w+|\d+)(?::|-)/;
        my $pat = qr/$id/;
        $self->set_id($name);

        my $sline = <$fh>;
        chomp $sline;

        my $seqline;
        if ($sline =~ /[ATCGNatcgn]/) {
            push @seqs, $sline;
            while ($seqline = <$fh>) {
                last if $seqline =~ /\+/;
                push @seqs, $seqline;
            }
        }
        seek $fh, -length($seqline), 1 if length $seqline;
        my $seq = join '', @seqs;
        $seq =~ s/\+.*// if $seq =~ /\+/;
        $seq =~ s/\s//g;
        $self->set_seq($seq);

        
        my $cline = <$fh>;
        my $qline;
        while ($qline = <$fh>) {
            chomp $qline;
            last if $qline =~ /$pat/;
            push @quals, $qline;
        }
        seek $fh, -length($qline)-1, 1 if length $qline;
        my $qual = join '', @quals;
        $qual =~ s/${pat}.*// if $qual =~ /${pat}/;
        $qual =~ s/\s//g;
        $self->set_qual($qual);

        return $self;
    }
}

=head2 _set_id_per_encoding

Title   : _set_id_per_encoding

Usage   : This is a private method, don't use it directly.
          
Function: Try to determine format of sequence files
          and preserve paired-end information.
                                                               Return_type
Returns : A corrected sequence header if Illumina              Scalar
          Illumina 1.8+ is detected                           
        
                                                               Arg_type
Args    : A sequence header                                    Scalar

=cut

sub _set_id_per_encoding {
    my $hline = shift;
    if ($hline =~ /^.?(\S+)\s(\d)\S+/) {
	return $1."/".$2;
    }
    elsif ($hline =~ /^.?(\S+)/) {
	return $1;
    }
    else {
	return '';
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

    perldoc Transposome::SeqIO


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

