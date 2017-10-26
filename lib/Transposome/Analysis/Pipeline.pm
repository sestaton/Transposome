package Transposome::Analysis::Pipeline;

use 5.010;
use Moose;
use List::Util qw(sum max);
use File::Path qw(make_path remove_tree);
use Storable   qw(thaw);
use POSIX      qw(strftime);
use Log::Any   qw($log);
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

#with 'Transposome::Role::File', 
#     'Transposome::Role::Util';

=head1 NAME

Transposome::Analysis::Pipeline - Run individual analysis steps of Transposome

=head1 VERSION

Version 0.11.3

=cut

our $VERSION = '0.11.3';
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

=head2 annotate_clusters

 Title   : annotation_clusters

 Usage   : $annotation->annotate_clusters();
           
 Function: Runs the annotation pipeline within Transposome.

                                                                           
 Returns : A Perl hash containing the cluster annotation results.

 Args    : A Perl hash containing data for annotation.

           A description of the hash values taken:
                                                                            Arg_type
           cluster_directory - the directory of cluster FASTA files         Scalar
           singletons_file - the FASTA file of singleton sequences          Scalar
           total_sequence_num - the number of sequences that went into      Scalar
                                the clustering (returned from store_seq() 
                                from Transposome::SeqStore), 
           total_cluster_num - the total number of clusters (also           Scalar 
                               returned from make_clusters() from 
                               Transposome::Cluster).

=cut

sub run_blast {
    my $self = shift;
    my ($config_file, $te_config_obj) = @_;

    #my $init_config = defined $analysis && $analysis eq 'blast' ? 1 : 0;
    #my ( $t0, $log ) = init_transposome( $config )
        #if defined $analysis && $analysis eq 'blast';
    
    my $blast = Transposome::Run::Blast->new( 
	configfile => $config_file,
	file       => $te_config_obj->{sequence_file},
	format     => $te_config_obj->{sequence_format},                                     
        dir        => $te_config_obj->{output_directory},                                      
        threads    => $te_config_obj->{thread},
        cpus       => $te_config_obj->{cpu},
        seq_num    => $te_config_obj->{sequence_num},
        verbose    => 1 
    );
    
    my $blastdb = $blast->run_allvall_blast;

    #log_interval( $t0, $log ) if $analysis eq 'blast';

    ##TODO: get blastdb somehow
    return $blastdb;
}

sub find_pairs {
    my $self = shift;
    my ($config_file, $te_config_obj, $blastdb) = @_;

    #my $init_config = defined $analysis && $analysis eq 'findpairs' ? 1 : 0;
    #my ( $t0, $log ) = init_transposome( $config )
        #if defined $analysis && $analysis eq 'findpairs';

    my $blast_res = Transposome::PairFinder->new( 
	configfile       => $config_file,
	file             => $blastdb,  
	dir              => $te_config_obj->{output_directory},
	in_memory        => $te_config_obj->{in_memory},
	percent_identity => $te_config_obj->{percent_identity},
	alignment_length => $te_config_obj->{alignment_length},
	verbose          => 1 
    );
    
    my ($idx_file, $int_file, $hs_file) = $blast_res->parse_blast;
    unlink $blastdb;
    #log_interval( $t0, $log ) if $analysis eq 'findpairs';


    ##TODO: use find() to return the files below from the output dir
    return ($idx_file, $int_file, $hs_file);
}

sub make_clusters {
    my $self = shift;
    my ($config_file, $te_config_obj, $idx_file, $int_file, $hs_file) = @_;
    
    #my $init_config = defined $analysis && $analysis eq 'cluster' ? 1 : 0;
    #my ( $t0, $log ) = init_transposome( $config )
        #if defined $analysis && $analysis eq 'cluster';

    my $memstore = Transposome::SeqUtil->new( 
	file      => $te_config_obj->{sequence_file}, 
	in_memory => $te_config_obj->{in_memory},
	format    => $te_config_obj->{sequence_format},
        dir       => $te_config_obj->{output_directory} 
    );

    my ($seqs, $seqct, $seq_dbm) = $memstore->store_seq;

    my $cluster = Transposome::Cluster->new( 
        configfile      => $config_file,
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
    unlink $idx_file, $int_file, $hs_file;
    untie %$seqs unless $te_config_obj->{in_memory};
    unlink $seq_dbm if defined $seq_dbm && -e $seq_dbm;

    #log_interval( $t0, $log ) if $analysis eq 'cluster';

    ##TODO: parse log to return the clustered sequence number required for annotation

    return $cluster_data;
}

sub annotate_clusters {
    my ($config_file, $te_config_obj, $cls_dir_path, $seqct, $cls_tot) = @_;

    #my $init_config = defined $analysis && $analysis eq 'annotation' ? 1 : 0;
    #my ( $t0, $log ) = init_transposome( $config )
        #if defined $analysis && $analysis eq 'annotation';

    my @clsfastas;
    find( sub { push @clsfastas, $File::Find::name if -f and /\.fas$/ }, $cls_dir_path );

    my ($singletons_file_path) = grep { /singletons/ } @clsfastas;

    my $annotation = Transposome::Annotation->new( 
	configfile => $config_file,
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
            total_cluster_num  => $cls_tot });

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

    my $atar = Archive::Tar->new;
    $atar->add_files(@annotations);
    $atar->write($anno_tar_file, &COMPRESS_GZIP);
    
    remove_tree( $cls_res_dir,  { safe => 1 } );
    remove_tree( $anno_res_dir, { safe => 1 } );
    
    #log_interval( $t0, $log ) 
        #if defined $analysis && $analysis eq 'annotation';

    return;
}

sub get_blastdb {
    my $self = shift;
    my ($te_config_obj) = @_;

    my $blastdb;
    find(sub { $blastdb = $File::Find::name if -f and /\.bln$/, }, $te_config_obj->{output_directory} );

    return $blastdb;
}

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

    perldoc Transposome::Annotation


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2017 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
