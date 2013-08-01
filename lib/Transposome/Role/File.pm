package Transposome::Role::File;

use 5.012;
use Moose::Role;
use MooseX::Types::Path::Class;
use namespace::autoclean;

=head1 NAME

Transposome::Role::File - File handling methods for Transposome.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    use Transposome;

    with 'Transposome::Role::File'
    ...

=cut

has 'file' => (
      is       => 'ro',
      isa      => 'Path::Class::File',
      required => 1,
      coerce   => 1,
    );

has 'dir' => (
      is       => 'ro',
      isa      => 'Path::Class::Dir',
      required => 0,
      coerce   => 1,
    );

=head1 SUBROUTINES/METHODS

=head2 get_fh

 Title   : get_fh
 Usage   : my $fh = $trans_obj->file->get_fh;
          
 Function: Gets a filehandle for the associated
           file.

                                                   Data_type
 Returns : An open filehandle for reading          Scalar

 Args    : None. This is a role that can
           be consumed.

=cut

sub get_fh {
    my $self = shift;
    if (-e $self->file) {
        my $fh = $self->file->openr;
        return $fh
    }
}

1;
