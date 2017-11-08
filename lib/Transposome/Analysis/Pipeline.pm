package Transposome::Analysis::Pipeline;

use 5.010;
use Moose;
use List::Util qw(sum max);
use File::Path qw(make_path remove_tree);
use Storable   qw(thaw);
use POSIX      qw(strftime);
use Path::Class::File;
use File::Basename;
use File::Spec;
use File::Find;
use Archive::Tar;
use Transposome::SeqUtil;
use Transposome::SeqFactory;
use Transposome::Run::Blast;
use Transposome::PairFinder;
use Transposome::Cluster;
use Transposome::Annotation;
use namespace::autoclean;
#use Data::Dump::Color;

with 'Transposome::Role::File'; 

=head1 NAME

Transposome::Analysis::Pipeline - Run individual analysis steps of Transposome

=head1 VERSION

Version 0.12.0

=cut

our $VERSION = '0.12.0';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    use Transposome::Analysis::Pipeline;


=cut

has 'debug' => (
    is         => 'ro',
    isa        => 'Bool',
    predicate  => 'has_debug',
    lazy       => 1,
    default    => 0,
);

=head1 METHODS

=head2 run_blast

 Title   : run_blast

 Usage   : Do not use directly. This is a class method for running parts of
           the Transposome analysis.
           
 Function: Run the all vs. all BLAST for determining pairwise similarity 
           between WGS reads.

                                                                     Return_type
 Returns : The resulting BLAST database                              Scalar

                                                                     Arg_type
 Args    : Hash of configuration values for Transposome the          HashRef
           analysis

=cut

sub run_blast {
    my $self = shift;
    my ($te_config_obj) = @_;
    my $config_file = $self->config;

    my $blast = Transposome::Run::Blast->new( 
	config     => $config_file,
	file       => $te_config_obj->{sequence_file},
	format     => $te_config_obj->{sequence_format},                                     
        dir        => $te_config_obj->{output_directory},                                      
        threads    => $te_config_obj->{thread},
        cpus       => $te_config_obj->{cpu},
        seq_num    => $te_config_obj->{sequence_num},
        verbose    => 1 
    );
    
    my $blastdb = $blast->run_allvall_blast;

    return $blastdb;
}

=head2 find_pairs

 Title   : find_pairs

 Usage   : Do not use directly. This is a class method for running parts of
           the Transposome analysis.
           
 Function: Find high-scoring pairs of reads to form edges for graph-based
           clustering.

                                                                     Return_type
 Returns : In order, 1) an index mapping the sequence ID and the     Scalar
                        sequence index used for clustering
                     2) a file containing the index of each sequence Scalar
                        and match score
                     3) a file containg the pairwise information     Scalar
                        for each best scoring match

                                                                     Arg_type
 Args    : In order, 1) a hash of configuration values for the       HashRef
                        Transposome analysis
                     2) the BLAST database                           Scalar

=cut

sub find_pairs {
    my $self = shift;
    my ($te_config_obj, $blastdb) = @_;
    my $config_file = $self->config;

    my $blast_res = Transposome::PairFinder->new( 
	config           => $config_file,
	file             => $blastdb,  
	dir              => $te_config_obj->{output_directory},
	in_memory        => $te_config_obj->{in_memory},
	percent_identity => $te_config_obj->{percent_identity},
	alignment_length => $te_config_obj->{alignment_length},
	verbose          => 1 
    );
    
    my ($idx_file, $int_file, $edge_file) = $blast_res->parse_blast;
    unlink $blastdb;

    return ($idx_file, $int_file, $edge_file);
}

=head2 make_clusters

 Title   : make_clusters

 Usage   : Do not use directly. This is a class method for running parts of
           the Transposome analysis.
           
 Function: Construct clusters in FASTA format based on high-scoring pairs 
           and split paired-end reads.

                                                                     Return_type
 Returns : An object with summary statistics of clustering           HashRef

                                                                     Arg_type
 Args    : In order, 1) a hash of configuration values for the       HashRef
                        Transposome analysis 
                     2) an index mapping the sequence ID and the     Scalar
                        sequence index used for clustering
                     3) a file containing the index of each          Scalar 
                        sequence and match score
                     4) a file containg the pairwise information     Scalar
                        for each best scoring match

