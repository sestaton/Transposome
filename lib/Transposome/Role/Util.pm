package Transposome::Role::Util;

use 5.010;
use Moose::Role;
use MooseX::Types::Moose qw(Str);
use Method::Signatures;

=head1 NAME

Transposome::Role::Util - Numerous utility routines for Transposome. 

=head1 VERSION

Version 0.08.4

=cut

our $VERSION = '0.08.4';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    use Transposome;

    with 'Transposome::Role::Util'
    ...

=cut

has 'cpus' => (
    is        => 'ro',
    isa       => 'Int',
    predicate => 'has_cpus',
    lazy      => 1,
    default   => 1,
);

has 'threads' => (
    is        => 'ro',
    isa       => 'Int',
    predicate => 'has_threads',
    lazy      => 1,
    default   => 1,
);

=head1 METHODS

=head2 mk_key

 Title   : mk_key
 Usage   : my $key = mk_key('string1','string2');
          
 Function: Safely creates a string of joined strings
           to be used (internally) as a hash key. Could
           also be used in comparisons. This uses standard
           ascii characters whereas previous versions relied
           on unicode characters (which may be safer but is
           much slower).

                                                           Return_type
 Returns : A string comprising the input                   Scalar

                                                           Arg_type
 Args    : An array of strings                             Array

=cut

method mk_key (@arg) {
    return join "~~", map { $_ // " " } @arg;
}

=head2 mk_vec

 Title   : mk_vec
 Usage   : my @vec = mk_vec('some_joined_string');
          
 Function: Creates an array out of a string.
                  
                                                           Return_type                                  
 Returns : An array comprised of the elements              Array
           joined in the input string

                                                           Arg_type
 Args    : A string                                        Scalar

=cut

method mk_vec (Str $key) {
    return split /\~\~/, $key;
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

    perldoc Transposome::Role::Util


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2015 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

1; 

