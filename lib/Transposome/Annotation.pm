package Transposome::Annotation;

use 5.012;
use Moose;
use namespace::autoclean;
use List::Util qw(sum max);
use IPC::System::Simple qw(system capture EXIT_ANY);
use File::Path qw(make_path);
use File::Basename;
use Try::Tiny;
use autodie qw(open);

with 'File', 'Util';

=head1 NAME

Transposome::Annotation - Annotate clusters for repeats.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    use Transposome::Annotation;

    my $trans_obj = Transposome::Annotation->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=cut

has 'database' => (
      is       => 'ro',
      isa      => 'Path::Class::File',
      required => 1,
      coerce   => 1,
    );

has 'rb_json' => (
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
    
=head1 SUBROUTINES/METHODS

=head2 annotate_clusters

 Title   : annotation_clusters
 Usage   : $trans_obj->annotate_clusters();
           
 Function: 
 Returns : 
 Args    : 

=cut

sub annotate_clusters {
    my ($self, $cls_with_merges_dir, $seqct, $cls_tot) = @_;
    
    my $report = $self->file->relative;
    my $database = $self->database->relative;
    my $out_dir = $self->dir->relative;
    my $json = $self->rb_json->relative;
    my ($rpname, $rppath, $rpsuffix) = fileparse($report, qr/\.[^.]*/);
    my $rp_path = File::Spec->rel2abs($rppath.$rpname.$rpsuffix);
    open my $rep, '>>', $rp_path;
    my $anno_rep = $rpname."_annotations.tsv";
    my $anno_summary_rep = $rpname."_annotations_summary.tsv";
    my $anno_rp_path = File::Spec->rel2abs($rppath.$anno_rep);
    my $anno_sum_rep_path = File::Spec->rel2abs($rppath.$anno_summary_rep);
    my $total_readct = 0;
    #$evalue //= 10;
    my $evalue = $self->evalue;
    my $rep_frac = $cls_tot / $seqct;
    say $rep "======> Total seqs: ",$seqct;
    say $rep "======> Total clustered: ",$cls_tot;
    say $rep "======> Repeat fraction: ",$rep_frac;
    close $rep;
    my $top_hit_superfam = {};
    my $cluster_annot = {};

    ## get input files
    opendir my $dir, $cls_with_merges_dir || die "\nERROR: Could not open directory: $cls_with_merges_dir. Exiting.\n";
    my @clus_fas_files = grep /\.fa.*$/, readdir $dir;
    closedir $dir;


    if (scalar @clus_fas_files < 1) {
        say "\nERROR: Could not find any fasta files in $cls_with_merges_dir. Exiting.\n";
        exit(1);
    }

    ## set path to output dir
    my $annodir = $cls_with_merges_dir."_annotations";
    my $out_path = File::Spec->rel2abs($annodir);
    make_path($annodir, {verbose => 0, mode => 0711,}); # allows for recursively making paths                                                                 
    my ($dname, $dpath, $dsuffix) = fileparse($database, qr/\.[^.]*/);
    my $db_path = File::Spec->rel2abs($dpath.$dname);
    my @blasts;    # container for each report (hash) 
    my @blast_out; # container for blastn output
    my @superfams;
    my @cluster_annotations;

    #chdir $cls_with_merges_dir;

    for my $file (@clus_fas_files) {
        my $query = $cls_with_merges_dir."/".$file;
        my ($fname, $fpath, $fsuffix) = fileparse($query, qr/\.[^.]*/);
        my $blast_res = $fname;
        my ($filebase, $readct) = split /\_/, $fname, 2;
        $total_readct += $readct;
        $blast_res =~ s/\.[^.]+$//;
        $blast_res .= "_blast_$evalue.tsv";
        my $blast_file_path = File::Spec->catfile($out_path, $blast_res);

        my @blastcmd = "blastn -dust no -query $query -evalue $evalue -db $db_path -outfmt 6 | ".
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
	    warn "\nERROR: blastn failed. Caught error: $_" and exit;
	};

	#dd @blast_out; exit;
        my ($hit_ct, $top_hit, $top_hit_perc, $blhits) = $self->_parse_blast_to_top_hit(\@blast_out, $blast_file_path);
        next unless defined $top_hit && defined $hit_ct;
                                                           
        push @blasts, $blhits;
        ($top_hit_superfam, $cluster_annot) = $self->_blast_to_annotation($json, $filebase, $readct, $top_hit, $top_hit_perc); 
        push @superfams, $top_hit_superfam unless !%$top_hit_superfam;
	push @cluster_annotations, $cluster_annot unless !%$cluster_annot;
    }

    my %all_cluster_annotations;
    @all_cluster_annotations{keys %$_} = values %$_ for @cluster_annotations;

    open my $out, '>', $anno_rp_path;
    say $out join "\t", "Cluster", "Read_count", "Type", "Class", "Superfam", "Family","Top_hit","Top_hit_perc";

    for my $readct (reverse sort { $a <=> $b } keys %all_cluster_annotations) {
	my @annots = $self->mk_vec($all_cluster_annotations{$readct});
	my $cluster = shift @annots;
	say $out join "\t", $cluster, $readct, join "\t", @annots;
    }
    close $out;

    return ($anno_rp_path, $anno_sum_rep_path, $total_readct, $rep_frac, \@blasts, \@superfams);
}