=cut

sub make_clusters {
    my $self = shift;
    my ($te_config_obj, $idx_file, $int_file, $edge_file) = @_;
    my $config_file = $self->config;

    # we set the 'seqtype' explicitly to ensure Casava 1.8+ headers are parsed correctly
    my $memstore = Transposome::SeqUtil->new( 
	file      => $te_config_obj->{sequence_file}, 
	in_memory => $te_config_obj->{in_memory},
	format    => $te_config_obj->{sequence_format},
        dir       => $te_config_obj->{output_directory},
        seqtype   => 'illumina',
    );

    my ($seqs, $seqct, $seq_dbm) = $memstore->store_seq;

    my $cluster = Transposome::Cluster->new( 
        config          => $config_file,
        file            => $int_file,
        dir             => $te_config_obj->{output_directory},
        merge_threshold => $te_config_obj->{merge_threshold},
        cluster_size    => $te_config_obj->{cluster_size},
        verbose         => 1,
        in_memory       => $te_config_obj->{in_memory} 
    );
    
    my $comm = $cluster->louvain_method;
    my $cluster_file = $cluster->make_clusters($comm, $idx_file);
    my ($read_pairs, $vertex, $uf, $dbm) 
        = $cluster->find_pairs({ cluster_file     => $cluster_file, 
                                 cluster_log_file => $te_config_obj->{cluster_log_file},
                                 total_seq_num    => $seqct });
 
    my $cluster_data
       = $cluster->merge_clusters({ graph_vertices         => $vertex,
                                    sequence_hash          => $seqs,
                                    read_pairs             => $read_pairs,
                                    cluster_log_file       => $te_config_obj->{cluster_log_file},
                                    graph_unionfind_object => $uf,
                                    dbm_file               => $dbm });

    $cluster_data->{total_sequence_num} = $seqct;
    unlink $idx_file, $int_file, $edge_file;
    untie %$seqs unless $te_config_obj->{in_memory};
    unlink $seq_dbm if defined $seq_dbm && -e $seq_dbm;

    return $cluster_data;
}

=head2 annotate_clusters

 Title   : annotate_clusters

 Usage   : Do not use directly. This is a class method for running parts of
           the Transposome analysis.
           
 Function: Assign transposon annotations to each FASTA cluster and singleton.

 Returns : None. This is a class method of Transposome::Analysis::Pipeline.

                                                                     Arg_type
 Args    : In order, 1) a hash of configuration values for the       HashRef 
                        Transposome analysis 
                     2) the full PATH to the directory of clusters   Scalar
                        in FASTA that will be annotated
                     3) the total sequence number in the analysis    Scalar
                     4) the total number of clustered sequences      Scalar

=cut

sub annotate_clusters {
    my $self = shift;
    my ($te_config_obj, $cls_dir_path, $seqct, $clsct) = @_;
    my $config_file = $self->config;

    my @clsfastas;
    find( sub { push @clsfastas, $File::Find::name if -f and /\.fas$/ }, $cls_dir_path );

    my ($singletons_file_path) = grep { /singletons/ } @clsfastas;

    my $annotation = Transposome::Annotation->new( 
	config   => $config_file,
	database => $te_config_obj->{repeat_database},
	dir      => $te_config_obj->{output_directory},
	file     => $te_config_obj->{cluster_log_file},
	threads  => $te_config_obj->{thread},
	cpus     => $te_config_obj->{cpu},
	verbose  => 1 
    );

    my $annotation_results = $annotation->annotate_clusters({
            cluster_directory  => $cls_dir_path, 
            singletons_file    => $singletons_file_path, 
            total_sequence_num => $seqct, 
            total_cluster_num  => $clsct });

    $annotation->clusters_annotation_to_summary( $annotation_results );

    my $outdir       = dirname($cls_dir_path);
    my $cls_res_dir  = basename($cls_dir_path);
    my $anno_res_dir = join "_", basename($cls_res_dir), "annotations";
    chdir $outdir;

    my $cls_tar_file  = $cls_res_dir.".tgz"; 
    my $anno_tar_file = $anno_res_dir.".tgz";

    my (@clusters, @annotations);
    find( sub { push @clusters,    $File::Find::name }, $cls_res_dir );
    find( sub { push @annotations, $File::Find::name }, $anno_res_dir );

    my $ctar = Archive::Tar->new;
    $ctar->add_files(@clusters);
    $ctar->write($cls_tar_file, &COMPRESS_GZIP);

    my $atar = Archive::Tar->new;
    $atar->add_files(@annotations);
    $atar->write($anno_tar_file, &COMPRESS_GZIP);
    
    remove_tree( $cls_res_dir,  { safe => 1 } );
    remove_tree( $anno_res_dir, { safe => 1 } );
    
    return;
}

