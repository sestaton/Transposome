package Transposome::Log;

use 5.010;
use Moose;
use File::Basename;
use File::Spec;
use DateTime;
use Log::Log4perl;
use Log::Any::Adapter;
use Log::Any;
use POSIX       qw();
use Time::HiRes qw();
use Lingua::EN::Inflect;
use Transposome;
use namespace::autoclean;
#use Data::Dump::Color;

with 'Transposome::Role::File'; 

=head1 NAME

Transposome::Log - Base class for handling Transposome logging functions

=head1 VERSION

Version 0.12.0

=cut

our $VERSION = '0.12.0';
#$VERSION = eval $VERSION;

=head1 SYNOPSIS

    use Transposome::Log;

=cut

has 'log_to_screen' => (
    is         => 'ro',
    isa        => 'Bool',
    predicate  => 'has_log_to_screen',
    lazy       => 1,
    default    => 1,
);

=head1 METHODS

=head2 get_transposome_logger

 Title   : get_transposome_logger

 Usage   : my $conf_file = 'transposome_config.yml';
           my $log_obj = Tranposome::Log->new( config => $conf_file );
           my $logger = $log_obj->get_transposome_logger;
           
 Function: Returns a logging object to be used with any Transposome class methods

                                                                     Return_type
 Returns : Log4perl object of the 'Transposome' category             Object

 Args    : None. This is class method of Transposome::Log.        

=cut

sub get_transposome_logger {
    my $self = shift;
    my $config_file = $self->config;
    my $to_screen   = $self->log_to_screen;

    # Parse configuration                                   
    my $trans_obj = Transposome->new( config => $config_file );
    my $config = $trans_obj->get_configuration;
    
    my $log_file = File::Spec->catfile($config->{output_directory}, $config->{run_log_file});
    my $category = 'log4perl.category.Transposome      = INFO, Logfile';
    $category = $to_screen ? $category.', Screen' : $category;

    my $conf = qq{
    $category

    log4perl.appender.Logfile          = Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename = $log_file
    log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = %m%n
    };

    if ($to_screen) {
	$conf .= qq{
        log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.stderr  = 1
        log4perl.appender.Screen.layout  = Log::Log4perl::Layout::SimpleLayout
        };
    }

    Log::Log4perl::init( \$conf );
    Log::Any::Adapter->set('Log4perl');
    my $log = Log::Any->get_logger( category => "Transposome" );

    return $log;
}

=head2 init_transposome

 Title   : init_transposome

 Usage   : my $conf_file = 'transposome_config.yml';
           my $log_obj = Tranposome::Log->new( config => $conf_file );
   
           my $te_conf_obj = Transposome->new( config => $conf_file)->parse_configuration;
           my ($t0, $logger) = $log_obj->init_transposome($te_config_obj);
           
 Function: Returns a logging object to be used with any Transposome class methods and the 
           time the object was initialized.

                                                                     Return_type
 Returns : In order, 1) the time the object was initializedLog4perl  Object
                        object of the 'Transposome' category        
                     2) the time the object was initialized          Scalar

                                                                     Arg_type
 Args    : Hash of configuration values for Transposome analysis     HashRef

=cut

sub init_transposome {
    my $self = shift;
    my ($te_config_obj) = @_;
    my $config_file = $self->config;

    my $log = $self->get_transposome_logger($config_file);
    
    my $t0 = [Time::HiRes::gettimeofday()];
    my $ts = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("======== Transposome version: $VERSION (started at: $ts) ========");
    $log->info("Configuration - Log file for monitoring progress and errors: $te_config_obj->{run_log_file}");
    $log->info("Configuration - Sequence file:                               $te_config_obj->{sequence_file}");
    $log->info("Configuration - Sequence format:                             $te_config_obj->{sequence_format}");
    $log->info("Configuration - Sequence number for each BLAST process:      $te_config_obj->{sequence_num}");
    $log->info("Configuration - Number of CPUs per thread:                   $te_config_obj->{cpu}");
    $log->info("Configuration - Number of threads:                           $te_config_obj->{thread}");
    $log->info("Configuration - Output directory:                            $te_config_obj->{output_directory}");
    $log->info("Configuration - In-memory analysis:                          $te_config_obj->{in_memory}");
    $log->info("Configuration - Percent identity for matches:                $te_config_obj->{percent_identity}");
    $log->info("Configuration - Fraction coverage for pairwise matches:      $te_config_obj->{fraction_coverage}");
    $log->info("Configuration - Merge threshold for clusters:                $te_config_obj->{merge_threshold}");
    $log->info("Configuration - Minimum cluster size for annotation:         $te_config_obj->{cluster_size}");
    $log->info("Configuration - BLAST e-value threshold for annotation:      $te_config_obj->{blast_evalue}"); 
    $log->info("Configuration - Repeat database for annotation:              $te_config_obj->{repeat_database}");
    $log->info("Configuration - Log file for clustering/merging results:     $te_config_obj->{cluster_log_file}");

    return ($t0, $log);
}

=head2 log_interval

 Title   : log_interval

 Usage   : my $conf_file = 'transposome_config.yml';
           my $log_obj = Tranposome::Log->new( config => $conf_file );
   
           $log_obj->log_interval($t0, $log);
           
 Function: Given a start time and a log object, this method will log the interval
           of time that has passed from beginning to end in a human-readable format.

 Returns : None. This is class method of Transposome::Log.

                                                                     Arg_type
 Args    : In order, 1) a starting time for calculating the          Scalar
                        time interval
                     2) a logging object for writing the results     Object

=cut

sub log_interval {
    my $self = shift;
    my ($t0, $log) = @_;
    
    my $t1    = [Time::HiRes::gettimeofday()];
    my $t0_t1 = Time::HiRes::tv_interval($t0, $t1);
    my $dt    = DateTime->from_epoch( epoch => 0 );

    $dt = $dt->add( seconds => $t0_t1 );
    $dt = $dt - DateTime->from_epoch( epoch => 0 );
    
    my @time;
    push @time, $dt->days . Lingua::EN::Inflect::PL_N( ' day', $dt->days ) if $dt->days;
    push @time, $dt->hours . Lingua::EN::Inflect::PL_N( ' hour', $dt->hours ) if $dt->hours;
    push @time, $dt->minutes . Lingua::EN::Inflect::PL_N( ' minute', $dt->minutes ) if $dt->minutes;
    push @time, $dt->seconds . Lingua::EN::Inflect::PL_N( ' second', $dt->seconds ) if $dt->seconds;
    my $timestr = join ', ', @time;
    
    my $fs = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("======== Transposome completed at: $fs. Elapsed time: $timestr. ========");

    return;
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

    perldoc Transposome::Log


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2017 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
