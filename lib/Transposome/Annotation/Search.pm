package Transposome::Annotation::Search;

use 5.010;
use Moose::Role;
use IPC::System::Simple qw(system capture EXIT_ANY);
use Path::Class::File;
use File::Basename;
use Try::Tiny;
use Log::Any qw($log);

=head1 NAME

Transposome::Annotation::Search - Run the BLAST search on the clusters and singletons.

=head1 VERSION

Version 0.11.3

=cut

our $VERSION = '0.11.3';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    Consume this role in your class, or use Transposome::Annotation directly. E.g.,

    use Transposome::Annotation;

    my $cluster_file = '/path/to/cluster_file.cls';
    my $seqct        = 'total_seqs_in_analysis';    # Integer
    my $cls_tot      = 'total_reads_clustered';     # Integer

    my $annotation = Transposome::Annotation->new( database  => 'repeat_db.fas',
                                                   dir       => 'outdir',
                                                   file      => 'report.txt' );

    my $annotation_results =
        $annotation->annotate_clusters({ cluster_directory => $cls_dir_path,
                                         singletons_file => $singletons_file_path,
                                         total_sequence_num => $seqct,
                                         total_cluster_num => $cls_tot });
    
    $annotation->clusters_annotation_to_summary( $annotation_results );

=cut

=head1 METHODS

=head2 

 Title   : search_clusters

 Usage   : my $blast_out = $self->search_clusters($blast_data);
           
 Function: Run the BLAST search on a sequence set and return the matched
           repeats from the repeat database.

                                                                            Return_type
 Returns : A reference to an array containing the BLAST results             ArrayRef

           The data is tab-delimited in the format:
           hit_ct    hittype

           A description of the columns:

           hit_ct - the BLAST hit counts
           hittype - the specif BLAST hit

 Args    : A Perl hash containing blast data for annotating clusters.

           An example of the hash:

           { blast_exe    => $blastn,
             query_file   => $query,
             evalue       => $evalue,
             blastdb      => $db_path,
             thread_range => $thread_range }

           A description of the hash values:
                                                                            Arg_type
           blast_exe - the path to the blastn executable                    Scalar
           query_file - the FASTA file for a cluster                        Scalar
           evalue - the BLAST evalue cutoff to use in the analysis          Scalar
           blastdb - the path to the BLAST database (the repeats file)      Scalar
           thread_range - the number of threads to use for the BLAST        Scalar
                          search
=cut

sub search_clusters {
    my $self = shift;
    my ($blast_data) = @_;
    my $blastn  = $blast_data->{blast_exe};
    my $query   = $blast_data->{query_file};
    my $evalue  = $blast_data->{evalue};
    my $blastdb = $blast_data->{blastdb};
    my $thread_range = $blast_data->{thread_range};

    my @blast_out;

    my @blastcmd = "$blastn -dust no -query $query -evalue $evalue -db $blastdb ".
	"-outfmt 6 -num_threads $thread_range | ".
	"sort -k1,1 -u | ". # count each read in the report only once
	"cut -f2 | ".       # keep only the ssids
	"sort | ".          # sort the list
	"uniq -c | ".       # reduce the list
	"sort -bnr | ".     # count unique items
	"perl -lane 'print join(\"\\t\",\@F)'"; # create an easy to parse format

    try {
	@blast_out = capture(EXIT_ANY, @blastcmd);
    }
    catch { 
	$log->error("blastn failed. Caught error: $_.");
	exit(1);
    }; 

    return \@blast_out;
}

=head2 

 Title   : search_singletons

 Usage   : my $blast_out = $self->search_singletons($blast_data);
           
 Function: Run the BLAST search on a sequence set and return the matched
           repeats from the repeat database.

                                                                            Return_type
 Returns : A reference to an array containing the BLAST results             ArrayRef

           The data is tab-delimited in the format:
           hit_ct    hittype

           A description of the columns:

           hit_ct - the BLAST hit counts
           hittype - the specif BLAST hit

 Args    : A Perl hash containing blast data for annotating clusters.=head2 

           An example of the hash:

           { blast_exe    => $blastn,
             query_file   => $query,
             evalue       => $evalue,
             blastdb      => $db_path,
             thread_range => $thread_range }

           A description of the hash values:
                                                                            Arg_type
           blast_exe - the path to the blastn executable                    Scalar
           query_file - the FASTA file for the singletons                   Scalar
           evalue - the BLAST evalue cutoff to use in the analysis          Scalar
           blastdb - the path to the BLAST database (the repeats file)      Scalar
           thread_range - the number of threads to use for the BLAST        Scalar
                          search
=cut

sub search_singletons {
    my $self = shift;
    my ($singles_data) = @_;
    my $blastn  = $singles_data->{blast_exe};
    my $query   = $singles_data->{query_file};
    my $evalue  = $singles_data->{evalue};
    my $blastdb = $singles_data->{blastdb};
    my $thread_range = $singles_data->{thread_range};
    my $outfile = $singles_data->{blast_output_file};

    my @blastcmd = "$blastn -dust no -query $query -evalue $evalue -db $blastdb ".
                   "-outfmt 6 -num_threads $thread_range -max_target_seqs 1 |".
                   "sort -k1,1 -u > $outfile";

    my $exit_code;
    try {
        $exit_code = system([0..5], @blastcmd);
    }
    catch {
        $log->error("blastn failed with exit code: $exit_code. Caught error: $_.");
        exit(1);
    };
    return $exit_code;
}

=head2 make_blastdb

 Title   : make_blastdb

 Usage   : my $db_path = $self->make_blastdb($db_fas);
           
 Function: Creates a BLAST database of the repeat types being used
           for annotation.
                                                                            Return_type
 Returns : In order, 1) the blast database                                  Scalar

                                                                            Arg_type
 Args    : In order, 1) the Fasta file of repeats being                     Scalar
                        used for annotation

=cut 

sub make_blastdb {
    my $self = shift;
    my ($db_fas) = @_;
    my $makeblastdb = $self->get_makeblastdb_exec;
    my ($dbname, $dbpath, $dbsuffix) = fileparse($db_fas, qr/\.[^.]*/);

    my $db = $dbname."_blastdb";
    my $db_path = Path::Class::File->new($self->dir, $db);    
    unlink $db_path if -e $db_path;

    try {
        my @makedbout = capture([0..5],"$makeblastdb -in $db_fas -dbtype nucl -title $db -out $db_path 2>&1 > /dev/null");
    }
    catch {
	$log->error("Unable to make blast database. Here is the exception: $_.");
	$log->error("Ensure you have removed non-literal characters (i.e., "*" or "-") in your repeat database file.");
	$log->error("These cause problems with BLAST+. Exiting.");
        exit(1);
    };

    return $db_path;
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

    perldoc Transposome::Annotation::Search


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2015 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

1;
