package Transposome::Cluster;

use 5.010;
use Moose;
use MooseX::Types::Moose qw(HashRef);
use IPC::System::Simple  qw(system capture EXIT_ANY);
use File::Path           qw(make_path);
use POSIX                qw(strftime);
use Method::Signatures;
use Graph::UnionFind;
use File::Spec;
use File::Basename;
use Try::Tiny;
use Path::Class::File;
use Config;
use namespace::autoclean;

with 'MooseX::Log::Log4perl',
     'Transposome::Role::File', 
     'Transposome::Role::Util';

=head1 NAME

Transposome::Cluster - Clustering and cluster analysis routines in Transposome.

=head1 VERSION

Version 0.08.3

=cut

our $VERSION = '0.08.3';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    use Transposome::Cluster;

    my $clus_obj = Transposome::Cluster->new();
    ...

=cut

has 'merge_threshold' => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
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

method louvain_method {
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
    $self->log->info("Transposome::Cluster::louvain_method started at:         $st.")
        if Log::Log4perl::initialized();

    try {
	system([0..5], "$lconvert -i $int_file -o $cls_bin_path -w $cls_tree_weights_path");
    }
    catch {
	$self->log->error("Louvain 'convert' failed. Caught error: $_.")
	    if Log::Log4perl::initialized();
	exit(1);
    };

    try {
	system([0..5],"$lcommunity $cls_bin_path -l -1 -w $cls_tree_weights_path -v >$cls_tree_path 2>$cls_tree_log_path");
    }
    catch {
	$self->log->error("Louvain 'community' failed. Caught error: $_.")
	    if Log::Log4perl::initialized();
	exit(1);
    };

    unlink $cls_bin_path;
    unlink $cls_tree_weights_path;

    try {
	$levels = capture(EXIT_ANY, "grep -c level $cls_tree_log_path");
	chomp $levels;
    }
    catch {
	$self->log->error("grep failed. Caught error: $_.")
	    if Log::Log4perl::initialized();
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
	    $self->log->error("Louvain 'hierarchy' failed. Caught error: $_.")
		if Log::Log4perl::initialized();
	    exit(1);
	};

	push @comm, $cls_graph_comm;
    }
    unlink $cls_tree_path;

    # log results
    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("Transposome::Cluster::louvain_method completed at:       $ft.")
        if Log::Log4perl::initialized();

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

