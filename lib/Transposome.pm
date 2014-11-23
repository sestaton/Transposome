package Transposome;

use 5.012;
use Moose;
use Method::Signatures;
use YAML::Tiny;
use namespace::autoclean;

with 'MooseX::Log::Log4perl',
     'Transposome::Role::Config';

=head1 NAME

Transposome - Investigate the repeat strucuture of a genome through unassembled sequence reads.

=head1 VERSION

Version 0.07.9

=cut

our $VERSION = '0.07.9';
#$VERSION = eval $VERSION;

=head1 SYNOPSIS

    transposome --config transposome_config.yml

=cut

has 'config' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 0,
    documentation => qq{The Transposome configuration file},
);

#has 'version' => ( 
#    is            => 'ro', 
#    isa           => 'Bool', 
#    required      => 0,
#    documentation => qq{Get version information and exit},
#);

#has '+logger' => ( traits => ['NoGetopt'], );

method get_configuration {
    my $configfile   = YAML::Tiny->read( $self->config );
    my $valid_config = $self->parse_configuration( $configfile );
    return $valid_config;
}

#method getopt_usage_config {
#   return (
#       format   => "Usage: %c [OPTIONS]",
#       headings => 1,
#   );
#}

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests through the project site at 
L<https://github.com/sestaton/Transposome/issues>. I will be notified,
and there will be a record of the issue. Alternatively, I can also be 
reached at the email address listed above to resolve any questions.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2014 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
