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

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 mk_key

 Title   : mk_key
 Usage   : 
          
 Function: 
 Returns : 
 Args    :

=cut

sub mk_key {
    my ($self) = shift;
    return join "\N{INVISIBLE SEPARATOR}", map { $_ // " " } @_;
}

=head2 mk_vec

 Title   : mk_vec
 Usage   : 
          
 Function: 
 Returns : 
 Args    :

=cut

sub mk_vec {
    my ($self, $key) = @_;
    return split "\N{INVISIBLE SEPARATOR}", $key;
}

=head2 json_to_hash

 Title   : json_to_hash
 Usage   : 
          
 Function: 
 Returns : 
 Args    :

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
 Usage    :
 Function :
 Returns  :
 Args     :

=cut 

sub get_config {
    my ($self) = @_;

    my %config;

    $config{sequence_file}    = $self->configuration->{clustering_input}->[0]->{sequence_file};
    $config{blast_file}       = $self->configuration->{clustering_input}->[1]->{blast_file};
    $config{output_directory} = $self->configuration->{clustering_input}->[2]->{output_directory};
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

Please report any bugs or feature requests to C<bug-transposome at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Transposome>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::Util


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Transposome>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Transposome>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Transposome>

=item * Search CPAN

L<http://search.cpan.org/dist/Transposome/>

=back


=head1 ACKNOWLEDGEMENTS


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

1; # End of Transposome::Util
#__PACKAGE__->meta->make_immutable;
