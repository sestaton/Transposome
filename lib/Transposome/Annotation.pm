package Transposome::Annotation;

use 5.012;
use Moose;
use namespace::autoclean;
use List::Util qw(sum max);
use IPC::System::Simple qw(system capture EXIT_ANY);
use Path::Class::File;
use File::Path qw(make_path);
use File::Basename;
use Try::Tiny;
use Storable qw(thaw);
use POSIX qw(strftime);

with 'MooseX::Log::Log4perl',
     'Transposome::Annotation::Typemap', 
     'Transposome::Role::File', 
     'Transposome::Role::Util';

=head1 NAME

Transposome::Annotation - Annotate clusters for repeat types.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use Transposome::Annotation;

    my $cluster_file = '/path/to/cluster_file.cls';
    my $seqct = 'total_seqs_in_analysis';  # Integer
    my $cls_tot = 'total_reads_clustered'; # Integer

    my $annotation = Transposome::Annotation->new( database  => 'repeat_db.fas',
                                                   dir       => 'outdir',
                                                   file      => 'report.txt' );

    my ($anno_rp_path, $anno_sum_rep_path, $total_readct,                                                                           
    $rep_frac, $blasts, $superfams) = $annotation->annotate_clusters($cluster_file, $seqct, $cls_tot);
    
 
    $annotation->clusters_annotation_to_summary($anno_rp_path, $anno_sum_rep_path, $total_readct,
                                                $seqct, $rep_frac, $blasts, $superfams, $report);


=cut

has 'database' => (
      is       => 'ro',
      isa      => 'Path::Class::File',
      required => 1,
      coerce   => 1,
    );

has 'evalue' => (
    is       => 'ro',
    isa      => 'Num',
    default  => 10,
    );

has 'report' => (
      is       => 'ro',
      isa      => 'Path::Class::File',
      required => 0,
      coerce   => 1,
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

sub BUILD {
    my ($self) = @_;

    my @path = split /:|;/, $ENV{PATH};

    for my $p (@path) {
	my $bl = $p."/"."blastn";
	my $mb = $p."/"."makeblastdb";
        if (-e $bl && -x $bl && $bl =~ /ncbi/ && -e $mb) {
            $self->set_blastn_exec($bl);
            $self->set_makeblastdb_exec($mb);
        }
    }
    try {
        die unless $self->has_makeblastdb_exec;
    }
    catch {
        $self->log->info("\n[ERROR]: Unable to find makeblastdb. Check you PATH to see that it is installed. Exiting.\n") 
	    if Log::Log4perl::initialized(); 
	exit(1);
    };
    try {
        die unless $self->has_blastn_exec;
    }
    catch {
        $self->log->info("\n[ERROR]: Unable to find blastn. Check you PATH to see that it is installed. Exiting.\n")
	    if Log::Log4perl::initialized(); 
	exit(1);
    };
}
    
=head1 METHODS

=head2 annotate_clusters

 Title   : annotation_clusters

 Usage   : $annotation->annotate_clusters();
           
 Function: Runs the annotation pipeline within Transposome.

                                                                            Return_type
 Returns : In order, 1) path to the cluster annotation file,                Scalar
                     2) path to the cluster annotation summary file,        Scalar
                     3) the total number of reads clusters,                 Scalar
                     4) the repeat fraction of the genome,                  Scalar
                     5) the individual cluster blast reports,               ArrayRef
                     6) the top superfamily hit for each cluster;           ArrayRef

                                                                            Arg_type
 Args    : In order, 1) cluster file generated by make_clusters()           Scalar
                        from Transposome::Cluster, 
                     2) the number of sequences that went into              Scalar
                        the clustering (returned from store_seq() 
                        from Transposome::SeqStore), 
                     3) the total number of clusters (also returned         Scalar
                        from make_clusters() from Transposome::Cluster).

=cut

