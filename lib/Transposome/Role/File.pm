package Transposome::Role::File;

use 5.010;
use Moose::Role;
use MooseX::Types::Path::Class;
#use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use IO::File;
use Symbol;
#use Method::Signatures;

=head1 NAME

Transposome::Role::File - File handling methods for Transposome.

=head1 VERSION

Version 0.09.5

=cut

our $VERSION = '0.09.5';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    use Transposome;

    with 'Transposome::Role::File'
    ...

=cut

has 'file' => (
      is       => 'ro',
      isa      => 'Path::Class::File',
      required => 0,
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
    #isa        => 'IO::File',
    predicate  => 'has_fh',
    lazy_build => 1,
    builder    => '_build_fh',
);

has 'format' => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_format',
    default   => 'fasta'
);

sub _build_fh {
    my $self = shift;
    my $file = $self->file->absolute;
    my $fh = IO::File->new();

    if ($file =~ /\.gz$/) {
        open $fh, '-|', 'zcat', $file or die "\nERROR: Could not open file: $file\n";
	#$fh = new IO::Uncompress::Gunzip $file->stringify;
	    #or die "IO::Uncompress::Gunzip failed: $GunzipError\n";
    }
    elsif ($file =~ /\.bz2$/) {
        open $fh, '-|', 'bzcat', $file or die "\nERROR: Could not open file: $file\n";
    }
    elsif ($file =~ /^-$|STDIN/) {
        open $fh, '< -' or die "\nERROR: Could not open STDIN\n";
    }
    else {
	open $fh, '<', $file or die "\nERROR: Could not open file: $file\n";
    }

    return $fh;
}

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

sub get_fh {
    my $self = shift;
    my $file = $self->file;
    my $fh;
    if ($file =~ /\.gz$/) {
	open $fh, '-|', 'zcat', $file or die "\nERROR: Could not open file: $file\n";
    }
    elsif ($file =~ /\.bz2$/) {
	open $fh, '-|', 'bzcat', $file or die "\nERROR: Could not open file: $file\n";
    }
    elsif ($file =~ /^-$|STDIN/) {
	open $fh, '< -' or die "\nERROR: Could not open STDIN\n";
    }
    else {
	$fh = $self->file->openr;
    }
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

Copyright (C) 2013-2015 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

1;
