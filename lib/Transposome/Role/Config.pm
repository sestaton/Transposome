package Transposome::Role::Config;

use 5.010;
use Moose::Role;

=head1 NAME

Transposome::Role::Config - Attributes and routines for parsing Transposome configuration. 

=head1 VERSION

Version 0.12.1

=cut

our $VERSION = '0.12.1';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    use Transposome;

    with 'Transposome::Role::Config'
    ...

=cut

=head1 METHODS

=head2 parse_configuration

 Title    : parse_config

 Usage    : my $config = $trans_obj->parse_configuration;

 Function : The parsed configuration for Transposome.

                                                           Return_type
 Returns  : A hash containing the user-set configuration   HashRef
            for how transposome is to be executed

 Args     : None. This is a role that can be consumed.

=cut 

sub parse_configuration {
    my $self = shift;
    my ($yaml) = @_;
    my %config;
    my $index = 0;

    # blast input section from config
    $config{sequence_file}   = $yaml->[0]->{blast_input}->[$index]->{sequence_file}; 
    $index++;
    $config{sequence_format} = $yaml->[0]->{blast_input}->[$index]->{sequence_format}; 
    $index++;
    $config{sequence_num}    = $yaml->[0]->{blast_input}->[$index]->{sequence_num}; 
    $index++;
    unless ($config{sequence_num}) {
	$config{sequence_num} = 50000;
	$index--;
    }
    $config{cpu} = $yaml->[0]->{blast_input}->[$index]->{cpu}; 
    $index++;
    unless ($config{cpu}) {
	$config{cpu} = 1;
	$index--;
    }
    $config{thread}            = $yaml->[0]->{blast_input}->[$index]->{thread};
    $index++;
    $config{output_directory}  = $yaml->[0]->{blast_input}->[$index]->{output_directory};

    # clustering options from config
    $index = 0;
    $config{in_memory}         = $yaml->[0]->{clustering_options}->[$index]->{in_memory};
    $index++;
    if ($config{in_memory} =~ /1|yes/i) {
	$config{in_memory} = 1;
    }
    elsif ($config{in_memory} =~ /0|no/i) {
	$config{in_memory} = 0;
    }
    $config{percent_identity}  = $yaml->[0]->{clustering_options}->[$index]->{percent_identity};
    $index++;
    $config{fraction_coverage} = $yaml->[0]->{clustering_options}->[$index]->{fraction_coverage};
    $index++;
    $config{merge_threshold}   = $yaml->[0]->{clustering_options}->[$index]->{merge_threshold};
    unless ($config{merge_threshold}) {
	$config{merge_threshold} = 0.001;
    }

    # annotation options from config
    $index = 0;
    $config{cluster_size} = $yaml->[0]->{annotation_options}->[$index]->{cluster_size};
    $index++;
    $config{blast_evalue} = $yaml->[0]->{annotation_options}->[$index]->{blast_evalue};
    $config{blast_evalue} //= 10;

    # annotation input from config
    $index = 0;
    $config{repeat_database} = $yaml->[0]->{annotation_input}->[0]->{repeat_database};

    # output from config
    $index = 0;
    $config{run_log_file}     = $yaml->[0]->{output}->[0]->{run_log_file};
    $index++;
    $config{cluster_log_file} = $yaml->[0]->{output}->[1]->{cluster_log_file};

    my $valid_config = $self->_validate_params(\%config);

    return $valid_config;
}

=head2 _validate_params

 Title    : _validate_params

 Usage    : This is a private method, do not use it directly.

 Function : Valiadate whether all of the slots in config file
            have been set.

                                                           Return_type
 Returns  : A hash containing the user-set configuration   HashRef
            for how transposome is to be executed

 Args     : None. This is a role that can be consumed.

=cut 

sub _validate_params {
    my $self = shift;
    my ($config) = @_;
    for my $k (keys %$config) {
	my $v = $config->{$k};
        if (not defined $v) {
            die "[ERROR]: '$k' is not defined after parsing configuration file.\n".
	        "         This indicates there may be a blank line in your configuration file.\n".
	        "         Please check your configuration file and try again. Exiting.\n";
        }
        elsif ($v =~ /^~/) {
            $v =~ s/^~/$ENV{"HOME"}/;
            $config->{$k} = $v;
        }
    }
    
    for my $file (qw(sequence_file repeat_database)) {
	if (! -e $config->{$file}) {
	    die "[ERROR]: '$config->{$file}' was provided in the configuration file but it does not exist or cannot be found.\n".
	        "          Please check your configuration file and try again. Exiting.\n";
	}
    }
    return $config;
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

    perldoc Transposome::Role::Config


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2023 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

1; 