method find_pairs ($cls_file, $cls_log_file) {    
    my $out_dir                      = $self->dir->relative;
    my $cls_log_path                 = File::Spec->catfile($out_dir, $cls_log_file);
    my ($clname, $clpath, $clsuffix) = fileparse($cls_file, qr/\.[^.]*/);
    my $cls_file_path                = File::Spec->catfile($clpath.$out_dir, $clname.$clsuffix);
    
    my $uf = Graph::UnionFind->new;

    # log results
    open my $rep, '>', $cls_log_path or die "\n[ERROR]: Could not open file: $cls_log_path\n";
    say $rep "# Cluster connections above threshold";
    my $st = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("Transposome::Cluster::find_pairs started at:             $st.")
        if Log::Log4perl::initialized();

    my %vertex;
    my %read_pairs;
    my %mapped_pairs;

    {
        local $/ = '>';
        
        open my $in, '<', $cls_file_path or die "\n[ERROR]: Could not open file: $cls_file_path\n";   
        while (my $line = <$in>) {
            $line =~ s/>//g;
            next if !length($line);
            my ($clsid, $seqids) = split /\n/, $line;
            $clsid =~ s/\s/\_/;
            my @ids = split /\s+/, $seqids;       
            # limit cluster size in .cls file here, if desired
            push @{$read_pairs{$clsid}}, $_ for @ids;
        }
        close $in;
    }

    while (my ($cls, $reads) = each %read_pairs) {
        for my $read (@$reads) {
            my $readbase = $read;
            $readbase =~ s/\/\d$//;
            if (exists $mapped_pairs{$readbase}) {
                push @{$mapped_pairs{$readbase}}, {$read => $cls};
            }
            else {
                $mapped_pairs{$readbase} = [{$read => $cls}];
            }
        }
    }

    my %cls_conn_ct;
    my ($cls_i, $cls_j);
    my @sep_reads;

    for my $allpairs (keys %mapped_pairs) {
        if (@{$mapped_pairs{$allpairs}} < 2) {     # if no pair is found in another cluster, 
            delete $mapped_pairs{$allpairs};       # remove this pair
        }
        else {
            push @sep_reads, values %$_ for @{$mapped_pairs{$allpairs}};
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

    for my $p (reverse sort { $cls_conn_ct{$a} <=> $cls_conn_ct{$b} } keys %cls_conn_ct) {
	my ($i, $j) = $self->mk_vec($p);
        my $i_noct = $i; $i_noct =~ s/\_.*//;
        my $j_noct = $j; $j_noct =~ s/\_.*//;
        if ($cls_conn_ct{$p} >= $self->merge_threshold) {   
            say $rep join "\t", $i_noct, $j_noct, $cls_conn_ct{$p};
            ++$vertex{$_} for $i, $j;
            $uf->union($i, $j);
        }
    }
    close $rep;
    unlink $cls_file_path;

    # log results
    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("Transposome::Cluster::find_pairs completed at:           $ft.")
        if Log::Log4perl::initialized();

    return(\%read_pairs, \%vertex, \$uf);
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

method make_clusters ($graph_comm, $idx_file) {
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
    if (Log::Log4perl::initialized()){
	$self->log->logdie("\n[ERROR]: Community clustering failed. Exiting.\n") unless defined $graph;
    }
    my $graph_path = File::Spec->catfile($out_dir, $graph);
    my %clus;
    my %index;

    # log results
    my $st = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("Transposome::Cluster::make_clusters started at:          $st.")
        if Log::Log4perl::initialized();

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
        if (exists $clus{$j}) {
            push @{$clus{$j}}, $i;
        }
        else {
            $clus{$j} = [$i];
        }
    }
    close $in;

    my $cls_ct = 1;
    for my $cls (reverse sort { @{$clus{$a}} <=> @{$clus{$b}} } keys %clus) {
        my $clus_size = @{$clus{$cls}};
        say $cls_out ">CL$cls_ct $clus_size";
        my @clus_members;
        for my $cls_member (@{$clus{$cls}}) {
            say $mem "$cls_member $cls_ct";
            if (exists $index{$cls_member}) {
                push @clus_members, $index{$cls_member};
            }
        }
        say $cls_out join q{ }, @clus_members;
        $cls_ct++;
    }
    close $cls_out;
    close $mem;

    for (@$graph_comm) {
	my $graph_file = File::Spec->catfile($out_dir, $_);
	unlink $graph_file;
    }

    # log results
    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("Transposome::Cluster::make_clusters completed at:        $ft.")
        if Log::Log4perl::initialized();

    return $cluster_file;
}

=head2 merge_clusters

 Title   : merge_clusters
 Usage   : 
           
 Function: Join clusters based on threshold of split paired reads.  

                                                                                 Return_type
 Returns : In order, 1) path to the results directory                            Scalar
                     2) filename (path to) the cluster file with                 Scalar
                        unions above threshold (see below)
                     3) filename (path to) the singletons file                   Scalar
                     4) the total number of reads clustered                      Scalar

           The cluster file is in a format similar to Fasta, where the           
           identifier specifies the cluster ID followed by the size. The
           second line of each record contains each read ID separated by 
           a space. The 'G' indicates a group created by joining clusters.
           
           E.g., 
        
               >G1 3
               read1 read2 read3 
                                                                                 Arg_type
 Args    : In order, 1) a hash of the vertices and their counts                  HashRef
                     2) the mapping of Fasta/q IDs and their sequence            HashRef
                        returned from store_seq() from Transposome::SeqStore
                     3) a data structure containing the read IDs in each         HashRef
                        cluster
                     4) the filename of the report for logging progress          Scalar 
                        and results
                     5) a Graph::UnionFind object, containg data for finding
                        union in the graph   