=head2 get_blastdb

 Title   : get_blastdb

 Usage   : Do not use directly. This is a class method for running parts of
           the Transposome analysis.
           
 Function: Find a BLAST database generated by the 'blast' analysis
           for finding high-scoring pairs.

                                                                     Return_type
 Returns : The BLAST database for finding graph edges                Scalar

                                                                     Arg_type
 Args    : Hash of configuration values for the Transposome          HashRef 
           analysis

=cut

sub get_blastdb {
    my $self = shift;
    my ($te_config_obj) = @_;

    my $blastdb;
    find(sub { $blastdb = $File::Find::name if -f and /\.bln$/, }, $te_config_obj->{output_directory} );

    return $blastdb;
}

=head2 get_cluster_files

 Title   : get_cluster_files

 Usage   : Do not use directly. This is a class method for running parts of
           the Transposome analysis.
           
 Function: Find a integer, index and edge files generated by the 'findpairs' 
           analysis for clustering.

                                                                     Return_type
 Returns : Hash of integer, index and edge file PATHs used           HashRef
           for clustering 

                                                                     Arg_type
 Args    : Hash of configuration values for the Transposome          HashRef 
           analysis

=cut

sub get_cluster_files {
    my $self = shift;
    my ($te_config_obj) = @_;

    my @files;
    find(sub { push @files, $File::Find::name if -f and /\.int$|\.idx$|\.edges$/, }, $te_config_obj->{output_directory} );

    my %clsfiles;
    for my $file (@files) {
        if ($file =~ /\.int$/) {
            $clsfiles{int} = $file;
        }
        elsif ($file =~ /\.idx$/) {
            $clsfiles{idx} = $file;
        }
        elsif ($file =~ /\.edges$/) {
            $clsfiles{edges} = $file;       
        }
    }

    return \%clsfiles;
}

=head2 get_cluster_data

 Title   : get_cluster_data

 Usage   : Do not use directly. This is a class method for running parts of
           the Transposome analysis.
           
 Function: Get clustering statistics from the Transposome log for calculating 
           annotation summary information.

                                                                     Return_type
 Returns : Hash of the total sequence number in the analysis,        HashRef
           the total clustered number, and the PATH to the
           clusters that will be used for annotation

                                                                     Arg_type
 Args    : Hash of configuration values for the Transposome          HashRef
           analysis

=cut

sub get_cluster_data {
    my $self = shift;
    my ($te_config_obj) = @_;

    my $log = File::Spec->catfile($te_config_obj->{output_directory}, $te_config_obj->{run_log_file});
    open my $in, '<', $log or die $!;

    my $clsct;
    while (my $line = <$in>) {
        chomp $line;
        
        if ($line =~ /Results - Total number of clustered reads:  (\d+)./) {
            $clsct = $1;
        }
    }
    close $in;

    my $seqobj = Transposome::SeqFactory->new( file   => $te_config_obj->{sequence_file}, 
					       format => $te_config_obj->{sequence_format} )->make_seqio_object;

    my $seqnum = 0;
    while (my $seqio = $seqobj->next_seq) {
        ++$seqnum if $seqio->has_seq;
    }

    my $clsdir;
    find( sub { $clsdir = $File::Find::name if -d and /cls_fasta_files/ }, $te_config_obj->{output_directory} );

    my %cluster_data = (
        total_ct     => $seqnum,
        clustered_ct => $clsct,
        cluster_dir  => $clsdir,
    );

    return \%cluster_data;
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

    perldoc Transposome::Analysis::Pipeline


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2017 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
