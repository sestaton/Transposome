package Transposome::Role::Types;
use 5.010;
use Moose::Role;
#use Types::Standard qw(Str Num Int);
#use Type::Utils qw(declare as where inline_as coerce from via); 
use Moose::Util::TypeConstraints;
use namespace::autoclean;

=head1 NAME

Transposome::Types - Types used by Transposome. Not meant to be used directly. 

=head1 VERSION

Version 0.11.3

=cut

our $VERSION = '0.11.3';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    with 'Transposome::Role::Types';
    ...

=cut

#my $ModNum = declare
#    as        Num,
#    where     { /\_/ || /\d+/ },
#    inline_as { "$_ =~ /\_/ || $_ =~ /\d+/" };

#coerce $ModNum, from Str, via { $_ =~ s/\_//g; 0+$_ }; 
subtype 'ModNum'
    => as 'Num'
    => where { /\_/ || /\d+/ };

coerce 'ModNum',
    from 'Str',
    via { $_ =~ s/\"|\_//g; 0+$_ };

#has 'ModNum' => ( 
#     is     => 'ro',
#     isa    => $ModNum,
#     coerce => 1,
#);

has 'counter' => (
    traits  => ['Counter'],
    is      => 'ro',
    isa     => 'Num',
    default => 0,
    handles => {
        inc_counter   => 'inc',
        dec_counter   => 'dec',
        reset_counter => 'reset',
    },
);

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests through the project site at 
L<https://github.com/sestaton/Transposome/issues>. I will be notified,
and there will be a record of the issue. Alternatively, I can also be 
reached at the email address listed above to resolve any questions.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::Role::Types


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2015 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

1;

