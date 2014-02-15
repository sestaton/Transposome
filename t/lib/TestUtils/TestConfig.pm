package TestUtils::TestConfig;

use 5.012;
use Moose::Role;
use MooseX::Types::Path::Class;
use Method::Signatures;
use File::Temp;
use TestUtils;
use namespace::autoclean;

=head1 NAME

TestUtils::TestConfig - Methods for mocking configuration data for Transposome.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

    use TestUtils;

    my $test = TestUtils->new( build_proper => 1, destroy => 0 );
    my $config_arr = $test->config_constructor;

=cut

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

=head2 config_constructor

 Title   : config_constructor

 Usage   : my $test = TestUtils->new( build_proper => 1, destroy => 0 );                                                                                                         
           my $fa_arr = $test->config_constructor; 
           
 Function: Create temporary configuration files for testing Transposome.

                                                                            Return_type
 Returns : An array of config files.                                         ArrayRef
           
 Args    : None. This is a class method called on TestUtils object.

=cut

method config_constructor {
    if ( $self->build_proper ) {
        my $proper_yml = $self->_build_config_data;
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

 Usage   : This is a private method, don't use it directly.
           
 Function: Create temporary configuration files for testing Transposome.

                                                                            Return_type
 Returns : A config file                                                    Scalar
           
 Args    : None. This is a class method called on TestUtils object.

=cut

method _build_config_data {
    my $tmpyml = File::Temp->new(
        TEMPLATE => "transposome_config_XXXX",
        DIR      => 't',
        SUFFIX   => ".yml",
        UNLINK   => 0
    );

    my $tmpyml_name = $tmpyml->filename;

    my $seq_file  = $self->seq_file;
    my $repeat_db = $self->repeat_db;
    my $test      = TestUtils->new( build_proper => 1, destroy => 0 );
    my $blast     = $test->blast_constructor;
    my ($blfl)    = @$blast;

    say $tmpyml "blast_input:";
    say $tmpyml "  - sequence_file:     $seq_file";
    say $tmpyml "  - sequence_num:      10";
    say $tmpyml "  - cpu:               1";
    say $tmpyml "  - thread:            1";
    say $tmpyml "  - output_directory:  t/test_transposome_cli_out";
    say $tmpyml "clustering_options:";
    say $tmpyml "  - in_memory:         1";
    say $tmpyml "  - percent_identity:  90";
    say $tmpyml "  - fraction_coverage: 0.55";
    say $tmpyml "  - merge_threshold:   2";
    say $tmpyml "annotation_input:";
    say $tmpyml "  - repeat_database:  $repeat_db";
    say $tmpyml "annotation_options:";
    say $tmpyml "  - cluster_size:     1";
    say $tmpyml "  - blast_evalue:     10";
    say $tmpyml "output:";
    say $tmpyml "  - run_log_file:       t_log.txt";
    say $tmpyml "  - cluster_log_file:   t_cluster_report.txt";

    return $tmpyml_name;
}

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

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
