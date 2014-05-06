package Transposome::Role::File;

use 5.012;
use Moose::Role;
use MooseX::Types::Path::Class;
use Method::Signatures;

=head1 NAME

Transposome::Role::File - File handling methods for Transposome.

=head1 VERSION

Version 0.07.0

=cut

our $VERSION = '0.07.0';
$VERSION = eval $VERSION;

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

has 'fh' => (
    is         => 'ro',
    isa        => 'IO::File',
    lazy_build => 1,
);

=head1 METHODS

=head2 get_fh

 Title   : get_fh

 Usage   : my $fh = $trans_obj->file->get_fh;
          
 Function: Gets a filehandle for the associated
           file.

                                                   Return_type
 Returns : An open filehandle for reading          Scalar

 Args    : None. This is a role that can
           be consumed.

=cut

method get_fh {
    if (-e $self->file) {
	my $fh = $self->file->openr;
	return $fh;
    }
}

=head2 _build_fh

 Title   : _build_fh

 Usage   : This is a private method, do not use it directly.
          
 Function: Gets a filehandle for the associated
           file.

                                                   Return_type
 Returns : An open filehandle for reading          Scalar

 Args    : None. This is a role that can
           be consumed.

=cut

method _build_fh {
    my $fh = $self->file->openr;
    return $fh;
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

    perldoc Transposome::Role::File


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2014 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

1;
