package Transposome::Role::Util;

use 5.012;
use Moose::Role;
use namespace::autoclean;
use utf8;
use charnames qw(:full :short);

=head1 NAME

Transposome::Role::Util - Numerous utility routines for Transposome. 

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    use Transposome;

    with 'Transposome::Role::Util'
    ...

=head1 METHODS

=head2 mk_key

 Title   : mk_key
 Usage   : my $key = mk_key('string1','string2');
          
 Function: Safely creates a string of joined strings
           to be used (internally) as a hash key. Could
           also be used in comparisons. This uses a Unicode
           character that is unlikely to be found in the
           data being analyzed. This is accomplished with
           Perl's charnames(), though these characters are available
           by default as of Perl v5.16.

                                                           Return_type
 Returns : A string comprising the input                   Scalar

                                                           Arg_type
 Args    : An array of strings                             Array

=cut

sub mk_key {
    my ($self) = shift;
    return join "\N{INVISIBLE SEPARATOR}", map { $_ // " " } @_;
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

sub mk_vec {
    my ($self, $key) = @_;
    return split "\N{INVISIBLE SEPARATOR}", $key;
}

=head2 get_config

 Title    : get_config

 Usage    : my $config = $trans_obj->get_config;

 Function : The parsed configuration for Transposome.

                                                           Return_type
 Returns  : A hash containing the user-set configuration   HashRef
            for how transposome is to be executed

 Args     : None. This is a role that can be consumed.

=cut 

sub get_config {
    my ($self) = @_;

    my %config;

    $config{sequence_file}    = $self->configuration->{blast_input}->[0]->{sequence_file};
    $config{sequence_num}     = $self->configuration->{blast_input}->[1]->{sequence_num};
    $config{cpu}              = $self->configuration->{blast_input}->[2]->{cpu};
    $config{thread}           = $self->configuration->{blast_input}->[3]->{thread};
    $config{output_directory} = $self->configuration->{blast_input}->[4]->{output_directory};

    $config{in_memory}         = $self->configuration->{clustering_options}->[0]->{in_memory};
    $config{percent_identity}  = $self->configuration->{clustering_options}->[1]->{percent_identity};
    $config{fraction_coverage} = $self->configuration->{clustering_options}->[2]->{fraction_coverage};
    $config{merge_threshold}   = $self->configuration->{clustering_options}->[3]->{merge_threshold};

    $config{cluster_size} = $self->configuration->{annotation_options}->[0]->{cluster_size};
    $config{blast_evalue} = $self->configuration->{annotation_options}->[1]->{blast_evalue};

    $config{repeat_database}   = $self->configuration->{annotation_input}->[0]->{repeat_database};

    $config{report_file} = $self->configuration->{output}->[0]->{report_file};

    for my $k (keys %config) {
	my $v = $config{$k};
	if ($v =~ /^~/) { 
	    $v =~ s/^~/$ENV{"HOME"}/; 
	    $config{$k} = $v;
	}
    }
    
    return \%config;
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

1; 

