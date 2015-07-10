package Transposome::Cluster;

use 5.010;
use Moose;
use IPC::System::Simple  qw(system capture EXIT_ANY);
use File::Path           qw(make_path);
use POSIX                qw(strftime);
use Log::Any             qw($log);
use DBI;
use Tie::Hash::DBD;
use Graph::UnionFind;
use File::Spec;
use File::Basename;
use Try::Tiny;
use Path::Class::File;
use Config;
use namespace::autoclean;

#use Data::Dump;

with 'Transposome::Role::File', 
     'Transposome::Role::Util';

=head1 NAME

Transposome::Cluster - Clustering and cluster analysis routines in Transposome.

=head1 VERSION

Version 0.09.7

=cut

our $VERSION = '0.09.7';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    use Transposome::Cluster;

    my $clus_obj = Transposome::Cluster->new();
    ...

=cut

has 'in_memory' => (
    is         => 'ro',
    isa        => 'Bool',
    predicate  => 'has_in_memory',
    lazy       => 1,
    default    => 1,
);

has 'merge_threshold' => (
    is       => 'ro',
    isa      => 'Num',
    default  => 0.001,
);

has 'cluster_size' => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has 'bin_dir' => (
    is       => 'rw',
    isa      => 'Path::Class::Dir',
    default  => sub {
	return Path::Class::Dir->new($Config{sitebin})
    },
);

=head1 METHODS

=head2 louvain_method

 Title   : louvain_method
         
 Usage   : my $community = $clus_obj->louvain_method;

 Function: This method generates the community using the method
           of Blondel et al. (e.g., the Louvain method).
                                                                                Return_type
 Returns : A file representing the community structure of repeat                Scalar
           clusters in the genome.

 Args    : None. This is a class method of Transposome::Cluster.

=cut

sub louvain_method {
    my $self = shift;
    # set get paths to class attributes
    my $int_file = $self->file->relative;
    my $out_dir  = $self->dir->relative;
    my $realbin  = $self->bin_dir->resolve;

    my ($lconvert, $lcommunity, $lhierarchy) = $self->_find_community_exes($realbin);

    my ($iname, $ipath, $isuffix) = fileparse($int_file, qr/\.[^.]*/);
    my $cls_bin          = $iname.".bin";              # Community "bin" format
    my $cls_tree         = $iname.".tree";             # hierarchical tree of clustering results
    my $cls_tree_weights = $cls_tree.".weights";       # bit score, the weights applied to clustering
    my $cls_tree_log     = $cls_tree.".log";           # the summary of clustering results at each level of refinement
    my $hierarchy_err    = $cls_tree.".hierarchy.log"; # hierarchical tree building log (not actually used)
    my $levels;                                        # the number of hierarchical levels

    my $cls_bin_path          = File::Spec->catfile($out_dir, $cls_bin);
    my $cls_tree_path         = File::Spec->catfile($out_dir, $cls_tree);
    my $cls_tree_weights_path = File::Spec->catfile($out_dir, $cls_tree_weights);
    my $cls_tree_log_path     = File::Spec->catfile($out_dir, $cls_tree_log);
    my $hierarchy_err_path    = File::Spec->catfile($out_dir, $hierarchy_err);

    # log results
    my $st = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("Transposome::Cluster::louvain_method started at:         $st.");

    try {
	system([0..5], "$lconvert -i $int_file -o $cls_bin_path -w $cls_tree_weights_path");
    }
    catch {
	$log->error("Louvain 'convert' failed. Caught error: $_.");
	exit(1);
    };

    try {
	system([0..5],"$lcommunity $cls_bin_path -l -1 -w $cls_tree_weights_path -v >$cls_tree_path 2>$cls_tree_log_path");
    }
    catch {
	$log->error("Louvain 'community' failed. Caught error: $_.");
	exit(1);
    };

    unlink $cls_bin_path;
    unlink $cls_tree_weights_path;

    try {
	$levels = capture(EXIT_ANY, "grep -c level $cls_tree_log_path");
	chomp $levels;
    }
    catch {
	$log->error("grep failed. Caught error: $_.");
	exit(1);
    };

    my @comm;
    for (my $i = 0; $i <= $levels-1; $i++) {
        my $cls_graph_comm      = $cls_tree.".graph_comm_".$i; 
	my $cls_graph_comm_path = File::Spec->catfile($self->dir, $cls_graph_comm);
	
	try {
	    system([0..5],"$lhierarchy $cls_tree_path -l $i > $cls_graph_comm_path");
	}
	catch {
	    $log->error("Louvain 'hierarchy' failed. Caught error: $_.");
	    exit(1);
	};

	push @comm, $cls_graph_comm;
    }
    unlink $cls_tree_path;

    # log results
    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("Transposome::Cluster::louvain_method completed at:       $ft.");

    return \@comm;
}

