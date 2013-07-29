package Transposome::Role::File;

use 5.012;
use Moose::Role;
use MooseX::Types::Path::Class;
use namespace::autoclean;


# class attributes
has 'file' => (
      is       => 'ro',
      isa      => 'Path::Class::File',
      #isa      => 'File', # coerced to Path::Class::File
      required => 1,
      coerce   => 1,
    );

has 'dir' => (
      is       => 'ro',
      isa      => 'Path::Class::Dir',
      required => 0,
      coerce   => 1,
    );

# class methods
sub get_fh {
    my $self = shift;
    if (-e $self->file) {
        my $fh = $self->file->openr;
        return $fh
    }
}

1;
