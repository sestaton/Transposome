package Transposome::Role::Config;

use 5.012;
use Moose::Role;
use Method::Signatures;

=head1 NAME

Transposome::Role::Config - Attributes and routines for parsing Transposome configuration. 

=head1 VERSION

Version 0.06.1

=cut

our $VERSION = '0.06.1';
$VERSION = eval $VERSION;

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

method parse_configuration ($yaml) {
    my %config;

    # blast input section from config
    $config{sequence_file}     = $yaml->[0]->{blast_input}->[0]->{sequence_file};
    $config{sequence_num}      = $yaml->[0]->{blast_input}->[1]->{sequence_num};
    $config{cpu}               = $yaml->[0]->{blast_input}->[2]->{cpu};
    $config{thread}            = $yaml->[0]->{blast_input}->[3]->{thread};
    $config{output_directory}  = $yaml->[0]->{blast_input}->[4]->{output_directory};

    # clustering options from config
    $config{in_memory}         = $yaml->[0]->{clustering_options}->[0]->{in_memory};
    $config{percent_identity}  = $yaml->[0]->{clustering_options}->[1]->{percent_identity};
    $config{fraction_coverage} = $yaml->[0]->{clustering_options}->[2]->{fraction_coverage};
    $config{merge_threshold}   = $yaml->[0]->{clustering_options}->[3]->{merge_threshold};

    # annotation options from config
    $config{cluster_size}      = $yaml->[0]->{annotation_options}->[0]->{cluster_size};
    $config{blast_evalue}      = $yaml->[0]->{annotation_options}->[1]->{blast_evalue};

    # annotation input from config
    $config{repeat_database}   = $yaml->[0]->{annotation_input}->[0]->{repeat_database};

    # output from config
    $config{run_log_file}      = $yaml->[0]->{output}->[0]->{run_log_file};
    $config{cluster_log_file}  = $yaml->[0]->{output}->[1]->{cluster_log_file};

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

Copyright (C) 2013-2014 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

1; 