=head2 find_pairs

 Title   : find_pairs

 Usage   : my $cluster_file = $cluster->make_clusters($comm, $idx_file);
           
 Function: This method analyzes cluster groupings for clusters having
           split reads above the threshold.

                                                                                 Return_type
 Returns : In order, 1) a data structure containing the read IDs in each         HashRef
                        cluster
                     2) a data structure containing the count of vertices        HashRef
                        seen in the graph
                     3) a Graph::UnionFind object, containg data for finding
                        union in the graph
                                                                                 Arg_type
 Args    : In order, 1) the community file generated by the louvain_method()     Scalar
                        class method of Transposome::Cluster
                     2) the index file generated by the parse_blast() method     Scalar
                        of Transposome::Cluster

=cut

sub find_pairs {
    my $self = shift;
    my ($cluster_data) = @_;
    my $cls_file     = $cluster_data->{cluster_file};
    my $cls_log_file = $cluster_data->{cluster_log_file};
    my $total_seq_num   = $cluster_data->{total_seq_num};
    my $merge_threshold = sprintf("%.0f", $total_seq_num * $self->merge_threshold);
 
    my $out_dir                      = $self->dir->relative;
    my $cls_log_path                 = File::Spec->catfile($out_dir, $cls_log_file);
    my ($clname, $clpath, $clsuffix) = fileparse($cls_file, qr/\.[^.]*/);
    my $cls_file_path                = File::Spec->catfile($clpath.$out_dir, $clname.$clsuffix);
    
    my $uf = Graph::UnionFind->new;

    # log results
    open my $rep, '>', $cls_log_path 
	or die "\n[ERROR]: Could not open file: $cls_log_path\n";
    say $rep "# Cluster connections above threshold";
    my $st = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("Transposome::Cluster::find_pairs started at:             $st.");

    my %vertex;
    my %read_pairs;
    my %mapped_pairs;
    my %cls_conn_ct;

    my $dbm = File::Spec->catfile($out_dir, "transposome_readpairs.dbm");
    my $dbc = File::Spec->catfile($out_dir, "transposome_clusterconn.dbm");

    unless ($self->in_memory) {
	my $rp_dbh = DBI->connect("dbi:SQLite:dbname=$dbm", undef, undef, {
            PrintError       => 0, 
            RaiseError       => 1,
            AutoCommit       => 1,
            FetchHashKeyName => 'NAME_lc',
            synchronous      => 0,
            journal_mode     => 'TRUNCATE'
        });

        tie %read_pairs, "Tie::Hash::DBD", $rp_dbh;

	my $cl_dbh = DBI->connect("dbi:SQLite:dbname=$dbc", undef, undef, {
            PrintError       => 0, 
            RaiseError       => 1,
            AutoCommit       => 1,
            FetchHashKeyName => 'NAME_lc',
            synchronous      => 0,
            journal_mode     => 'TRUNCATE'
        });

        tie %cls_conn_ct, "Tie::Hash::DBD", $cl_dbh;
    }

    {
	local $/ = '>';
        
        open my $in, '<', $cls_file_path or die "\n[ERROR]: Could not open file: $cls_file_path\n";   
        while (my $line = <$in>) {
            $line =~ s/>//g;
            next if !length($line);
            my ($clsid, $seqids) = split /\n/, $line;
            $clsid =~ s/\s/\_/;
            my @ids = split /\s+/, $seqids;       
	    my $id_key = $self->mk_key(@ids);
            # limit cluster size in .cls file here, if desired
            #push @{$read_pairs{$clsid}}, $_ for @ids;
	    $read_pairs{$clsid} = $id_key;
        }
        close $in;
    }

    #dd \%read_pairs;

    while (my ($cls, $reads) = each %read_pairs) {
	my @read_ids = $self->mk_vec($reads);
        for my $read (@read_ids) {
            my $readbase = $read;
            $readbase =~ s/\/\d$//;
	    push @{$mapped_pairs{$readbase}}, {$read => $cls};
        }
    }

    #untie %read_pairs unless $self->in_memory;
    #unlink $dbm if -e $dbm;

    my ($cls_i, $cls_j);
    my @sep_reads;

    while (my ($allpairs, $reads) = each %mapped_pairs) {
	if (@$reads < 2) {                         # if no pair is found in another cluster,
            delete $mapped_pairs{$allpairs};       # remove this pair
        }
        else {
            push @sep_reads, values %$_ for @$reads;
	    ($cls_i, $cls_j) = sort @sep_reads;
            if ($cls_i =~ /$cls_j/) {              # remove reads that have pairs in the same cluster       
                delete $mapped_pairs{$allpairs};   # which is uninformative for merging clusters
            }
            else {
		my $k = $self->mk_key($cls_i, $cls_j);
                $cls_conn_ct{$k}++;
            }
        }
        @sep_reads = ();
    }

    while (my ($pk, $pv) = each %cls_conn_ct) {
	my ($i, $j) = $self->mk_vec($pk);
        my $i_noct = $i; $i_noct =~ s/\_.*//;
        my $j_noct = $j; $j_noct =~ s/\_.*//;
        if ($pv >= $merge_threshold) {   
	    say $rep join "\t", $i_noct, $j_noct, $pv;
            ++$vertex{$_} for $i, $j;
            $uf->union($i, $j);
        }
    }
    close $rep;
    unlink $cls_file_path;

    untie %cls_conn_ct unless $self->in_memory;
    unlink $dbc if -e $dbc;

    # log results
    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("Transposome::Cluster::find_pairs completed at:           $ft.");

    return (\%read_pairs, \%vertex, \$uf, $dbm);
}

