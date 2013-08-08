package Transposome::Cluster;

use 5.012;
use Moose;
use namespace::autoclean;
use Graph::UnionFind;
use File::Spec;
use File::Basename;
use Try::Tiny;
use IPC::System::Simple qw(system capture EXIT_ANY);
use File::Path qw(make_path);
use Path::Class::File;
use POSIX qw(strftime);
use Config;

with 'Transposome::Role::File', 
     'Transposome::Role::Util';

=head1 NAME

Transposome::Cluster - Clustering and cluster analysis routines in Transposome.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

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

has 'blastn_exec' => (
    is        => 'rw',
    isa       => 'Str',
    reader    => 'get_blastn_exec',
    writer    => 'set_blastn_exec',
    predicate => 'has_blastn_exec',
    );

has 'makeblastdb_exec' => (
    is        => 'rw',
    isa       => 'Str',
    reader    => 'get_makeblastdb_exec',
    writer    => 'set_makeblastdb_exec',
    predicate => 'has_makeblastdb_exec',
    );

has 'formatdb_exec' => (
    is        => 'rw',
    isa       => 'Str',
    reader    => 'get_formatdb_exec',
    writer    => 'set_formatdb_exec',
    predicate => 'has_formatdb_exec',
    );

has 'mgblast_exec' => (
    is        => 'rw',
    isa       => 'Str',
    reader    => 'get_mgblast_exec',
    writer    => 'set_mgblast_exec',
    predicate => 'has_mgblast_exec',
    );

