package Transposome::Role::Util;

use 5.012;
use Moose::Role;
use namespace::autoclean;
use utf8;
use charnames qw(:full :short);
use JSON;

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

                                                   Data_type
 Returns : A string comprising the input           Scalar

 Args    : An array of strings                     Array

=cut

sub mk_key {
    my ($self) = shift;
    return join "\N{INVISIBLE SEPARATOR}", map { $_ // " " } @_;
}

=head2 mk_vec

 Title   : mk_vec
 Usage   : my @vec = mk_vec('some_joined_string');
          
 Function: Creates an array out of a string.
                  
                                                   Data_type                                  
 Returns : An array comprised of the elements      Array
           joined in the input string

 Args    : A string                                Scalar

=cut

sub mk_vec {
    my ($self, $key) = @_;
    return split "\N{INVISIBLE SEPARATOR}", $key;
}

=head2 json_to_hash

 Title   : json_to_hash
 
 Usage   : my $hash = json_to_hash($json);
          
 Function: Creates an easy to parse data structure out of
           a JSON file. Helpful for going back and forth
           between Perl and some serialized data form.

                                                    Data_type
 Returns : A Perl data structure comprised of       HashRef
           all the JSON contents

 Args    : A valid JSON file                        Scalar

=cut

sub json_to_hash {
    my ($self, $json) = @_;
   
    my $json_text;
    local $/;
    open my $in, '<', $json;
    $json_text = <$in>;
    close $in;

    my $repeats = JSON->new->utf8->space_after->decode($json_text);
    return $repeats;
}

=head2 get_config

 Title    : get_config

 Usage    : my $config = $trans_obj->get_config;

 Function : The parsed configuration for Transposome.

                                                           Data_type
 Returns  : A hash containing the user-set configuration   HashRef
            for how transposome is to be executed

 Args     : None. This is a role that can be consumed.

=cut 

sub get_config {
    my ($self) = @_;

    my %config;


    $config{sequence_file}    = $self->configuration->{blast_input}->[0]->{sequence_file};
    $config{description_num}  = $self->configuration->{blast_input}->[1]->{description_num};
    $config{alignment_num}    = $self->configuration->{blast_input}->[2]->{alignment_num};
    $config{sequence_num}     = $self->configuration->{blast_input}->[3]->{sequence_num};
    $config{cpu}              = $self->configuration->{blast_input}->[4]->{cpu};
    $config{thread}           = $self->configuration->{blast_input}->[5]->{thread};
    $config{output_directory} = $self->configuration->{blast_input}->[6]->{output_directory};

    $config{blast_file}       = $self->configuration->{clustering_input}->[1]->{blast_file};
    $config{in_memory}        = $self->configuration->{clustering_input}->[3]->{in_memory};

    $config{percent_identity}  = $self->configuration->{clustering_options}->[0]->{percent_identity};
    $config{fraction_coverage} = $self->configuration->{clustering_options}->[1]->{fraction_coverage};
    $config{merge_threshold}   = $self->configuration->{clustering_options}->[2]->{merge_threshold};

    $config{cluster_size} = $self->configuration->{annotation_options}->[0]->{cluster_size};
    $config{blast_evalue} = $self->configuration->{annotation_options}->[1]->{blast_evalue};

    $config{repeat_database}   = $self->configuration->{annotation_input}->[0]->{repeat_database};
    $config{repeat_json_file} = $self->configuration->{annotation_input}->[1]->{repeat_json_file};

    $config{report_file} = $self->configuration->{output}->[0]->{report_file};

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