sub annotate_clusters {
    my ($self, $cls_with_merges_dir, $seqct, $cls_tot) = @_;
    
    my $report = $self->file->relative;
    my $database = $self->database->absolute;
    my $db_path = $self->_make_blastdb($database);
    my $out_dir = $self->dir->relative;
    my $blastn = $self->get_blastn_exec;
    my $thread_range = sprintf("%.0f", $self->threads * $self->cpus);
    my ($rpname, $rppath, $rpsuffix) = fileparse($report, qr/\.[^.]*/);
    my $rp_path = Path::Class::File->new($out_dir, $rpname.$rpsuffix);

    open my $rep, '>>', $rp_path or die "\n[ERROR]: Could not open file: $rp_path\n";

    my $anno_rep = $rpname."_annotations.tsv";
    my $anno_summary_rep = $rpname."_annotations_summary.tsv";
    my $anno_rp_path = Path::Class::File->new($out_dir, $anno_rep);
    my $anno_sum_rep_path = Path::Class::File->new($out_dir, $anno_summary_rep);
    my $total_readct = 0;
    my $evalue = $self->evalue;
    my $rep_frac = $cls_tot / $seqct;
    
    # log results
    my $st = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("======== Transposome::Annotation::annotate_clusters started at $st.")
        if Log::Log4perl::initialized();

    say $rep "======> Total seqs: ",$seqct;
    say $rep "======> Total clustered: ",$cls_tot;
    say $rep "======> Repeat fraction: ",$rep_frac;
    close $rep;

    my $top_hit_superfam = {};
    my $cluster_annot = {};

    my $repeat_typemap = $self->map_repeat_types($database);
    my %repeats = %{ thaw($repeat_typemap) };

    ## get input files
    opendir my $dir, $cls_with_merges_dir || die "\n[ERROR]: Could not open directory: $cls_with_merges_dir. Exiting.\n";
    my @clus_fas_files = grep /\.fa.*$/, readdir $dir;
    closedir $dir;


    if (scalar @clus_fas_files < 1) {
        warn "\n[ERROR]: Could not find any fasta files in $cls_with_merges_dir. Exiting.\n" and exit(1);
    }

    ## set path to output dir
    my $annodir = $cls_with_merges_dir."_annotations";
    my $out_path = File::Spec->rel2abs($annodir);
    make_path($annodir, {verbose => 0, mode => 0711,});
    my @blasts;    # container for each report (hash) 
    my @blast_out; # container for blastn output
    my @superfams;
    my @cluster_annotations;
    my %all_cluster_annotations; # container for annotations; used for creating summary

    for my $file (@clus_fas_files) {
        my $query = $cls_with_merges_dir."/".$file;
        my ($fname, $fpath, $fsuffix) = fileparse($query, qr/\.[^.]*/);
        my $blast_res = $fname;
        my ($filebase, $readct) = split /\_/, $fname, 2;
        $total_readct += $readct;
        $blast_res =~ s/\.[^.]+$//;
        $blast_res .= "_blast_$evalue.tsv";
        my $blast_file_path = File::Spec->catfile($out_path, $blast_res);

        my @blastcmd = "$blastn -dust no -query $query -evalue $evalue -db $db_path -outfmt 6 -num_threads $thread_range | ".
                       "sort -k1,1 -u | ".                       # count each read in the report only once                                                 
                       "cut -f2 | ".                             # keep only the ssids        
                       "sort | ".                                # sort the list
                       "uniq -c | ".                             # reduce the list
                       "sort -bnr | ".                           # count unique items
                       "perl -lane 'print join(\"\\t\",\@F)'";   # create an easy to parse format
	
	try {
	    @blast_out = capture(EXIT_ANY, @blastcmd);
	}
	catch {
	    $self->log->info("\n[ERROR]: blastn failed. Caught error: $_")
		if Log::Log4perl::initialized();
	    exit(1);
	};

        my ($hit_ct, $top_hit, $top_hit_perc, $blhits) = $self->_parse_blast_to_top_hit(\@blast_out, $blast_file_path);
        next unless defined $top_hit && defined $hit_ct;
                                                           
        push @blasts, $blhits;
        ($top_hit_superfam, $cluster_annot) = $self->_blast_to_annotation(\%repeats, $filebase, $readct, $top_hit, $top_hit_perc); 
        push @superfams, $top_hit_superfam unless !%$top_hit_superfam;
	push @cluster_annotations, $cluster_annot unless !%$cluster_annot;
    }

    @all_cluster_annotations{keys %$_} = values %$_ for @cluster_annotations;

    open my $out, '>', $anno_rp_path or die "\n[ERROR]: Could not open file: $anno_rp_path\n";
    say $out join "\t", "Cluster", "Read_count", "Type", "Class", "Superfam", "Family","Top_hit","Top_hit_perc";

    for my $readct (reverse sort { $a <=> $b } keys %all_cluster_annotations) {
	my @annots = $self->mk_vec($all_cluster_annotations{$readct});
	my $cluster = shift @annots;
	say $out join "\t", $cluster, $readct, join "\t", @annots;
    }
    close $out;
    unlink glob("$db_path*");

    # log results
    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("======== Transposome::Annotation::annotate_clusters completed at $ft.")
        if Log::Log4perl::initialized();

    return ($anno_rp_path, $anno_sum_rep_path, $total_readct, $rep_frac, \@blasts, \@superfams);
}

