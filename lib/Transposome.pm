package Transposome;

use 5.010;
use Moose;
use YAML::Tiny;
use Log::Any qw($log);
use namespace::autoclean;

with 'Transposome::Role::Config',
     'Transposome::Role::File';

=head1 NAME

Transposome - Investigate the repeat strucuture of a genome through unassembled sequence reads.

=head1 VERSION

Version 0.12.1

=cut

our $VERSION = '0.12.1';
#$VERSION = eval $VERSION;

=head1 SYNOPSIS

    transposome --config transposome_config.yml

=cut

sub get_configuration {
    my $self = shift;
    my $config_file   = YAML::Tiny->read( $self->config );
    my $valid_config = $self->parse_configuration( $config_file );
    return $valid_config;
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

    perldoc Transposome


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2023 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