=cut

method merge_clusters (HashRef $vertex, HashRef $seqs, HashRef $read_pairs, $cls_log_file, $uf) {
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
    open my $clsnew, '>', $cls_with_merges_path or die "\n[ERROR]: Could not open file: $cls_with_merges_path\n";

    my ($rpname, $rppath, $rpsuffix) = fileparse($cls_log_file, qr/\.[^.]*/);
    my $rp_path = File::Spec->catfile($out_dir, $rpname.$rpsuffix);

    open my $rep, '>>', $rp_path or die "\n[ERROR]: Could not open file: $rp_path\n";

    my $cls_tot = 0;

    # log results
    my $st = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("Transposome::Cluster::merge_clusters started at:         $st.")
        if Log::Log4perl::initialized();
    
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
		print $clsnew join " ",@{$read_pairs->{$clus}};
		for my $read (@{$read_pairs->{$clus}}) {
		    if (exists $seqs->{$read}) {
			say $groupout join "\n", ">".$read, $seqs->{$read};
			delete $seqs->{$read};
		    }
		    else {
			$self->log->warn("$read not found. This indicates something went wrong processing the input. ".
					 "Please check your input.")
			    if Log::Log4perl::initialized();
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
    for my $non_paired_cls (keys %$read_pairs) {
	my ($non_paired_clsid, $non_paired_clsseqnum) = split /\_/, $non_paired_cls, 2;
	$cls_tot += $non_paired_clsseqnum;
	say $rep $non_paired_clsid;
	say $clsnew join "\n", ">$non_paired_clsid $non_paired_clsseqnum", join " ", @{$read_pairs->{$non_paired_cls}};

	if (@{$read_pairs->{$non_paired_cls}} >= $self->cluster_size) {
	    my $non_paired_clsfile .= $non_paired_cls.".fas";
	    my $cls_file_path = File::Spec->catfile($cls_dir_path, $non_paired_clsfile);
	    open my $clsout, '>', $cls_file_path or die "\n[ERROR]: Could not open file: $cls_file_path\n";

	    for my $non_paired_read (@{$read_pairs->{$non_paired_cls}}) {
		if (exists $seqs->{$non_paired_read}) {
		    say $clsout join "\n", ">".$non_paired_read, $seqs->{$non_paired_read};
		    delete $seqs->{$non_paired_read};
		}
		else {
		    $self->log->warn("$non_paired_read not found. ".
				     "This indicates something went wrong processing the input. ".
				     "Please check your input.")
			if Log::Log4perl::initialized();
		}
	    }
	    close $clsout;
	}
    }
    close $rep;
    close $clsnew;

    # write out singletons for rarefaction
    my $singletons_num = scalar keys %$seqs;
    my $singletons_file = "singletons_$singletons_num.fas";
    my $singletons_file_path = File::Spec->catfile($cls_dir_path, $singletons_file);
    open my $singlesout, '>', $singletons_file_path or die "\n[ERROR]: Could not open file: $singletons_file_path\n";

    for my $seqid (keys %$seqs) {
	say $singlesout join "\n", ">".$seqid, $seqs->{$seqid};
    }
    close $singlesout;

    # log results
    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("Transposome::Cluster::merge_clusters completed at:       $ft.")
        if Log::Log4perl::initialized();

    return ($cls_dir_path, $cls_with_merges_path, $singletons_file_path, $cls_tot);
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

method _find_community_exes (Path::Class::Dir $realbin) {
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
	$self->log->error("Unable to find clusting executables. This is a bug, please report it. Exiting.")
	    if Log::Log4perl::initialized();
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

Copyright (C) 2013-2014 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