=head2 clusters_annotation_to_summary

 Title   : clusters_annotation_to_summary

 Usage   : $annotation->clusters_annotation_to_summary();
           
 Function: Take individual cluster annotation files and generate a grand
           summary for the whole genome which describes the repeat abundance
           classified down to the family level.

 Returns : No data returned. This is the final step in the Transposome analysis
           pipeline.

                                                                            Arg_type
 Args    : In order, 1) the cluster annotation file                         Scalar
                     2) the annotation summary file                         Scalar
                     3) the total number of reads with a blast hit          Scalar
                     4) the total number of reads that went                 Scalar
                        into the clustering                                
                     5) the repeat fraction of the genome                   Scalar
                     6) the individual cluster blast reports                ArrayRef
                     7) the top superfamily hit for each cluster            ArrayRef

=cut 

sub clusters_annotation_to_summary  {
    my ($self, $anno_rp_path, $anno_sum_rep_path, $total_readct, 
	$seqct, $rep_frac, $blasts, $superfams) = @_;

    my $report = $self->file->relative;
    my ($rpname, $rppath, $rpsuffix) = fileparse($report, qr/\.[^.]*/);
    my $rp_path = File::Spec->rel2abs($rppath.$rpname.$rpsuffix);
    open my $rep, '>>', $rp_path or die "\n[ERROR]: Could not open file: $rp_path\n";

    # log results
    my $st = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("======== Transposome::Annotation::clusters_annotation_to_summary started at $st.")
        if Log::Log4perl::initialized();

    my %top_hit_superfam;
    @top_hit_superfam{keys %$_} = values %$_ for @$superfams;

    for my $f (keys %top_hit_superfam) {
	if ($f =~ /(^RL[CG][-_][a-zA-Z]+)/) {
            my $fam = $1;
            $top_hit_superfam{$fam} = $top_hit_superfam{$f};
            delete $top_hit_superfam{$f};
        }
    }

    open my $outsum, '>', $anno_sum_rep_path or die "\n[ERROR]: Could not open file: $anno_sum_rep_path\n";

    my %annot;
    my %fams;
    my $total_ct = 0;
    my $hashct = scalar @$blasts;
    my $hitct;
    for my $blast (@$blasts) {
        for my $fam (keys %$blast) {
            $total_ct += $blast->{$fam};
	    if ($fam =~ /(^RL[CG][-_][a-zA-Z]+)/) {
                my $famname = $1;
                if (exists $fams{$famname}) {
                    $fams{$famname} += $blast->{$fam};
                }
                else {
                    $fams{$famname} = $blast->{$fam};
                }
            }
            elsif ($fam =~ /(^Gypsy-\d+_[a-zA-Z]+)(?:[-|_][I|LTR])/) {
                my $famname = $1;
                if (exists $fams{$famname}) {
                    $fams{$famname} += $blast->{$fam};
                }
                else {
                    $fams{$famname} = $blast->{$fam};
                }
            }
            elsif ($fam =~ /(^Gyp.*\d+(?:-|_)(?:LTR|I)_w{2})/i) {
                my $famname = $1;
                if (exists $fams{$famname}) {
                    $fams{$famname} += $blast->{$fam};
                }
                else {
                    $fams{$famname} = $blast->{$fam};
                }
            }
	    elsif ($fam =~ /^([a-zA-Z]+)(?:-|_)(?:I|LTR)(_\w+)/) {
		my $famname = $1.$2;
                if (exists $fams{$famname}) {
                    $fams{$famname} += $blast->{$fam};
                }
                else {
                    $fams{$famname} = $blast->{$fam};
                }
	    }
	    elsif ($fam =~ /(^RL[CG]_\w+\d+_\d+)/) {
    	        my $famname = $1;
                if (exists $fams{$famname}) {
                    $fams{$famname} += $blast->{$fam};
                }   
                else {
                    $fams{$famname} = $blast->{$fam};
                }
	    }
            elsif ($fam =~ /(^Copia-\d+_[a-zA-Z]+)(?:[-|_][I|LTR])/) {
                my $famname = $1;
                if (exists $fams{$famname}) {
                    $fams{$famname} += $blast->{$fam};
                }
                else {
                    $fams{$famname} = $blast->{$fam};
                }
            }
            elsif ($fam =~ /^(COP\d+_)(?:I|LTR)_([a-zA-Z]+)/) {
                my $famname = $1.$2;
                if (exists $fams{$famname}) {
                    $fams{$famname} += $blast->{$fam};
                }
                else {
                    $fams{$famname} = $blast->{$fam};
                }
            }
	    elsif ($fam =~ /(^[A-Za-z]+)_/) {
		my $famname = $1;
                if (exists $fams{$famname}) {
                    $fams{$famname} += $blast->{$fam};
                }
                else {
                    $fams{$famname} = $blast->{$fam};
                }
            }
            else {
                if (exists $fams{$fam}) {
                    $fams{$fam} += $blast->{$fam};
                }
                else {
                    $fams{$fam} = $blast->{$fam};
                }
            }
        }
    }
    my $total_gcov = 0;

    say $outsum join "\t", "ReadNum", "Superfamily", "Family", "ReadCt/ReadsWithHit", "HitPerc", "GenomePerc";
    for my $k (reverse sort { $fams{$a} <=> $fams{$b} } keys %fams) {
        if (exists $top_hit_superfam{$k}) {
	    my $hit_perc = sprintf("%.12f",$fams{$k}/$total_ct);
	    my $gperc_corr = $hit_perc * $rep_frac;
            $total_gcov += $gperc_corr;
	    my $fam = $k;
	    $fam =~ s/\_I$// if $fam =~ /\_I$/;
	    $fam =~ s/\_LTR$// if $fam =~ /\_LTR$/;
            say $outsum join "\t", $seqct, $top_hit_superfam{$k}, $fam, $fams{$k}."/".$total_ct, $hit_perc, $gperc_corr;
        }
    }
    close $outsum;
    say $rep "======> Total repeat fraction from annotations: ",$total_gcov;
    close $rep;

    # log results
    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $self->log->info("======== Transposome::Annotation::clusters_annotation_to_summary completed at $ft.")
        if Log::Log4perl::initialized();
}

