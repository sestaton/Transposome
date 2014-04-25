#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use lib qw(../../blib/lib t/lib);
use Transposome;
use Transposome::Run::Blast;
use TestUtils;
use Log::Log4perl;

use Test::More tests => 2;

my $test = TestUtils->new(
    seq_file     => 't/test_data/t_reads.fas',
    repeat_db    => 't/test_data/t_db.fas',
    destroy      => 0,
    build_proper => 1
);

my $conf = $test->config_constructor;
my ($conf_file) = @$conf;

my $trans_obj = Transposome->new( config => $conf_file );
ok( $trans_obj->get_configuration, 'Configuration data loaded from file correctly' );
my $config = $trans_obj->get_configuration;

my $log_conf = qq{
    log4perl.category.Transposome       = INFO, Logfile

    log4perl.appender.Logfile           = Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename  = t/$config->{run_log_file}
    log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = %m%n
  };

Log::Log4perl::init( \$log_conf );

my $blast = Transposome::Run::Blast->new(
    file    => $config->{sequence_file},
    dir     => $config->{output_directory},
    threads => 1,
    cpus    => 1,
    seq_num => $config->{sequence_num}
);

my $blastdb = $blast->run_allvall_blast;
ok( defined($blastdb), 'Can execute all vs. all blast correctly' );

system("rm -rf t/test_transposome_cli_out t/transposome_config* t/transposome_mgblast* t/$config->{run_log_file} t_log.txt formatdb.log");
