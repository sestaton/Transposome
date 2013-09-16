#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use lib qw(../../blib/lib t/lib);
use Transposome;
use Transposome::Run::Blast;
use TestUtils;

use Test::More tests => 2;

my $test = TestUtils->new( seq_file     => 't/test_data/t_reads.fas',
			   repeat_db    => 't/test_data/t_db.fas', 
			   destroy      => 0,
                           build_proper => 1 );

my $conf = $test->config_constructor;
my ($conf_file) = @$conf;

my $trans_obj = Transposome->new( config => $conf_file );
ok ( $trans_obj->get_config, 'Configuration data loaded from file correctly' );
my $config = $trans_obj->get_config;

#ok( system("formatdb"), 'Can create database for mgblast' ); # test loading attributes instead
#ok( system("mgblast"),  'Can execute mgblast' );

my $blast = Transposome::Run::Blast->new( file      => $config->{sequence_file},
					  dir       => $config->{output_directory},
					  threads   => 1,
					  cpus      => 1,
					  seq_num   => $config->{sequence_num} );
#                                          report    => $config->{report_file} );

my $blastdb = $blast->run_allvall_blast;
ok ( defined($blastdb), 'Can execute all vs. all blast correctly' );

system("rm -rf t/test_transposome_cli_out t/transposome_config* t/transposome_mgblast*");