=head2 make_clusters

 Title   : make_clusters

 Usage   :  my $clus_obj = Transposome::Cluster->new();
            my $cluster_file = $clus_obj->make_clusters($comm, $idx_file);

 Function: Create a mapping of the integer IDs required for clustering
           to the read IDs, and return a common file format for
           clusters.

                                                                                 Return_type
 Returns : A cluster file containing information about the                       Scalar
           number of reads in each cluster and the IDs of each
           read belonging to a particular cluster.
                                                                                 Arg_type
 Args    : In order, 1) the community file returned from louvain_method()        Scalar
                        from Transposome::Cluster
                     2) the index file returned from parse_blast() from          Scalar
                         Transposome::PairFinder
           

=cut

sub make_clusters {
    my $self = shift;
    my ($graph_comm, $idx_file) = @_;
    # set paths for make_clusters() method
    my $int_file             = $self->file->relative;
    my $out_dir              = $self->dir->relative;
    my ($iname, $ipath, $isuffix) = fileparse($int_file, qr/\.[^.]*/);
    my $cluster_file         = $iname.".cls";
    my $membership_file      = $cluster_file.".membership.txt";
    my $cluster_file_path    = File::Spec->catfile($out_dir, $cluster_file);
    my $membership_file_path = File::Spec->catfile($out_dir, $membership_file);

    my @graph_comm_sort = reverse sort { ($a =~ /(\d)$/) <=> ($b =~ /(\d)$/) } @$graph_comm;
    my $graph = shift @graph_comm_sort;
    $log->logdie("\n[ERROR]: Community clustering failed. Exiting.\n") unless defined $graph;
    my $graph_path = File::Spec->catfile($out_dir, $graph);
    my %clus;
    my %index;

    # log results
    my $st = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("Transposome::Cluster::make_clusters started at:          $st.");

    open my $idx, '<', $idx_file or die "\n[ERROR]: Could not open file: $idx_file\n";
    while (my $idpair = <$idx>) {
        chomp $idpair;
        my ($readid, $readindex) = split /\s+/, $idpair;
        $index{$readindex} = $readid;
    }
    close $idx;

    open my $mem,'>', $membership_file_path or die "\n[ERROR]: Could not open file: $membership_file_path\n";;
    open my $in, '<', $graph_path or die "\n[ERROR]: Could not open file: $graph_path\n";;
    open my $cls_out, '>', $cluster_file_path or die "\n[ERROR]: Could not open file: $cluster_file_path\n";;

    while (my $line = <$in>) {
        chomp $line;
        my ($i, $j) = split /\s+/, $line;
	push @{$clus{$j}}, $i;
    }
    close $in;

    #dd \%clus;

    my $cls_ct = 0;
    while (my ($cls, $cls_ids) = each %clus) {
	$cls_ct++;
	my $clus_size = @$cls_ids;
        my @clus_members;
	for my $cls_member (@$cls_ids) {
            say $mem "$cls_member $cls_ct";
            if (exists $index{$cls_member}) {
                push @clus_members, $index{$cls_member};
            }
        }
	if (@clus_members) {
	    say $cls_out ">CL$cls_ct $clus_size";
	    say $cls_out join q{ }, @clus_members;
	}
    }
    close $cls_out;
    close $mem;
    unlink $membership_file_path;

    for (@$graph_comm) {
	my $graph_file = File::Spec->catfile($out_dir, $_);
	unlink $graph_file;
    }

    if ($cls_ct == 0) {
	$log->error("No clusters found. This likely results from analyzing too few sequences. 
                     Report this issue if it persists. Exiting.");
	exit(1);
    }

    # log results
    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("Transposome::Cluster::make_clusters completed at:        $ft.");

    return $cluster_file;
}

=head2 merge_clusters

 Title   : merge_clusters
 Usage   : 
           
 Function: Join clusters based on threshold of split paired reads.  

                                                                                 
 Returns : A Perl hash containing the clustering results.

           The following is an example data structure returned by 
           the merge_clusters method:

           { cluster_directory    => $cls_dir_path,
             singletons_file      => $singletons_file_path,
             merged_clusters_file => $cls_with_merges_path,
             total_cluster_num    => $cls_tot }

           A description of the hash values returned:                            Return_type

           cluster_directory -  path to the results directory                    Scalar
           merged_clusters_file - filename (path to) the cluster file with       Scalar
                                  unions above threshold (see below)
           singletons_file - filename (path to) the singletons file              Scalar
           total_cluster_num - the total number of reads clustered               Scalar

           The cluster file is in a format similar to FASTA, where the           
           identifier specifies the cluster ID followed by the size. The
           second line of each record contains each read ID separated by 
           a space. The 'G' indicates a group created by joining clusters.
           
           E.g., 
        
               >G1 3
               read1 read2 read3 
                                                                                 Arg_type
 Args    : A Perl hash containing the clustering results.                        HashRef
           
           The following is an example data structure taken by the 
           merge_clusters method.

           { graph_vertices         => $vertex,
             sequence_hash          => $seqs,
             read_pairs             => $read_pairs,
             dbm_file               => $dbm,
             cluster_log_file       => $cluster_log_file,
             graph_unionfind_object => $uf });

           A description of the hash values taken:

           graph_vertices - a hash of the vertices and their counts              HashRef
           sequence_hash - the mapping of FASTA/Q IDs and their sequence         HashRef
                           returned from store_seq() from 
                           Transposome::SeqStore
           read_pairs - a data structure containing the read IDs in each         HashRef
                        cluster
           cluster_log_file - the filename of the report for logging progress    Scalar 
                              and results
           graph_unionfind_object - a Graph::UnionFind object, containg data     Object
                                    for finding union in the graph   