=head2 _make_blastdb

 Title : _make_blastdb
 
 Usage   : This is a private method, don't use it directly.
           
 Function: Creates a BLAST database of the repeat types being used
           for annotation.
                                                                            Return_type
 Returns : In order, 1) the blast database                                  Scalar

                                                                            Arg_type
 Args    : In order, 1) the Fasta file of repeats being                     Scalar
                        used for annotation

=cut 

sub _make_blastdb {
    my ($self, $db_fas) = @_;

    my $makeblastdb = $self->get_makeblastdb_exec;
    my ($dbname, $dbpath, $dbsuffix) = fileparse($db_fas, qr/\.[^.]*/);
    #my $db_file = File::Spec->rel2abs($dbpath.$dbname.$dbsuffix);

    my $db = $dbname."_blastdb";
    #my $db_path = File::Spec->rel2abs($dbpath.$db);
    my $db_path = Path::Class::File->new($self->dir, $db);
    unlink $db_path if -e $db_path;

    try {
	system([0..5],"$makeblastdb -in $db_fas -dbtype nucl -title $db -out $db_path 2>&1 > /dev/null");
    }
    catch {
	$self->log->info("\n[ERROR]: Unable to make blast database. Here is the exception: $_.")
	    if Log::Log4perl::initialized();
	$self->log->info("[ERROR]: Ensure you have removed non-literal characters (i.e., "*" or "-") in your repeat database file. These cause problems with BLAST+. Exiting.\n")
	    if Log::Log4perl::initialized();
	exit(1);
    };

    return $db_path;
}

=head2 _parse_blast_to_top_hit

 Title   : _parse_blast_to_top_hit

 Usage   : This is a private method, don't use it directly.
           
 Function: Calculates the top blast hit for each cluster.
 
                                                                            Return_type
 Returns : In order, 1) the total hit count                                 ScalarRef
                     2) the top blast hit                                   ScalarRef
                     3) the top blast hit percentage                        ScalarRef
                     4) a hash of all the hits and their counts             HashRef

                                                                            Arg_type
 Args    : In order, 1) the blast hits for the cluster                      ArrayRef
                     2) the blast output file                               Scalar
           

=cut

