#!/usr/bin/env perl

use 5.012;
use strict;
use warnings;
use Cwd;
use File::Spec;
use File::Path qw(remove_tree);
use Transposome;
use Transposome::Run::Blast;
use Log::Log4perl;

use aliased 'Transposome::Test::TestUtils';
use Test::More tests => 4;

my $fasfile  = File::Spec->catfile('t', 'test_data', 't_reads.fas');
my $fqfile   = File::Spec->catfile('t', 'test_data', 't_reads.fq');
my $repeatdb = File::Spec->catfile('t', 'test_data', 't_db.fas');

mgblast_fasta($fasfile, $repeatdb);
mgblast_fastq($fqfile,  $repeatdb);

sub mgblast_fasta {
    my ($fasfile, $repeatdb) = @_;
    my $test = TestUtils->new(
			      seq_file     => $fasfile,
			      repeat_db    => $repeatdb,
			      destroy      => 0,
			      build_proper => 1
			      );

    my $conf = $test->config_constructor;
    my ($conf_file) = @$conf;

    my $cwd      = getcwd();
    my $bin      = File::Spec->catdir($cwd, 'bin');
    my $mgblast  = File::Spec->catfile($bin, 'mgblast');
    my $formatdb = File::Spec->catfile($bin, 'formatdb');

    my $trans_obj = Transposome->new( config => $conf_file );
    ok( $trans_obj->get_configuration, 'Configuration data loaded from file correctly' );
    my $config = $trans_obj->get_configuration;
    
    my $log_conf = qq{
	    log4perl.category.Transposome       = INFO, Logfile
	    
	    log4perl.appender.Logfile           = Log::Log4perl::Appender::File
	    log4perl.appender.Logfile.filename  = t/$config->{run_log_file}
	    log4perl.appender.Logfile.layout    = Log::Log4perl::Layout::PatternLayout
	    log4perl.appender.Logfile.layout.ConversionPattern = %m%n
	};
    
    Log::Log4perl::init( \$log_conf );
    
    my $blast = Transposome::Run::Blast->new(
					     file          => $config->{sequence_file},
					     dir           => $config->{output_directory},
					     threads       => 1,
					     cpus          => 1,
					     seq_num       => $config->{sequence_num},
					     mgblast_exec  => $mgblast,
					     formatdb_exec => $formatdb
					     );
    
    my $blastdb = $blast->run_allvall_blast;
    ok( defined($blastdb), 'Can execute all vs. all blast correctly' );

    remove_tree("t/test_transposome_cli_out");
    unlink glob("t/transposome_config*");
    unlink glob("t/transposome_allvall_megablast*");
    unlink "t/$config->{run_log_file}";
    unlink "t_log.txt";
    unlink "formatdb.log";
}

sub mgblast_fastq {
    my ($fqfile, $repeatdb) = @_;
    my $test = TestUtils->new(
                              seq_file     => $fqfile,
                              repeat_db    => $repeatdb,
                              destroy      => 0,
                              build_proper => 1
                              );

    my $conf = $test->config_constructor;
    my ($conf_file) = @$conf;
    
    my $cwd      = getcwd();
    my $bin      = File::Spec->catdir($cwd, 'bin');
    my $mgblast  = File::Spec->catfile($bin, 'mgblast');
    my $formatdb = File::Spec->catfile($bin, 'formatdb');

    my $trans_obj = Transposome->new( config => $conf_file );
    ok( $trans_obj->get_configuration, 'Configuration data loaded from file correctly' );
    my $config = $trans_obj->get_configuration;
    
    my $log_conf = qq{
            log4perl.category.Transposome       = INFO, Logfile
            
            log4perl.appender.Logfile           = Log::Log4perl::Appender::File
            log4perl.appender.Logfile.filename  = t/$config->{run_log_file}
            log4perl.appender.Logfile.layout    = Log::Log4perl::Layout::PatternLayout
            log4perl.appender.Logfile.layout.ConversionPattern = %m%n
        };
    
    Log::Log4perl::init( \$log_conf );
    
    my $blast = Transposome::Run::Blast->new(
                                             file          => $config->{sequence_file},
                                             dir           => $config->{output_directory},
                                             threads       => 1,
                                             cpus          => 1,
                                             seq_num       => $config->{sequence_num},
					     mgblast_exec  => $mgblast,
					     formatdb_exec => $formatdb
                                             );
    
    my $blastdb = $blast->run_allvall_blast;
    ok( defined($blastdb), 'Can execute all vs. all blast correctly' );

    remove_tree("t/test_transposome_cli_out");
    unlink glob("t/transposome_config*");
    unlink glob("t/transposome_allvall_megablast*");
    unlink "t/$config->{run_log_file}";
    unlink "t_log.txt";
    unlink "formatdb.log";
}
