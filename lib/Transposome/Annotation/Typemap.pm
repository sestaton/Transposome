package Transposome::Annotation::Typemap;

use 5.012;
use Moose::Role;
use MooseX::Method::Signatures;
use Storable qw(freeze);

=head1 NAME

Transposome::Annotation::Typemap - Create a map of repeats to the family level.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

    Consume this role in your class, or use Transposome::Annotation directly. E.g.,

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

=head1 METHODS

=head2 map_repeat_types

 Title   : map_repeat_types

 Usage   : my $annotation = Transposome::Annotation->new();
      
           my $database = 'custom_repeats.fasta';

           my $repeat_map = $annotation->map_repeat_types($database);
           
 Function: Create a mapping of the input repeats to the full repeat 
           taxonomic lineage.

                                                                            Return_type
 Returns : A complex data structure of the repeat taxonomy from Class       HashRef
           to the element belonging to a particular family
            
                                                                            Arg_type
 Args    : The repeat database being used for annotation                    Scalar

=cut

method map_repeat_types ($infile) {
    open my $in, '<', $infile or die "\n[ERROR]: Could not open file: $infile\n";

    my $matches = $self->_build_repeat_map();

    my %family_map;

    while (my $line = <$in>) {
	chomp $line;
	if ($line =~ /^>/) {
	    $line =~ s/>//;
	    my ($f, $sf, $source)  = split /\t/, $line;
	    next unless defined $sf && defined $f; 
	    if ($sf =~ /(\s+)/) {
		$sf =~ s/$1/\_/;
	    }
	    $f =~ s/\s/\_/;
	    if (exists $family_map{$sf}) {
		push @{$family_map{$sf}}, $f;
	    }
	    else {
		$family_map{$sf} = [];
	    }
	}
    }
    close $in;

    for my $type (keys %$matches) {
	unless ($type eq 'pseudogene' || $type eq 'integrated_virus') {
	    for my $class (keys %{$matches->{$type}}) {
		while ( my ($superfam_index, $superfam) = each @{$matches->{$type}{$class}} ) {
		    for my $superfam_h (keys %$superfam) {
			my $superfam_cp = lc($superfam_h);
			for my $mapped_fam (keys %family_map) {
			    my $mapped_fam_cp = lc($mapped_fam);
			    if (length($superfam_cp) > 1 && length($mapped_fam_cp) > 1) {
				if ($mapped_fam_cp =~ /sine/i && $superfam_cp =~ /sine/i) {
				    while (my ($sine_fam_index, $sine_fam_h) = each @{$superfam->{$superfam_h}}) {
					for my $sine_fam_mem (keys %$sine_fam_h) {
					    if ($sine_fam_mem =~ /$mapped_fam_cp/i && $mapped_fam_cp =~ /^(?!sine$)/) {
						push @{$matches->{$type}{$class}[$superfam_index]{$superfam_h}[$sine_fam_index]{$sine_fam_mem}}, 
						$family_map{$mapped_fam};
					    }
					}
				    }
				} 
				elsif ($mapped_fam_cp =~ /$superfam_cp/) {
				    push @{$matches->{$type}{$class}[$superfam_index]{$superfam_h}}, $family_map{$mapped_fam};
				}
				elsif (length($mapped_fam_cp) == 1 && length($superfam_cp) == 1) {
				    if ($mapped_fam_cp =~ /$superfam_cp/) {
					push @{$matches->{$type}{$class}[$superfam_index]{$superfam_h}}, $family_map{$mapped_fam};
				    }
				}
			    }
			}
		    }
		} 
	    } 
	}
    }
    
    my $matches_ser = freeze $matches;   
    return $matches_ser;
}

=head2 _build_repeat_map

 Title : _build_repeat_map
 
 Usage   : This is a private method, don't use it directly.
           
 Function: Creates a data structure containing a full taxonomic
           map of repeat types.
                                                                            Return_type
 Returns : A complex data structure containing a mapping of                 HashRef
           repeat types from Class to Family

 Args    : None. This is a class method called on a object
           of the class consuming this role.

=cut 

method _build_repeat_map {
    my $matches = {};
    
    $matches->{'transposable_element'}{'dna_transposon'} = [{'Mariner/Tc1' => []}, {'hAT' => []}, 
							    {'MuDR' => []}, {'EnSpm' => []}, 
							    {'piggyBac' => []}, {'P' => []}, 
							    {'Merlin' => []}, {'Harbinger' => []}, 
							    {'Transib' => []}, {'Novosib' => []}, 
							    {'Helitron' => []}, {'Polinton' => []}, 
							    {'Kolobok' => []}, {'ISL2EU' => []}, 
							    {'Crypton' => []}, {'Sola' => []}, 
							    {'Zator' => []}, {'Ginger/1' => []}, 
							    {'Ginger2/TDD' => []}, {'Academ' => []}, 
							    {'Zisupton' => []}, {'IS3EU' => []}];
    
    $matches->{'transposable_element'}{'ltr_retrotransposon'} = [{'Gypsy' => []}, {'Copia' => []}, 
								 {'BEL' => []}, {'DIRS' => []}];
    
    $matches->{'transposable_element'}{'endogenous_retrovirus'} = [{'ERV1' => []}, {'ERV2' => []}, 
								   {'ERV3' => []}, {'Lentivirus' => []}, 
								   {'ERV4' => []}];
    
    $matches->{'transposable_element'}{'non-ltr_retrotransposon'} = [{'SINE' => [{'SINE1/7SL' => []}, {'SINE2/tRNA' => []},
										 {'SINE3/5S' => []},{'SINE4' => []}]},
								     {'CRE' => []}, {'NeSL' => []}, 
								     {'R4' => []}, {'R2' => []}, 
								     {'L1' => []}, {'RTE' => []}, 
								     {'I' => []}, {'Jockey' => []}, 
								     {'CR1' => []}, {'Rex1' => []}, 
								     {'RandI' => []}, {'Penelope' => []}, 
								     {'Tx1' => []}, {'RTEX' => []}, 
								     {'Crack' => []}, {'Nimb' => []}, 
								     {'Proto1' => []}, {'Proto2' => []}, 
								     {'RTETP' => []}, {'Hero' => []}, 
								     {'L2' => []}, {'Tad1' => []}, 
								     {'Loa' => []}, {'Ingi' => []}, 
								     {'Outcast' => []}, {'R1' => []}, 
								     {'Daphne' => []}, {'L2A' => []}, 
								     {'L2B' => []}, {'Ambal' => []}, 
								     {'Vingi' => []}, {'Kiri' => []}];
    
    $matches->{'simple_repeat'}{'Satellite'} = [{'SAT' => []}, {'MSAT' => []}];
    
    $matches->{'pseudogene'} = [{'rRNA' => []}, {'tRNA' => []}, {'snRNA' => []}];
    
    $matches->{'integrated_virus'} = [{'DNA_Virus' => []}, {'Caulimoviridae' => []}];
    
    return $matches;
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

    perldoc Transposome::Annotation::Typemap


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

1;
