package TestUtils::TestConfig;

use 5.012;
use Moose::Role;
use MooseX::Types::Path::Class;
use File::Temp;
use Cwd;
use namespace::autoclean;
use TestUtils;

has 'seq_file' => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 0,
    coerce   => 1 
    );

has 'repeat_db' => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 0,
    coerce   => 1,
    );

has 'repeat_json' => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 0,
    coerce   => 1,
    );

sub config_constructor {
    my ($self) = @_;
    if ($self->build_proper) {
        my $proper_yml = $self->_build_config_data;
        if ($self->destroy) {
            unlink $proper_yml;
        }
        else {
            return [ $proper_yml ];
        }
    }
}

sub _build_config_data {
    my ($self) = @_;
    my $cwd = getcwd();
    my $tmpyml = File::Temp->new( TEMPLATE => "transposome_config_XXXX",
                                  DIR      => $cwd,
                                  SUFFIX   => ".yml",
                                  UNLINK   => 0 );

    my $tmpyml_name = $tmpyml->filename;

    my $seq_file = $self->seq_file;
    my $repeat_db = $self->repeat_db;
    my $repeat_json = $self->repeat_json;
    my $test = TestUtils->new( build_proper => 1, destroy => 0 );
    my $blast = $test->blast_constructor;
    my ($blfl) = @$blast;
    
    say $tmpyml "clustering_input:";
    say $tmpyml "  - sequence_file:     $seq_file";
    say $tmpyml "  - blast_file:        $blfl";
    say $tmpyml "  - output_directory:  test_cli_out";
    say $tmpyml "  - in_memory:         1";
    say $tmpyml "clustering_options:";
    say $tmpyml "  - percent_identity:  90";
    say $tmpyml "  - fraction_coverage: 0.55";
    say $tmpyml "  - merge_threshold:   2";
    say $tmpyml "annotation_input:";
    say $tmpyml "  - repeat_database:  $repeat_db";
    say $tmpyml "  - repeat_json_file: $repeat_json";
    say $tmpyml "annotation_options:";
    say $tmpyml "  - cluster_size:     1";
    say $tmpyml "  - blast_evalue:     10";
    say $tmpyml "output:";
    say $tmpyml "  - report_file:      t_rep.out";

    return $tmpyml_name;
}

1;
