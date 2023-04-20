package Transposome::SeqIO::fasta;

use 5.010;
use Moose;
use namespace::autoclean;

extends 'Transposome::SeqIO';

=head1 NAME

Transposome::SeqIO::fasta - Class for reading FASTA data.

=head1 VERSION

Version 0.12.1

=cut

our $VERSION = '0.12.1';

=head1 SYNOPSIS

    use Transposome::SeqIO::fasta;

    my $trans_obj = Transposome::SeqIO::fasta->new( file => $infile );

    while (my $seq = $trans_obj->next_seq) {
         # do something interesting with $seq
    }

=cut

=head1 METHODS

=head2 next_seq

 Title   : next_seq
 Usage   : while (my $seq = $trans_obj->next_seq) { ... };
           
 Function: Reads FASTA data from a file or filehanle.
                                                                            
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

 Args    : None. This is a class method called on a Transposome::SeqIO::fasta object.
 
           my $seqio = Transposome::SeqIO::fasta->new( file => $infile );

=cut

sub next_seq {
    my $self = shift;
    local $/ = "\n>";
    my $fh   = $self->fh;
    return unless my $record = $fh->getline;
    chomp $record;

    my ($id, $seq) = split /\n/, $record, 2;
    defined $id && $id =~ s/>//g;
    my $name;
    if ($self->has_seqtype && $self->get_seqtype =~ /illumina/i) { 
	$name = $self->set_id_per_encoding($id);
    }
    else {
	$name = $id;
    }
    $self->set_id($name);

    if (!length($seq)) {
	warn "No sequence for FASTA record '$name'.";
	exit(1);
    }
    $self->set_seq($seq);

    return $self;
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

Copyright (C) 2013-2023 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