=cut

sub merge_clusters {
    my $self = shift; 
    my ($cluster_data) = @_;
    my $vertex = $cluster_data->{graph_vertices};
    my $seqs   = $cluster_data->{sequence_hash};
    my $uf     = $cluster_data->{graph_unionfind_object};
    my $read_pairs   = $cluster_data->{read_pairs};
    my $cls_log_file = $cluster_data->{cluster_log_file};
    my $dbm_file     = $cluster_data->{dbm_file};

    my $infile = $self->file->relative;
    my ($iname, $ipath, $isuffix) = fileparse($infile, qr/\.[^.]*/);
    my $out_dir = $self->dir->relative;
    my $str = POSIX::strftime("%m_%d_%Y_%H_%M_%S", localtime);

    my $cls_dir_base    = $iname;
    my $cls_with_merges = $cls_dir_base;
    my $cls_dir         = $cls_dir_base."_cls_fasta_files_$str";
    $cls_with_merges    .= "_merged_$str.cls";
    my $cls_dir_path    = $ipath.$cls_dir;
    make_path($cls_dir_path, {verbose => 0, mode => 0711,});
    my $cls_with_merges_path = File::Spec->catfile($out_dir, $cls_with_merges);
    open my $clsnew, '>', $cls_with_merges_path 
	or die "\n[ERROR]: Could not open file: $cls_with_merges_path\n";

    my ($rpname, $rppath, $rpsuffix) = fileparse($cls_log_file, qr/\.[^.]*/);
    my $rp_path = File::Spec->catfile($out_dir, $rpname.$rpsuffix);

    open my $rep, '>>', $rp_path or die "\n[ERROR]: Could not open file: $rp_path\n";

    my $cls_tot = 0;

    # log results
    my $st = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("Transposome::Cluster::merge_clusters started at:         $st.");
    
    my %cluster;
    for my $v (keys %$vertex) {
	my $b = $$uf->find($v);
	die "$0: no block for $v" unless defined $b;
	push @{$cluster{$b}}, $v;
    }

    # generate groups based on cluster union
    say $rep "# Cluster groupings (group_index\tclusters)";
    my $group_index = 0;
    for my $group (values %cluster) {
	my $groupseqnum; my @grpcp;
	for my $clsstrcp (@$group) { 
	    my ($id, $seqnum) = split /\_/, $clsstrcp, 2; 
	    $groupseqnum += $seqnum; 
	    push @grpcp, $id; 
	}
	$cls_tot += $groupseqnum;
	say $rep join "\t", $group_index, join ",", @grpcp;
	say $clsnew ">G$group_index $groupseqnum";
	my $group_file = "G$group_index"."_$groupseqnum".".fas";
	my $group_file_path = File::Spec->catfile($cls_dir_path, $group_file);
	open my $groupout, '>', $group_file_path or die "\n[ERROR]: Could not open file: $group_file_path\n";
    
	for my $clus (@$group) {
	    if (exists $read_pairs->{$clus}) {
		my @ids = $self->mk_vec($read_pairs->{$clus});
		print $clsnew join q{ }, @ids;
		for my $read (@ids) {
		    if (exists $seqs->{$read}) {
			say $groupout join "\n", ">".$read, $seqs->{$read};
			delete $seqs->{$read};
		    }
		    else {
			$log->warn("$read not found. This indicates something went wrong processing the input. ".
				   "Please check your input.")
		    }
		}
	    }
	    print $clsnew q{ };
	    delete $read_pairs->{$clus}
	}
	print $clsnew "\n";
	close $groupout;
	$group_index++;
    }

    # write out those clusters that weren't merged
    say $rep "# Non-grouped clusters";
    while (my ($non_paired_cls, $non_paired_clsids) = each %$read_pairs) {
	my ($non_paired_clsid, $non_paired_clsseqnum) = split /\_/, $non_paired_cls, 2;
	my @ids = $self->mk_vec($non_paired_clsids);
	$cls_tot += $non_paired_clsseqnum;
	say $rep $non_paired_clsid;
	say $clsnew join "\n", ">$non_paired_clsid $non_paired_clsseqnum", join " ", @ids;

	if (@ids >= $self->cluster_size) {
	    my $non_paired_clsfile .= $non_paired_cls.".fas";
	    my $cls_file_path = File::Spec->catfile($cls_dir_path, $non_paired_clsfile);
	    open my $clsout, '>', $cls_file_path or die "\n[ERROR]: Could not open file: $cls_file_path\n";

	    for my $non_paired_read (@ids) {
		if (exists $seqs->{$non_paired_read}) {
		    say $clsout join "\n", ">".$non_paired_read, $seqs->{$non_paired_read};
		    delete $seqs->{$non_paired_read};
		}
		else {
		    $log->warn("$non_paired_read not found. ".
			       "This indicates something went wrong processing the input. ".
			       "Please check your input.");
		}
	    }
	    close $clsout;
	}
    }
    close $rep;
    close $clsnew;

    untie %$read_pairs unless $self->in_memory;
    unlink $dbm_file if -e $dbm_file;

    # write out singletons for rarefaction
    my $singletons_num = scalar keys %$seqs;
    my $singletons_file = "singletons_$singletons_num.fas";
    my $singletons_file_path = File::Spec->catfile($cls_dir_path, $singletons_file);
    open my $singlesout, '>', $singletons_file_path 
	or die "\n[ERROR]: Could not open file: $singletons_file_path\n";

    while (my ($seqid, $seq) = each %$seqs) {
	say $singlesout join "\n", ">".$seqid, $seq;
    }
    close $singlesout;

    # log results
    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("Transposome::Cluster::merge_clusters completed at:       $ft.");
    $log->info("Results - Total number of clustered reads:  $cls_tot.");

    return ({ cluster_directory    => $cls_dir_path,
              singletons_file      => $singletons_file_path,
              merged_clusters_file => $cls_with_merges_path,
	      total_cluster_num    => $cls_tot });

}