sub _parse_blast_to_top_hit {
    my ($self, $blast_out, $blast_file_path) = @_;
 
    my %blhits;
    my $hit_ct = 0;

    for my $hit (@$blast_out) {
        chomp $hit;
        my ($ct, $hittype) = split /\t/, $hit;
        next unless defined $ct;
        $blhits{$hittype} = $ct;
        $hit_ct++;
    }
    
    my $sum = sum values %blhits;
    if ($hit_ct > 0) {
        open my $out, '>', $blast_file_path or die "\n[ERROR]: Could not open file: $blast_file_path\n";
        my $top_hit = (reverse sort { $blhits{$a} <=> $blhits{$b} } keys %blhits)[0];
        my $top_hit_perc = sprintf("%.2f", $blhits{$top_hit} / $sum);
        keys %blhits; #reset iterator                                                                                                                         
        for my $hits (reverse sort { $blhits{$a} <=> $blhits{$b} } keys %blhits) {
            my $hit_perc = sprintf("%.2f", $blhits{$hits} / $sum);
            say $out join "\t", $hits, $blhits{$hits}, $hit_perc;
        }
        close $out;
        return \$hit_ct, \$top_hit, \$top_hit_perc, \%blhits;
    }
    else { ## if (!%blhits) {
        unlink $blast_file_path;
        return undef, undef, undef;
    }
}

=head2 _blast_to_annotation

 Title   : _blast_to_annotation

 Usage   : This is a private method, don't use it directly.
           
 Function: This method takes the blast hits and uses a key of repeat
           types to determine the taxonomic lineage for each repeat.

                                                                            Return_type
 Returns : In order, 1) the repeat annotation for each                      HashRef
                        top hit (per cluster)
                     2) a hash containing all hits and counts per           HashRef
                        superfamily
                                                                            Arg_type
 Args    : In order, 1) a hash containing taxonomic                         HashRef
                        relationships for all repeat types
                     2) the name of the cluster file being annotated        Scalar
                     3) the total number of reads with a blast hit          Scalar
                     4) the top blast hit                                   ScalarRef
                     5) the top blast hit percentage                        ScalarRef

=cut

