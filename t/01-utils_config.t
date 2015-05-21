#!/usr/bin/env perl

use strict;
use warnings;
use File::Spec;
use Transposome;

use aliased 'Transposome::Test::TestFixture';
use Test::Most tests => 8;

my $seqfile  = File::Spec->catfile('t', 'test_data', 't_reads.fas.gz');
my $repeatdb = File::Spec->catfile('t', 'test_data', 't_db.fas');
 
my $tf_obj_destroy = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 1,
    build_proper => 1
);

ok( $tf_obj_destroy->config_constructor, 'Can build and destroy configuration data for testing' );


my $tf_obj_keep = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1
);

my $keep_conf = $tf_obj_keep->config_constructor;
my ($keep_conf_file) = @$keep_conf;

ok( defined($keep_conf_file), 'Correctly build and keep configuration data for testing' );

my $tf_obj_noseqfile = TestFixture->new(
    seq_file     => 'test_seqfile', # does not exist
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,      
    destroy      => 0,
    build_proper => 1
);

my $noseqfile_conf = $tf_obj_noseqfile->config_constructor;
my ($noseqfile_conf_file) = @$noseqfile_conf;

my $trans_obj_noseqfile = Transposome->new( config => $noseqfile_conf_file );

dies_ok { $trans_obj_noseqfile->get_configuration } 'Correctly handled missing sequence file in configuration';

my $tf_obj_norepeatdb = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => 'test_db',      # does not exist
    destroy      => 0,
    build_proper => 1
);

my $norepeatdb_conf = $tf_obj_norepeatdb->config_constructor;
my ($norepeatdb_conf_file) = @$norepeatdb_conf;

my $trans_obj_norepeatdb = Transposome->new( config => $norepeatdb_conf_file );

dies_ok { $trans_obj_norepeatdb->get_configuration } 'Correctly handled missing repeat database file in configuration';

my $tf_obj_noseqnum = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1,
    exclude      => 'sequence_num',
);

my $noseqnum_conf = $tf_obj_noseqnum->config_constructor;
my ($noseqnum_conf_file) = @$noseqnum_conf;

ok( defined($noseqnum_conf_file), 'Correctly build configuration data without sequence_num' );

my $tf_obj_nocpu = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1,
    exclude      => 'cpu',
);

my $nocpu_conf = $tf_obj_nocpu->config_constructor;
my ($nocpu_conf_file) = @$nocpu_conf;

ok( defined($nocpu_conf_file), 'Correctly build configuration data without cpu' );

my $tf_obj_noblasteval = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1,
    exclude      => 'blast_evalue',
);

my $noblasteval_conf = $tf_obj_noblasteval->config_constructor;
my ($noblasteval_conf_file) = @$noblasteval_conf;

ok( defined($noblasteval_conf_file), 'Correctly build configuration data without blast_evalue' );

my $tf_obj_nomergethresh = TestFixture->new(
    seq_file     => $seqfile,
    seq_format   => 'fasta',
    repeat_db    => $repeatdb,
    destroy      => 0,
    build_proper => 1,
    exclude      => 'merge_threshold',
);

my $nomergethresh_conf = $tf_obj_nomergethresh->config_constructor;
my ($nomergethresh_conf_file) = @$nomergethresh_conf;

ok( defined($nomergethresh_conf_file), 'Correctly build configuration data without merge_threshold' );

unlink glob("t/transposome_mgblast_*"); 
unlink glob("t/transposome_config_*");