sub BUILD {
    my ($self) = @_;

    my @path = split /:|;/, $ENV{PATH};

    for my $p (@path) {
	my $mg = $p."/"."mgblast";
	my $bl = $p."/"."blastn";
	my $fd = $p."/"."formatdb";
	my $mb = $p."/"."makeblastdb";

	if (-e $mg && -x $mg) {
	    $self->set_mgblast_exec($mg);
	}
	elsif (-e $bl && -x $bl && $bl =~ /ncbi/ && -e $mb) {
	    $self->set_blastn_exec($bl);
	    $self->set_makeblastdb_exec($mb);
	}
	elsif (-e $fd && -x $fd) {
	    $self->set_formatdb_exec($fd);
	}
    }
    try {
	die unless $self->has_mgblast_exec;
    }
    catch {
	warn "\n[ERROR]: Unable to find mgblast. Check your PATH to see that it is installed. Exiting.\n"; exit(1);
    };

    try {
	die unless $self->has_formatdb_exec;
    }
    catch {
	warn "\n[ERROR]: Unable to find formatdb. Check your PATH to see that it is installed. Exiting.\n"; exit(1);
    };

    try {
	die unless $self->has_makeblastdb_exec;
    }
    catch {
	warn "\n[ERROR]: Unable to find makeblastdb. Check you PATH to see that it is installed. Exiting.\n"; exit(1);
    };

    try {
	die unless $self->has_blastn_exec;
    }
    catch {
	warn "\n[ERROR]: Unable to find blastn. Check you PATH to see that it is installed. Exiting.\n"; exit(1);
    };
}

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
    my ($self) = @_;
    my $int_file = $self->file->relative;
    my $out_dir = $self->dir->relative;
    my ($iname, $ipath, $isuffix) = fileparse($int_file, qr/\.[^.]*/);
    my $realbin = $self->bin_dir->resolve;
    my $cls_bin = $iname.".bin";                    # Community "bin" format
    my $cls_tree = $iname.".tree";                  # hierarchical tree of clustering results
    my $cls_tree_weights = $cls_tree.".weights";    # bit score, the weights applied to clustering
    my $cls_tree_log = $cls_tree.".log";            # the summary of clustering results at each level of refinement
    my $hierarchy_err = $cls_tree.".hierarchy.log"; # hierarchical tree building log (not actually used)
    my $levels;                                     # the number of hierarchical levels

    my $cls_bin_path = File::Spec->catfile($out_dir, $cls_bin);
    my $cls_tree_path = File::Spec->catfile($out_dir, $cls_tree);
    my $cls_tree_weights_path = File::Spec->catfile($out_dir, $cls_tree_weights);
    my $cls_tree_log_path = File::Spec->catfile($out_dir, $cls_tree_log);
    my $hierarchy_err_path = File::Spec->catfile($out_dir, $hierarchy_err);

    try {
	system([0..5], "$realbin/convert -i $int_file -o $cls_bin_path -w $cls_tree_weights_path");
    }
    catch {
	warn "\n[ERROR]: Louvain 'convert' failed. Caught error: $_" and exit(1);
    };

    try {
	system([0..5],"$realbin/community $cls_bin_path -l -1 -w $cls_tree_weights_path -v >$cls_tree_path 2>$cls_tree_log_path");
    }
    catch {
	warn "\n[ERROR]: Louvain 'community' failed. Caught error: $_" and exit(1);
    };

    try {
	$levels = capture(EXIT_ANY, "grep -c level $cls_tree_log_path");
	chomp $levels;
    }
    catch {
	warn "\n[ERROR]: grep failed. Caught error: $_" and exit(1);
    };

    my @comm;
    for (my $i = 0; $i <= $levels-1; $i++) {
        my $cls_graph_comm = $cls_tree.".graph_node2comm_level_".$i; #
	my $cls_graph_comm_path = File::Spec->catfile($self->dir, $cls_graph_comm);
	
	try {
	    system([0..5],"$realbin/hierarchy $cls_tree_path -l $i > $cls_graph_comm_path");
	}
	catch {
	    warn "\n[ERROR]: Louvain 'hierarchy' failed. Caught error: $_" and exit(1);
	};

	push @comm, $cls_graph_comm;
    }
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
    my ($self, $cls_file, $report) = @_;
    
    my $out_dir = $self->dir->relative;
    my ($rpname, $rppath, $rpsuffix) = fileparse($report, qr/\.[^.]*/);
    my $rp_path = File::Spec->rel2abs($rppath.$rpname.$rpsuffix);
    my ($clname, $clpath, $clsuffix) = fileparse($cls_file, qr/\.[^.]*/);
    my $cls_file_path = File::Spec->rel2abs($clpath.$out_dir."/".$clname.$clsuffix);
    open my $rep, '>', $rp_path or die "\n[ERROR]: Could not open file: $rp_path\n";

    my $uf = Graph::UnionFind->new;

    say $rep "=====> Cluster connections above threshold";

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
            #if (scalar(@ids) >= $cluster_size) {       # limit cluster size in .cls file here, if desired
            push @{$read_pairs{$clsid}}, $_ for @ids;
            #}
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
        if (scalar(@{$mapped_pairs{$allpairs}}) < 2) {     # if no pair is found in another cluster, 
            delete $mapped_pairs{$allpairs};               # remove this pair
        }
        else {
            push @sep_reads, values %$_ for @{$mapped_pairs{$allpairs}};
            ($cls_i, $cls_j) = sort @sep_reads;
            if ($cls_i =~ /$cls_j/) {                      # remove reads that have pairs in the same cluster       
                delete $mapped_pairs{$allpairs};           # which is uninformative for merging clusters
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

sub make_clusters {
    my ($self, $graph_comm, $idx_file) = @_;

    my $int_file = $self->file->relative;
    my $out_dir = $self->dir->relative;
    my ($iname, $ipath, $isuffix) = fileparse($int_file, qr/\.[^.]*/);
    my $cluster_file = $iname.".cls";
    my $membership_file = $cluster_file.".membership.txt";
    my $cluster_file_path = File::Spec->catfile($out_dir, $cluster_file);
    my $membership_file_path = File::Spec->catfile($out_dir, $membership_file);

    my @graph_comm_sort = reverse sort { ($a =~ /(\d)$/) <=> ($b =~ /(\d)$/) } @$graph_comm;
    my $graph = shift @graph_comm_sort;
    die "\n[ERROR]: Community clustering failed. Exiting.\n" unless defined $graph; ## can probably remove this statement
    my $graph_path = File::Spec->catfile($out_dir, $graph);
    my %clus;
    my %index;

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
        my $clus_size = scalar @{$clus{$cls}};
        say $cls_out ">CL$cls_ct $clus_size";
        my @clus_members;
        for my $cls_member (@{$clus{$cls}}) {
            say $mem "$cls_member $cls_ct";
            if (exists $index{$cls_member}) {
                push @clus_members, $index{$cls_member};
            }
        }
        say $cls_out join " ", @clus_members;
        $cls_ct++;
    }
    close $cls_out;
    close $mem;

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
                     3) the total number of reads clustered                      Scalar

           The cluster file is in a format similar to Fasta, where the           
           identifier specifies the cluster ID followed by the size. The                                                                                                         second line of each record contains each read ID separated by                                                                                              
           a space. The 'G' indicates a group created by joining clusters.
           E.g.,                                                                                                                                             
                                                                                                                                                                      
               >G1 3                                                                                                                                                                 read1 read2 read3 
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

sub merge_clusters {
    my ($self, $vertex, $seqs, $read_pairs, $report, $uf) = @_;

    my $infile = $self->file->relative;
    my $out_dir = $self->dir->relative;
    my $str = POSIX::strftime("%m_%d_%Y_%H_%M_%S", localtime);
    my ($iname, $ipath, $isuffix) = fileparse($infile, qr/\.[^.]*/);
    my $cls_dir_base = $iname;
    my $cls_with_merges = $cls_dir_base;
    my $cls_dir = $cls_dir_base."_cls_fasta_files_$str";
    $cls_with_merges .= "_merged_$str.cls";
    my $cls_dir_path = $ipath.$cls_dir;
    make_path($cls_dir_path, {verbose => 0, mode => 0711,}); # allows for recursively making paths                                                                
    my $cls_with_merges_path = File::Spec->catfile($out_dir, $cls_with_merges);
    open my $clsnew, '>', $cls_with_merges_path or die "\n[ERROR]: Could not open file: $cls_with_merges_path\n";

    my ($rpname, $rppath, $rpsuffix) = fileparse($report, qr/\.[^.]*/);
    my $rp_path = File::Spec->rel2abs($rppath.$rpname.$rpsuffix);
    open my $rep, '>>', $rp_path or die "\n[ERROR]: Could not open file: $rp_path\n";

    my $cls_tot = 0;

    my %cluster;
    for my $v (keys %$vertex) {
	my $b = $$uf->find($v);
	die "$0: no block for $v" unless defined $b;
	push @{$cluster{$b}}, $v;
    }

    # generate groups based on cluster union
    say $rep "=====> Cluster groupings (group_index\tclusters)";
    my $group_index = 0;
    for my $group (values %cluster) {
	my $groupseqnum; my @grpcp;
	for (@$group) { my $clsstrcp = $_; my ($id, $seqnum) = split /\_/, $clsstrcp, 2; $groupseqnum += $seqnum; push @grpcp, $id; }
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
		    }
		    else {
			warn "[WARNING]: $read not found. This indicates something went wrong processing the input. Please check your input data.";
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
    say $rep "=====> Non-grouped clusters";
    for my $non_paired_cls (keys %$read_pairs) {
	my ($non_paired_clsid, $non_paired_clsseqnum) = split /\_/, $non_paired_cls, 2;
	$cls_tot += $non_paired_clsseqnum;
	say $rep $non_paired_clsid;
	say $clsnew join "\n", ">$non_paired_clsid $non_paired_clsseqnum", join " ", @{$read_pairs->{$non_paired_cls}};

	if (scalar(@{$read_pairs->{$non_paired_cls}}) >= $self->cluster_size) {
	    my $non_paired_clsfile .= $non_paired_cls.".fas";
	    my $cls_file_path = File::Spec->catfile($cls_dir_path, $non_paired_clsfile);
	    open my $clsout, '>', $cls_file_path or die "\n[ERROR]: Could not open file: $cls_file_path\n";

	    for my $non_paired_read (@{$read_pairs->{$non_paired_cls}}) {
		if (exists $seqs->{$non_paired_read}) {
		    say $clsout join "\n", ">".$non_paired_read, $seqs->{$non_paired_read};
		}
		else {
		    warn "[WARNING]: $non_paired_read not found. This indicates something went wrong processing the input. Please check your input data.";
		}
	    }
	    close $clsout;
	}
    }
    close $rep;
    close $clsnew;

    return ($cls_dir_path, $cls_with_merges_path, $cls_tot);
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

__PACKAGE__->meta->make_immutable;
