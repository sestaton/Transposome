package Transposome::Role::Config;

use 5.012;
use Moose::Role;
use MooseX::Method::Signatures;
use namespace::autoclean;

=head1 NAME

Transposome::Role::Config - Attributes and routines for parsing Transposome configuration. 

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

    use Transposome;

    with 'Transposome::Role::Config'
    ...

=cut

=head1 METHODS

=head2 get_config

 Title    : get_config

 Usage    : my $config = $trans_obj->get_config;

 Function : The parsed configuration for Transposome.

                                                           Return_type
 Returns  : A hash containing the user-set configuration   HashRef
            for how transposome is to be executed

 Args     : None. This is a role that can be consumed.

=cut 

method get_config {
    my %config;

    # blast input section from config
    $config{sequence_file}     = $self->configuration->{blast_input}->[0]->{sequence_file};
    $config{sequence_num}      = $self->configuration->{blast_input}->[1]->{sequence_num};
    $config{cpu}               = $self->configuration->{blast_input}->[2]->{cpu};
    $config{thread}            = $self->configuration->{blast_input}->[3]->{thread};
    $config{output_directory}  = $self->configuration->{blast_input}->[4]->{output_directory};

    # clustering options from config
    $config{in_memory}         = $self->configuration->{clustering_options}->[0]->{in_memory};
    $config{percent_identity}  = $self->configuration->{clustering_options}->[1]->{percent_identity};
    $config{fraction_coverage} = $self->configuration->{clustering_options}->[2]->{fraction_coverage};
    $config{merge_threshold}   = $self->configuration->{clustering_options}->[3]->{merge_threshold};

    # annotation options from config
    $config{cluster_size}      = $self->configuration->{annotation_options}->[0]->{cluster_size};
    $config{blast_evalue}      = $self->configuration->{annotation_options}->[1]->{blast_evalue};

    # annotation input from config
    $config{repeat_database}   = $self->configuration->{annotation_input}->[0]->{repeat_database};

    # output from config
    $config{run_log_file}      = $self->configuration->{output}->[0]->{run_log_file};
    $config{cluster_log_file}  = $self->configuration->{output}->[1]->{cluster_log_file};

    my $valid_config = $self->_validate_params(\%config);

    return $valid_config;
}

=head2 _validate_params

 Title    : _validate_params

 Usage    : This is a private method, don't use it directly.

 Function : Valiadate whether all of the slots in config file
            have been set.

                                                           Return_type
 Returns  : A hash containing the user-set configuration   HashRef
            for how transposome is to be executed

 Args     : None. This is a role that can be consumed.

=cut 

method _validate_params ($config) {
    for my $k (keys %$config) {
	my $v = $config->{$k};
        if (not defined $v) {
            warn "\n[ERROR]: '$k' is not defined after parsing configuration file.";
	    warn "           This indicates there may be a blank line in your configuration file.";
	    warn "           Please check your configuration file and try again. Exiting.\n";
            exit(1);
        }
        else {
            if ($v =~ /^~/) {
                $v =~ s/^~/$ENV{"HOME"}/;
                $config->{$k} = $v;
            }
        }
    }
    return $config;
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

    perldoc Transposome::Role::Config


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

