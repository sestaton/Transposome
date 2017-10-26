package Transposome::Annotation::Summary;

use 5.010;
use Moose::Role;
use POSIX    qw(strftime);
use Log::Any qw($log);
#use Data::Dump::Color;

with 'Transposome::Role::Util';

=head1 NAME

Transposome::Annotation::Summary - Generate an annotation summary for the whole genome (all clusters)

=head1 VERSION

Version 0.12.0

=cut

our $VERSION = '0.12.0';
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

=head2 clusters_annotation_to_summary

 Title   : clusters_annotation_to_summary

 Usage   : $annotation->clusters_annotation_to_summary();
           
 Function: Take individual cluster annotation files and generate a grand
           summary for the whole genome which describes the repeat abundance
           classified down to the family level.

 Returns : No data returned. This is the final step in the Transposome analysis
           pipeline.

 Args    : A Perl hash containing the cluster annotation results.

           The following is an example data structure returned by
           the annotate_clusters method:

           { annotation_report     => $anno_rp_path,
	     annotation_summary    => $anno_sum_rep_path,
	     singletons_report     => $singles_rp_path,
	     total_sequence_num    => $total_readct,
	     repeat_fraction       => $rep_frac,
	     cluster_blast_reports => $blasts,
	     cluster_superfamilies => $superfams }

            A description of the hash values:
                                                                            Arg_type
            annotation_report - path to the cluster annotation file         Scalar
            annotation_summary - path to the cluster annotation summary     Scalar
                                 file
            singletons_file - path to the singletons annotation file        Scalar
            total_sequence_num - the total number of reads clusters         Scalar
            repeat_fraction - the repeat fraction of the genome             Scalar
            cluster_blast_reports - the individual cluster blast reports    ArrayRef
            cluster_suparfamilies - the top superfamily hit for each        ArraryRef
                                    cluster

=cut 

sub clusters_annotation_to_summary {
    my $self = shift;
    my ($annotation_results) = @_;
    my $anno_rp_path      = $annotation_results->{annotation_report};
    my $anno_sum_rep_path = $annotation_results->{annotation_summary};
    my $singles_rp_path   = $annotation_results->{singletons_report};
    my $total_readct      = $annotation_results->{total_sequence_num};
    my $total_annotated_n = $annotation_results->{total_annotated_num};
    my $rep_frac          = $annotation_results->{repeat_fraction};
    my $blasts            = $annotation_results->{cluster_blast_reports};
    my $top_hit_superfam  = $annotation_results->{cluster_superfamilies};
    
    # log results
    my $st = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    
    open my $outsum, '>', $anno_sum_rep_path 
        or die "\n[ERROR]: Could not open file: $anno_sum_rep_path\n";
    
    my %annot;
    my %fams;
    my %superfams;
    my $total_ct = 0;
    my $hashct   = @$blasts;
    my $hitct;

    for my $blast (@$blasts) {
        for my $fam (keys %$blast) {
	    if (exists $top_hit_superfam->{$fam}) {
		my ($family, $superfam, $class) = $self->mk_vec($top_hit_superfam->{$fam});
		$total_ct += $blast->{$fam};
		$fams{$class}{$family} += $blast->{$fam};
		$superfams{$class}{$family} = $superfam;
	    }
        }
    }
    my $total_gcov = 0;

    my %summary_sort;
    for my $type (keys %fams) {
	for my $k (keys %{$fams{$type}}) {
	    my $sf = $superfams{$type}{$k};
	    my $hit_perc   = sprintf("%.12f", $fams{$type}{$k}/$total_ct);
	    my $gperc_corr = $hit_perc * $rep_frac;
	    $total_gcov += $gperc_corr;
	    my $key = $self->mk_key($gperc_corr, $total_readct, $type, $sf, $k);
	    $summary_sort{$key} = 1; #$self->mk_key($total_readct, $type, $sf, $k);
	}
    }

    say $outsum join "\t", "ReadNum", "Order", "Superfamily", "Family", "GenomeFraction";

    for my $id ( map $_->[0],
		 reverse sort { $a->[1] <=> $b->[1] } 
		 map [ $_, split /\~\~/ ],
		 keys %summary_sort ) { 
	my @summary = $self->mk_vec($id);
	my $gperc = shift @summary;
	say $outsum join "\t", @summary, $gperc;
    }
    close $outsum;
    
    $log->info("Results - Total repeat fraction from annotations: $total_gcov");

    # log results
    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("Transposome::Annotation::clusters_annotation_to_summary started at:   $st.");
    $log->info("Transposome::Annotation::clusters_annotation_to_summary completed at: $ft.");
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

    perldoc Transposome::Annotation::Summary


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2017 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

1;