=head2 clusters_annotation_to_summary

 Title   : clusters_annotation_to_summary
 Usage   : 
           
 Function: 
 Returns : The current value of filename
 Args    : 


=cut

sub clusters_annotation_to_summary  {
    my ($self, $anno_rp_path, $anno_sum_rep_path, $total_readct, 
	$seqct, $rep_frac, $blasts, $superfams) = @_;

    my $report = $self->report->relative;
    my ($rpname, $rppath, $rpsuffix) = fileparse($report, qr/\.[^.]*/);
    my $rp_path = File::Spec->rel2abs($rppath.$rpname.$rpsuffix);
    open my $rep, '>>', $rp_path;

    my %top_hit_superfam;
    @top_hit_superfam{keys %$_} = values %$_ for @$superfams;

    for my $f (keys %top_hit_superfam) {
	if ($f =~ /(^RL(C|G)(\-|\_)\w+)\-|\_\d+/) {
            my $fam = $1;
            $top_hit_superfam{$fam} = $top_hit_superfam{$f};
            delete $top_hit_superfam{$f};
        }
    }

    open my $outsum, '>', $anno_sum_rep_path;

    my %annot;
    my %fams;
    my $total_ct = 0;
    my $hashct = scalar @$blasts;
    my $hitct;
    for my $blast (@$blasts) {
        for my $fam (keys %$blast) {
            $total_ct += $blast->{$fam};
	    if ($fam =~ /(^RL(C|G)(\-|\_)\w+)\-|\_\d+/) {
                my $famname = $1;
		if (not defined $famname) { say "\nERROR: $fam is not defined after regex"; next; }
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

    say $outsum join "\t", "ReadNum", "Superfamily", "Family", "ReadCt/ReadsWithHit", "HitPerc", "GPerc";
    for my $k (reverse sort { $fams{$a} <=> $fams{$b} } keys %fams) {
        if (exists $top_hit_superfam{$k}) {
	    my $hit_perc = sprintf("%.12f",$fams{$k}/$total_ct);
	    my $gperc_corr = $hit_perc * $rep_frac;
            $total_gcov += $gperc_corr;
            say $outsum join "\t", $seqct, $top_hit_superfam{$k}, $k, $fams{$k}."/".$total_ct, $hit_perc, $gperc_corr;
        }
    }
    close $outsum;
    say $rep "======> Total repeat fraction from annotations: ",$total_gcov;
    close $rep;
}

=head2 _parse_blast_to_top_hit

 Title   : parse_blast_to_top_hit
 Usage   : 
           
  Function: 
 Returns : 
 Args    : 
           

=cut

sub _parse_blast_to_top_hit {
    my ($self, $blast_out, $blast_file_path) = @_;
    my %blhits;

    #my $top_hit;
    #my $top_hit_perc;
    #my $top_hit_num = 0;
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
        open my $out, '>', $blast_file_path;
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

 Title   : blast_to_annotation
 Usage   : 
           
  Function: 
 Returns : 
 Args    : 

=cut

sub _blast_to_annotation {
    my ($self, $json, $filebase, $readct, $top_hit, $top_hit_perc) = @_;

    my %top_hit_superfam;
    my %cluster_annot;
    my $repeats = $self->json_to_hash($json);

    for my $type (keys %$repeats) {
        if ($type eq 'pseudogene' || $type eq 'simple_repeat' || $type eq 'integrated_virus') {
            if ($type eq 'pseudogene' && $$top_hit =~ /rrna|trna|snrna/i) {
                #say join "\t", $filebase, $type, $$top_hit, $$top_hit_perc;
                my $anno_key = $self->mk_key($filebase, $type, $$top_hit, $$top_hit_perc);
                $cluster_annot{$readct} = $anno_key;
                last;
            }
            elsif ($type eq 'simple_repeat' && $$top_hit =~ /msat/i) {
                #say join "\t", $filebase, $type, "Satellite", "MSAT", $$top_hit, $$top_hit_perc;
                my $anno_key = $self->mk_key($filebase, $type, "Satellite", "MSAT", $$top_hit, $$top_hit_perc);
                $cluster_annot{$readct} = $anno_key;
                last;
            }
            elsif ($type eq 'simple_repeat' && $$top_hit =~ /sat/i) {
                #say join "\t", $filebase, $type, "Satellite", "SAT", $$top_hit, $$top_hit_perc;
                my $anno_key = $self->mk_key($filebase, $type, "Satellite", "SAT", $$top_hit, $$top_hit_perc);
                $cluster_annot{$readct} = $anno_key;
                last;
            }
            elsif ($type eq 'integrated_virus' && $$top_hit =~ /caul/i) {
		#say join "\t", $filebase, $type, "Caulimoviridae", $$top_hit, $$top_hit_perc;
                my $anno_key = $self->mk_key($filebase, $type, "Caulimoviridae", $$top_hit, $$top_hit_perc);
                $cluster_annot{$readct} = $anno_key;
                last;
            }
            elsif ($type eq 'integrated_virus' && ($$top_hit eq 'PIVE' || $$top_hit eq 'DENSOV_HM')) {
                #say join "\t", $filebase, $type, "DNA Virus", $$top_hit, $$top_hit_perc;
                my $anno_key = $self->mk_key($filebase, $type, "DNA Virus", $$top_hit, $$top_hit_perc);
                $cluster_annot{$readct} = $anno_key;
                last;
            }
            elsif ($type eq 'endogenous_retrovirus' && $$top_hit =~ /erv/i) {
                #say join "\t", $filebase, $type, "Endogenous Retrovirus", $$top_hit, $$top_hit_perc;
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
					    #say join "\t", $filebase, $type, $class, $superfam_h, $sine_fam_mem, $$top_hit, $$top_hit_perc;
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
                        if ($$top_hit =~ /(^RLG(\_|\-)\w+)/) {
                            $gypsy_fam = $1;
                        }
                        elsif ($$top_hit =~ /(^Gypsy\-\d+\_\w+)\-I|LTR/) {
                            $gypsy_fam = $1;
                        }
                        elsif ($$top_hit =~ /(^Gyp.*\d+\-(LTR|I)\_w{2})/i) {
                            $gypsy_fam = $1;
                        }
                        elsif ($$top_hit =~ /((^\w+)\-(I|LTR)(\_\w+))/) {
                            $gypsy_fam = $2.$4;
                        }
                        elsif ($$top_hit =~ /(^RLG\_\w+\d+\_\d+)/) {
                            $gypsy_fam = $1;
                        }
                        elsif ($$top_hit =~ /(^\S+)\_/) {
                            $gypsy_fam = $1;
                        }
                        else {
                            $gypsy_fam = $$top_hit;
                        }
                        $top_hit_superfam{$$top_hit} = $superfam_h;
                        #say join "\t", $filebase, $type, $class, $superfam_h, $gypsy_fam, $$top_hit, $$top_hit_perc;
                        #try {
                        my $anno_key = $self->mk_key($filebase, $type, $class, $superfam_h, $gypsy_fam, $$top_hit, $$top_hit_perc);
                        $cluster_annot{$readct} = $anno_key;
                        #}
                        #catch {
                        #    warn "\WARNING: Problem matching Gypsy family, this may be a bug: $_\n";
                        #};

                        #$cluster_annot{$readct} = $anno_key;
                        last;
                    }
                    elsif ($superfam_h =~ /copia/i && $$top_hit =~ /^RLC|Cop/i) {
			#my $copia_fam = $1 if $top_hit =~ /(^RLC(\_|\-)\w+)/;
                        my $copia_fam;
                        if ($$top_hit =~ /(^RLC(\_|\-)\w+)/) {
                            $copia_fam = $1;
                        }
                        elsif ($$top_hit =~ /(^Copia\-\d+\_\w+)\-I|LTR/) {
                            $copia_fam = $1;
                        }
                        elsif ($$top_hit =~ /(^(COP\d+)\_(I|LTR)(\_\w+))/) {
                            $copia_fam = $1;
                        }
                        elsif ($$top_hit =~ /(^Copia\-\d+\_\w+)\-(I|LTR)/) {
                            $copia_fam = $1;
                        }
                        elsif ($$top_hit =~ /(^\S+)\_/) {
                            $copia_fam = $1;
                        }
                        else {
                            $copia_fam = $$top_hit;
                        }
                        $top_hit_superfam{$$top_hit} = $superfam_h;
                        #say join "\t", $filebase, $type, $class, $superfam_h, $copia_fam, $$top_hit, $$top_hit_perc;
                        #try {
                        my $anno_key = $self->mk_key($filebase, $type, $class, $superfam_h, $copia_fam, $$top_hit, $$top_hit_perc);
                        $cluster_annot{$readct} = $anno_key;
                        #}
                        #catch {
                        #    warn "\WARNING: Problem matching Copia family, this may be a bug: $_\n";
                        #};
                        #$cluster_annot{$readct} = $anno_key;
                    }
                    else {
			for my $fam (@{$repeats->{$type}{$class}[$superfam_index]{$superfam_h}}) {
                            for my $mem (@$fam) {
                                if ($mem =~ /$$top_hit/i) {
                                    $top_hit_superfam{$$top_hit} = $superfam_h;
				    #say join "\t", $filebase, $type, $class, $superfam_h, $fam, $$top_hit, $$top_hit_perc;
                                    my $unk_fam = " ";
				    #try {
                                    my $anno_key = $self->mk_key($filebase, $type, $class, $superfam_h, $unk_fam, $$top_hit, $$top_hit_perc);
                                    $cluster_annot{$readct} = $anno_key;
				    #}
				    #catch {
                                    #warn "\WARNING: Problem matching family, this may be a bug: $_\n";
				    #   };
				    #$cluster_annot{$readct} = $anno_key;
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

Please report any bugs or feature requests to C<bug-transposome at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Transposome>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::Annotation


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

#1; # End of Transposome::Annotation
__PACKAGE__->meta->make_immutable;
