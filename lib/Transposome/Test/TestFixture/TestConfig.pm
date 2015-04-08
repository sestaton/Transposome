package Transposome::Test::TestFixture::TestConfig;

use 5.010;
use Moose::Role;
use MooseX::Types::Path::Class;
use File::Temp;
use aliased 'Transposome::Test::TestFixture';
use namespace::autoclean;

=head1 NAME

Transposome::Test::TestFixture::TestConfig - Methods for mocking configuration data for Transposome.

=head1 VERSION

Version 0.09.3

=cut

our $VERSION = '0.09.3';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    use Transposome::Test::TestFixture;

    my $test = Transposome::Test::TestFixture->new( build_proper => 1, destroy => 0 );
    my $config_arr = $test->config_constructor;

=cut

has 'exclude' => (
    is       => 'ro',
    isa      => 'Str',
    required => 0
);

has 'seq_file' => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 0,
    coerce   => 1
);

has 'seq_format' => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
);

has 'repeat_db' => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 0,
    coerce   => 1,
);

=head2 config_constructor

 Title   : config_constructor

 Usage   : my $test = Transposome::Test::TestFixture->new( build_proper => 1, destroy => 0 );                                                                                                         
           my $fa_arr = $test->config_constructor; 
           
 Function: Create temporary configuration files for testing Transposome.

                                                                            Return_type
 Returns : An array of config files.                                         ArrayRef
           
 Args    : None. This is a class method called on TestFixture object.

=cut

sub config_constructor {
    my $self = shift;
    if ( $self->build_proper ) {
	my $exclude = $self->exclude || undef;
	my $proper_yml = $self->_build_config_data($exclude);
	if ( $self->destroy ) {
	    unlink $proper_yml;
	}
	else {
	    return [$proper_yml];
	}
    }
}

=head2 _build_config_data

 Title   : _build_config_data

 Usage   : This is a private method, do not use it directly.
           
 Function: Create temporary configuration files for testing Transposome.

                                                                            Return_type
 Returns : A config file                                                    Scalar
           
 Args    : None. This is a class method called on TestFixture object.

=cut

sub _build_config_data {
    my $self = shift;
    my ($exclude) = @_;
    my $tmpyml = File::Temp->new(
        TEMPLATE => "transposome_config_XXXX",
        DIR      => 't',
        SUFFIX   => ".yml",
        UNLINK   => 0
    );

    my $tmpyml_name = $tmpyml->filename;

    my $seq_file   = $self->seq_file;
    my $seq_format = $self->seq_format;
    my $repeat_db  = $self->repeat_db;
    my $test       = TestFixture->new( build_proper => 1, destroy => 0 );
    my $blast      = $test->blast_constructor;
    my ($blfl)     = @$blast;

    say $tmpyml "blast_input:";
    say $tmpyml "  - sequence_file:     $seq_file";
    say $tmpyml "  - sequence_format:   $seq_format";
    say $tmpyml "  - sequence_num:      10" unless defined $exclude && $exclude eq 'sequence_num';
    say $tmpyml "  - cpu:               1" unless defined $exclude && $exclude eq 'cpu';
    say $tmpyml "  - thread:            1";
    say $tmpyml "  - output_directory:  t/test_transposome_cli_out";
    say $tmpyml "clustering_options:";
    say $tmpyml "  - in_memory:         1";
    say $tmpyml "  - percent_identity:  90";
    say $tmpyml "  - fraction_coverage: 0.55";
    say $tmpyml "  - merge_threshold:   0.029";
    say $tmpyml "annotation_input:";
    say $tmpyml "  - repeat_database:  $repeat_db";
    say $tmpyml "annotation_options:";
    say $tmpyml "  - cluster_size:     1";
    say $tmpyml "  - blast_evalue:     10" unless defined $exclude && $exclude eq 'blast_evalue';
    say $tmpyml "output:";
    say $tmpyml "  - run_log_file:       t_log.txt";
    say $tmpyml "  - cluster_log_file:   t_cluster_report.txt";

    return $tmpyml_name;
}

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2015 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

1;