=head2 _find_community_exes

 Title : _find_community_exes
 
 Usage   : my ($lconvert, $lcommunity, $lhierarchy) = $self->_find_community_exes($realbin);
           
 Function: Locates the clustering executables shipped with Transposome.
           Depending on the Perl installation, these may be installed in
           different locations. For example, with local::lib installed,
           the executables will not be in the default location.
           
                                                                                 Return_type
 Returns : The path to the default location with standard                        Scalar
           Perl installation.

                                                                                 Arg_type
 Args    : Returns : In order, 1) path to the convert program                    Scalar
                               2) path to the community program                  Scalar
                               3) path to the hierarchy program                  Scalar

=cut 

sub _find_community_exes {
    my $self = shift;
    my ($realbin) = @_;
    my $lconvert   = File::Spec->catfile($realbin, 'louvain_convert');
    my $lcommunity = File::Spec->catfile($realbin, 'louvain_community');
    my $lhierarchy = File::Spec->catfile($realbin, 'louvain_hierarchy');
    
    if (-e $lconvert   && -x $lconvert &&
	-e $lcommunity && -x $lcommunity &&
	-e $lhierarchy && -x $lhierarchy) {
	return ($lconvert, $lcommunity, $lhierarchy);
    }
    elsif (! -e $lconvert) {
	my @path = split /:|;/, $ENV{PATH};

	for my $p (@path) {
	    my $lconvert   = File::Spec->catfile($p, 'louvain_convert');
	    my $lcommunity = File::Spec->catfile($p, 'louvain_community');
	    my $lhierarchy = File::Spec->catfile($p, 'louvain_hierarchy');

	    if (-e $lconvert   && -x $lconvert &&
		-e $lcommunity && -x $lcommunity &&
		-e $lhierarchy && -x $lhierarchy) {
		return ($lconvert, $lcommunity, $lhierarchy);
	    }
	}
    }
    else {
	$log->error("Unable to find clusting executables. This is a bug, please report it. Exiting.");
	exit(1);
    }
}

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests through the project site at 
L<https://github.com/sestaton/Transposome/issues>. I will be notified,
and there will be a record of the issue. Alternatively, I can also be 
reached at the email address listed above to resolve any questions.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::Cluster


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2015 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
