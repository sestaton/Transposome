package Transposome::Cluster;

use 5.012;
use Moose;
use namespace::autoclean;
use Graph::UnionFind;
use File::Spec;
use File::Basename;
use Try::Tiny;
use IPC::System::Simple qw(system capture EXIT_ANY);
use autodie qw(open);
use File::Path qw(make_path);
use POSIX qw(strftime);

with 'File', 'Util';

=head1 NAME

Transposome::Cluster - 

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use Transposome::Cluster;

    my $clus_obj = Transposome::Cluster->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 ATTRIBUTES


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

=head1 SUBROUTINES/METHODS

=head2 louvain_method

 Title   : louvain_method
 Usage   : $self->louvain_method();

 Function: 
 Returns : 
 Args    : 

=cut

sub louvain_method {
    #my ($self, $int_file, $outdir) = @_;
    my ($self) = @_;
    #chdir($outdir) || die "\nERROR: Could not change $outdir: $!\n";
    my $int_file = $self->file->relative;
    my $out_dir = $self->dir->relative;
    my ($iname, $ipath, $isuffix) = fileparse($int_file, qr/\.[^.]*/);

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

    #TODO use File::Spec to get path to bin
    #my @convert_cmd = "../bin/convert -i $int_file -o $cls_bin_path -w $cls_tree_weights_path";
    #say @convert_cmd;
    try {
	system([0..5], "../bin/convert -i $int_file -o $cls_bin_path -w $cls_tree_weights_path");
    }
    catch {
	warn "\nERROR: Louvain 'convert' failed. Caught error: $_" and exit;
    };

    try {
	system([0..5],"../bin/community $cls_bin_path -l -1 -w $cls_tree_weights_path -v >$cls_tree_path 2>$cls_tree_log_path");
    }
    catch {
	warn "\nERROR: Louvain 'community' failed. Caught error: $_" and exit;
    };

    try {
	$levels = capture(EXIT_ANY, "grep -c level $cls_tree_log_path");
	chomp $levels;
    }
    catch {
	warn "\nERROR: grep failed. Caught error: $_" and exit;
    };

    my @comm;
    for (my $i = 0; $i <= $levels-1; $i++) {
        my $cls_graph_comm = $cls_tree.".graph_node2comm_level_".$i; #
	my $cls_graph_comm_path = File::Spec->catfile($self->dir, $cls_graph_comm);
	
	try {
	    system([0..5],"../bin/hierarchy $cls_tree_path -l $i > $cls_graph_comm_path");
	}
	catch {
	    warn "\nERROR: Louvain 'hierarchy' failed. Caught error: $_" and exit;
	};

	push @comm, $cls_graph_comm;
    }
    return \@comm;
}

=head2 find_pairs

 Title   : find_pairs
 Usage   : 
           
 Function: 
 Returns : 
 Args    : 

=cut

sub find_pairs {
    my ($self, $cls_file, $report) = @_;
    
    my $out_dir = $self->dir->relative;
    my ($rpname, $rppath, $rpsuffix) = fileparse($report, qr/\.[^.]*/);
    my $rp_path = File::Spec->rel2abs($rppath.$rpname.$rpsuffix);
    my ($clname, $clpath, $clsuffix) = fileparse($cls_file, qr/\.[^.]*/);
    my $cls_file_path = File::Spec->rel2abs($clpath.$out_dir."/".$clname.$clsuffix);
    open my $rep, '>', $rp_path;

    #$merge_threshold //= 500;

    my $uf = Graph::UnionFind->new;

    say $rep "=====> Cluster connections above threshold";

    my %vertex;
    my %read_pairs;
    my %mapped_pairs;

    {
        local $/ = '>';
        
        open my $in, '<', $cls_file_path;   
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
 Usage   : 
 Function: 
 Returns : 
 Args    : 
           

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
    die "\nERROR: Community clustering failed. Exiting.\n" unless defined $graph; ## can probably remove this statement
    my $graph_path = File::Spec->catfile($out_dir, $graph);
    my %clus;
    my %index;

    open my $idx, '<', $idx_file;
    while (my $idpair = <$idx>) {
        chomp $idpair;
        my ($readid, $readindex) = split /\s+/, $idpair;
        $index{$readindex} = $readid;
    }
    close $idx;

    open my $mem,'>', $membership_file_path;
    open my $in, '<', $graph_path;
    open my $cls_out, '>', $cluster_file_path;

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

 Title   : 
 Usage   : 
           
 Function: 
 Returns : 
 Args    : 


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
    #say join "\n", "iname: $iname", "cls_with_merges: $cls_with_merges", "cls_dir: $cls_dir", "cls_dir_path: $cls_dir_path";
    #exit;
    make_path($cls_dir_path, {verbose => 0, mode => 0711,}); # allows for recursively making paths                                                                
    my $cls_with_merges_path = File::Spec->catfile($out_dir, $cls_with_merges);
    open my $clsnew, '>', $cls_with_merges_path;

    my ($rpname, $rppath, $rpsuffix) = fileparse($report, qr/\.[^.]*/);
    my $rp_path = File::Spec->rel2abs($rppath.$rpname.$rpsuffix);
    open my $rep, '>>', $rp_path;

    #$cluster_size //= 500;
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
	open my $groupout, '>', $group_file_path;
    
	for my $clus (@$group) {
	    if (exists $read_pairs->{$clus}) {
		print $clsnew join " ",@{$read_pairs->{$clus}};
		for my $read (@{$read_pairs->{$clus}}) {
		    if (exists $seqs->{$read}) {
			say $groupout join "\n", ">".$read, $seqs->{$read};
		    }
		    else {
			say "WARNING: $read not found. This is possibly a bug. Please report it.";
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
	    open my $clsout, '>', $cls_file_path;

	    for my $non_paired_read (@{$read_pairs->{$non_paired_cls}}) {
		if (exists $seqs->{$non_paired_read}) {
		    say $clsout join "\n", ">".$non_paired_read, $seqs->{$non_paired_read};
		}
		else {
		    say "WARNING: $non_paired_read not found. This is possibly a bug. Please report it.";
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

Please report any bugs or feature requests to C<bug-transposome at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Transposome>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::Cluster


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Transposome>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Transposome>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Transposome>

=item * Search CPAN

L<http://search.cpan.org/dist/Transposome/>

=back

=head1 ACKNOWLEDGEMENTS


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
