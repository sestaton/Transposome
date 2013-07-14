package Transposome::SeqStore;

use 5.012;
use Moose::Role;
use MooseX::Types::Path::Class;
use namespace::autoclean;
BEGIN {
  @AnyDBM_File::ISA = qw( DB_File SQLite_File )
      unless @AnyDBM_File::ISA == 1;
}
use AnyDBM_File;                  
use vars qw( $DB_BTREE &R_DUP );  
use AnyDBM_File::Importer qw(:bdb);

with 'Transposome::Types';

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

=head1 ATTRIBUTES

'seq_file'  - Takes the name of a Fasta/q file as the argument.
'in_memory' - Set whether or not perform calculations in memory (Boolean: 0/1; Default: 0).

=cut

has 'file' => (
      is       => 'ro',
      isa      => 'Path::Class::File',
      required => 1,
      coerce   => 1,
    );

has 'in_memory' => (
    is         => 'ro',
    isa        => 'Bool',
    predicate  => 'memory',
    required   => 0,
    default    => 0,
    );

#has 'counter' => (
#      traits  => ['Counter'],
#      is      => 'ro',
#      isa     => 'Num',
#      default => 0,
#      handles => {
#	  inc_counter   => 'inc',
#          dec_counter   => 'dec',
#          reset_counter => 'reset',
#      },
#    );

=head1 METHODS

=head2 fas_to_hash

 Title   : fas_to_hash
 Usage   : my ($seqs, $seq_ct) = $seq_store->fas_to_hash;
          
 Function: 
 Returns : 
 Args    : 


=cut

sub fas_to_hash {
    my $self = shift;
 
    my %seqhash;
    unless ($self->memory) {
        $DB_BTREE->{cachesize} = 100000;
        $DB_BTREE->{flags} = R_DUP;
        my $seq_dbm = "transposome_seqstore.dbm";
        unlink $seq_dbm if -e $seq_dbm;
        tie %seqhash, 'AnyDBM_File', $seq_dbm, O_RDWR|O_CREAT, 0666, $DB_BTREE
            or croak "\nERROR: Could not open DBM file $seq_dbm: $!\n";
    }

    if (-e $self->file) {
        my $fh = $self->file->openr or croak "\nERROR: Could not open file: ",$self->file->relative; ## need to test this
        my ($name, $seq, $qual, @aux);
        while (($name, $seq, $qual) = _readfq(\*$fh, \@aux)) {
	    $self->inc_counter if defined $seq;;
            $seqhash{$name} = $seq;
        }
    }
    return(\%seqhash, $seqct);
}

=head2 _readfq 

 Title   : _readfq
 Usage   : 
          
 Function: 
 Returns : 
 Args    :

=cut

sub _readfq {
    my ($fh, $aux) = @_;
    @$aux = [undef, 0] if (!@$aux);
    return if ($aux->[1]);
    if (!defined($aux->[0])) {
        while (<$fh>) {
            chomp;
            if (substr($_, 0, 1) eq '>' || substr($_, 0, 1) eq '@') {
                $aux->[0] = $_;
                last;
            }
        }
        if (!defined($aux->[0])) {
            $aux->[1] = 1;
            return;
        }
    }
    my $name;
    if (/^.?(\S+)\s(\d)\S+/) {      # Illumina 1.8+
        $name = $1."/".$2;
    }
    elsif (/^.?(\S+)/) {            # Illumina 1.3+
        $name = $1;
    } else {
        $name = '';                 # ?
    }
    #my $name = /^.(\S+)/? $1 : ''; # Heng Li's original regex
    my $seq = '';
    my $c;
    $aux->[0] = undef;
    while (<$fh>) {
        chomp;
        $c = substr($_, 0, 1);
        last if ($c eq '>' || $c eq '@' || $c eq '+');
        $seq .= $_;
    }
    $aux->[0] = $_;
    $aux->[1] = 1 if (!defined($aux->[0]));
    return ($name, $seq) if ($c ne '+');
    my $qual = '';
    while (<$fh>) {
        chomp;
        $qual .= $_;
        if (length($qual) >= length($seq)) {
            $aux->[0] = undef;
            return ($name, $seq, $qual);
        }
    }
    $aux->[1] = 1;

    return ($name, $seq);
}

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-transposome at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Transposome>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::SeqStore


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Transposome>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Transposome>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Transposome>

=item * Search CPAN

L<http://search.cpan.org/dist/Transposome/>

=back


=head1 ACKNOWLEDGEMENTS


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

#1; # End of Transposome::SeqStore
__PACKAGE__->meta->make_immutable;