sub _blast_to_annotation {
    my ($self, $repeats, $filebase, $readct, $top_hit, $top_hit_perc) = @_;

    my %top_hit_superfam;
    my %cluster_annot;

    for my $type (keys %$repeats) {
        if ($type eq 'pseudogene' || $type eq 'simple_repeat' || $type eq 'integrated_virus') {
            if ($type eq 'pseudogene' && $$top_hit =~ /rrna|trna|snrna/i) {
                my $anno_key = $self->mk_key($filebase, $type, $$top_hit, $$top_hit_perc);
                $cluster_annot{$readct} = $anno_key;
                last;
            }
            elsif ($type eq 'simple_repeat' && $$top_hit =~ /msat/i) {
                my $anno_key = $self->mk_key($filebase, $type, "Satellite", "MSAT", $$top_hit, $$top_hit_perc);
                $cluster_annot{$readct} = $anno_key;
                last;
            }
            elsif ($type eq 'simple_repeat' && $$top_hit =~ /sat/i) {
                my $anno_key = $self->mk_key($filebase, $type, "Satellite", "SAT", $$top_hit, $$top_hit_perc);
                $cluster_annot{$readct} = $anno_key;
                last;
            }
            elsif ($type eq 'integrated_virus' && $$top_hit =~ /caul/i) {
                my $anno_key = $self->mk_key($filebase, $type, "Caulimoviridae", $$top_hit, $$top_hit_perc);
                $cluster_annot{$readct} = $anno_key;
                last;
            }
            elsif ($type eq 'integrated_virus' && ($$top_hit eq 'PIVE' || $$top_hit eq 'DENSOV_HM')) {
                my $anno_key = $self->mk_key($filebase, $type, "DNA Virus", $$top_hit, $$top_hit_perc);
                $cluster_annot{$readct} = $anno_key;
                last;
            }
            elsif ($type eq 'endogenous_retrovirus' && $$top_hit =~ /erv/i) {
                my $anno_key = $self->mk_key($filebase, $type, "Endogenous Retrovirus", $$top_hit, $$top_hit_perc);
                $cluster_annot{$readct} = $anno_key;
                last;
            }
            next;
        }
        for my $class (keys %{$repeats->{$type}}) {
            while ( my ($superfam_index, $superfam) = each @{$repeats->{$type}{$class}} ) {
                for my $superfam_h (keys %$superfam) {
                    if ($superfam_h =~ /sine/i) {
                        while (my ($sine_fam_index, $sine_fam_h) = each @{$superfam->{$superfam_h}}) {
                            for my $sine_fam_mem (keys %$sine_fam_h) {
                                for my $sines (@{$repeats->{$type}{$class}[$superfam_index]{$superfam_h}[$sine_fam_index]{$sine_fam_mem}}) {
                                    for my $sine (@$sines) {
                                        if ($sine =~ /$$top_hit/) {
                                            ## only include the same level of depth as others
				            $top_hit_superfam{$$top_hit} = $sine_fam_mem;
                                            my $anno_key = $self->mk_key($filebase, $type, $class, $superfam_h, $sine_fam_mem, $$top_hit, $$top_hit_perc);
                                            $cluster_annot{$readct} = $anno_key;
                                            last;
                                        }
                                    }
                                }
                            }
                        }
                    }
		    elsif ($superfam_h =~ /gypsy/i && $$top_hit =~ /^RLG|Gyp/i) {
                        my $gypsy_fam; 
                        if ($$top_hit =~ /(^RLG[_|-][a-zA-Z]+)/) {
                            $gypsy_fam = $1;
                        }
                        elsif ($$top_hit =~ /(^Gypsy-\d+_[a-zA-Z]+)(?:[-|_][I|LTR])/) {
                            $gypsy_fam = $1;
                        }
                        elsif ($$top_hit =~ /(^Gyp.*\d+(?:-|_)(?:LTR|I)_w{2})/i) {
                            $gypsy_fam = $1;
                        }
                        elsif ($$top_hit =~ /^([a-zA-Z]+)(?:-|_)(?:I|LTR)(_\w+)/) {
                            $gypsy_fam = $1.$2;
                        }
                        elsif ($$top_hit =~ /(^RLG_\w+\d+_\d+)/) {
                            $gypsy_fam = $1;
                        }
                        elsif ($$top_hit =~ /(^[a-zA-Z]+)_/) {
                            $gypsy_fam = $1;
                        }
                        else {
                            $gypsy_fam = $$top_hit;
                        }
                        $gypsy_fam =~ s/\_I$// if $gypsy_fam =~ /\_I$/;                                                                                                    
                        $gypsy_fam =~ s/\_LTR$// if $gypsy_fam =~ /\_LTR$/;
                        $top_hit_superfam{$$top_hit} = $superfam_h;
                        my $anno_key = $self->mk_key($filebase, $type, $class, $superfam_h, $gypsy_fam, $$top_hit, $$top_hit_perc);
                        $cluster_annot{$readct} = $anno_key;
                        last;
                    }
                    elsif ($superfam_h =~ /copia/i && $$top_hit =~ /^RLC|Cop/i) {
                        my $copia_fam;
                        if ($$top_hit =~ /(^RLC[_|-][a-zA-Z]+)/) {
                            $copia_fam = $1;
                        }
                        elsif ($$top_hit =~ /(^Copia[-|_]\d+_[a-zA-Z]+)(?:[-|_][I|LTR])/) {
                            $copia_fam = $1;
                        }
                        elsif ($$top_hit =~ /^(COP\d+_)(?:I|LTR)_([a-zA-Z]+)/) {
                            $copia_fam = $1.$2;
                        }
                        elsif ($$top_hit =~ /(^[A-Za-z]+)_/) {
                            $copia_fam = $1;
                        }
                        else {
                            $copia_fam = $$top_hit;
                        }
                        $copia_fam =~ s/\_I$// if $copia_fam =~ /\_I$/;                                                                                                    
                        $copia_fam =~ s/\_LTR$// if $copia_fam =~ /\_LTR$/;
                        $top_hit_superfam{$$top_hit} = $superfam_h;
                        my $anno_key = $self->mk_key($filebase, $type, $class, $superfam_h, $copia_fam, $$top_hit, $$top_hit_perc);
                        $cluster_annot{$readct} = $anno_key;
                        last;
                    }
                    else {
                        for my $fam (@{$repeats->{$type}{$class}[$superfam_index]{$superfam_h}}) {
                            for my $mem (@$fam) {
                                if ($mem =~ /$$top_hit/i) {
			            $$top_hit =~ s/\_I$// if $$top_hit =~ /\_I$/;
			            $$top_hit =~ s/\_LTR$// if $$top_hit =~ /\_LTR$/;
                                    $top_hit_superfam{$$top_hit} = $superfam_h;
				    my $unk_fam = q{ };
                                    my $anno_key = $self->mk_key($filebase, $type, $class, $superfam_h, $unk_fam, $$top_hit, $$top_hit_perc);
                                    $cluster_annot{$readct} = $anno_key;
                                    last;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return(\%top_hit_superfam, \%cluster_annot);
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

    perldoc Transposome::Annotation


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
