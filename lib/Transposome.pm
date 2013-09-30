package Transposome;

use 5.012;
use Moose;
use YAML;
use namespace::autoclean;

with 'MooseX::Getopt::Usage',
     'MooseX::Getopt::Usage::Role::Man',
     'MooseX::Log::Log4perl',
     'Transposome::Role::Util';

=head1 NAME

Transposome - Investigate the repeat strucuture of a genome through unassembled sequence reads.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    transposome --config transposome_config.yml

=cut

has 'config' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    documentation => qq{The Transposome configuration file},
    );

has 'configuration' => (
    traits  => ['NoGetopt'],
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { YAML::LoadFile shift->config }
    );

#sub getopt_usage_config {
#    return ( usage_sections => ["NAME|SYNOPSIS|OPTIONS"] );
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
