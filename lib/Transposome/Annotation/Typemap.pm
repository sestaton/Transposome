package Transposome::Annotation::Typemap;

use 5.010;
use Moose::Role;
use Storable        qw(freeze);
use List::MoreUtils qw(first_index);
#use Data::Dump::Color;

=head1 NAME

Transposome::Annotation::Typemap - Create a map of repeats to the family level.

=head1 VERSION

Version 0.11.1

=cut

our $VERSION = '0.11.1';
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

sub map_repeat_types {
    my $self = shift;
    my ($infile) = @_;
    open my $in, '<', $infile 
	or die "\n[ERROR]: Could not open file: $infile\n";

    my $matches = $self->_build_repeat_map();
    my $repeats = $self->_map_repeat_taxonomy($matches);
 
    my (%family_map, %type_map, %seen);

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
            push @{$family_map{$sf}}, $f;
        }
    }
    close $in;
 
    for my $mapped_sfam (keys %family_map) {
        my $mapped_sfam_cp = lc($mapped_sfam);
        for my $mapped_fam (@{$family_map{$mapped_sfam}}) {
            for my $class (keys %$repeats) {
                for my $sfamh (@{$repeats->{$class}}) {
                    my $sfam_index = first_index { $_ eq $sfamh } @{$repeats->{$class}};
                    for my $sfamname (keys %$sfamh) {
                        if (lc($sfamname) eq $mapped_sfam_cp) {
                            push @{$repeats->{$class}[$sfam_index]{$sfamname}}, $mapped_fam;
                            $type_map{$mapped_fam} = $class;
                        }
                        elsif ($class eq $mapped_sfam_cp) {
                            my $unk_idx = first_index { $_ eq 'unclassified' } @{$repeats->{$class}};
                            push @{$repeats->{$class}[$unk_idx]{'unclassified'}}, $mapped_fam
                                unless exists $seen{$mapped_fam};
                            $seen{$mapped_fam} = 1;
                            $type_map{$mapped_fam} = $class;
                        }
                    }
                }
            }
        }
    }
    
    my $repeats_ser = freeze $repeats;
    return ($repeats_ser, \%type_map);
}

=head2 _map_repeat_taxonomy

 Title   : _map_repeat_taxomy

 Usage   : This is a private method, do not use it directly.
           
 Function: Retrieve the repeat taxonomy for each TE order. This avoids
           walking the entire structure for every single match look up.

                                                                            Return_type
 Returns : A complex data structure of the repeat taxonomy from order       HashRef
           to the individual element.
            
                                                                            Arg_type
 Args    : The repeat taxonomy map (hash) from the type down to the         HashRef
           individual TE element.

=cut

sub _map_repeat_taxonomy {
    my $self = shift;
    my ($matches) = @_;
    my %repeats;

    for my $type (keys %$matches) { 
        if ($type eq 'transposable_element') { 
            for my $tes (keys %{$matches->{$type}}) {
                if ($tes eq 'dna_transposon') {
                    $repeats{'dna_transposon'} = $matches->{$type}{$tes};
                }
                elsif ($tes eq 'ltr_retrotransposon') {
                    $repeats{'ltr_retrotransposon'} = $matches->{$type}{$tes};
                }
                elsif ($tes eq 'non-ltr_retrotransposon') {
                    $repeats{'non-ltr_retrotransposon'} = $matches->{$type}{$tes};
                }
                elsif ($tes eq 'endogenous_retrovirus') {
                    $repeats{'endogenous_retrovirus'} = $matches->{$type}{$tes};
                }
            }
        }        
	elsif ($type eq 'simple_repeat') { 
            for my $subtype (keys %{$matches->{$type}}) {
                if ($subtype eq 'Satellite') {
                    $repeats{'satellite'} = $matches->{$type}{$subtype};
                }
            }
        }
        elsif ($type eq 'pseudogene') { 
            $repeats{'pseudogene'} = $matches->{$type};
        }
        elsif ($type eq 'integrated_virus') { 
            $repeats{'integrated_virus'} = $matches->{$type};
        }
	elsif ($type eq 'autonomous_replication_sequence') { 
            $repeats{'autonomous_replication_sequence'} = $matches->{$type};
        }
    }
    return \%repeats; 
}

=head2 _build_repeat_map

 Title : _build_repeat_map
 
 Usage   : This is a private method, do not use it directly.
           
 Function: Creates a data structure containing a full taxonomic
           map of repeat types.
                                                                            Return_type
 Returns : A complex data structure containing a mapping of                 HashRef
           repeat types from Class to Family

 Args    : None. This is a class method called on a object
           of the class consuming this role.

=cut 

sub _build_repeat_map {
    my $self = shift;
    my $matches = {};
    
    $matches->{'transposable_element'}{'dna_transposon'} 
        = [{'Tc1/Mariner' => []}, {'hAT' => []}, 
	   {'MuDR' => []}, {'EnSpm' => []}, 
	   {'piggyBac' => []}, {'P' => []}, 
	   {'Merlin' => []}, {'Harbinger' => []},
	   {'Transib' => []}, {'Novosib' => []}, 
	   {'Helitron' => []}, {'Polinton' => []}, 
	   {'Kolobok' => []}, {'ISL2EU' => []}, 
	   {'Crypton' => []}, {'Sola' => []}, 
	   {'Zator' => []}, {'Ginger/1' => []}, 
	   {'Ginger2/TDD' => []}, {'Academ' => []}, 
	   {'Zisupton' => []}, {'IS3EU' => []}, 
	   {'CACTA' => []}, {'Mutator' => []}, 
	   {'PIF/Harbinger' => []}, {'unclassified' => []}];
    
    $matches->{'transposable_element'}{'ltr_retrotransposon'} 
        = [{'Gypsy' => []}, {'Copia' => []}, 
	   {'BEL' => []}, {'DIRS' => []}, {'Unknown_LTR' => []},
	   {'unclassified' => []}];

    $matches->{'transposable_element'}{'endogenous_retrovirus'} 
        = [{'ERV1' => []}, {'ERV2' => []}, 
	   {'ERV3' => []}, {'Lentivirus' => []}, 
	   {'ERV4' => []}, {'unclassified' => []}];
    
    $matches->{'transposable_element'}{'non-ltr_retrotransposon'} 
        = [{'SINE1/7SL' => []}, {'SINE2/tRNA' => []},
	   {'SINE3/5S' => []},{'SINE4' => []},
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
	   {'Vingi' => []}, {'Kiri' => []}, {'unclassified' => []}];

    $matches->{'simple_repeat'}{'Satellite'} 
        = [{'SAT' => []}, {'MSAT' => []}];

    $matches->{'pseudogene'} 
        = [{'rRNA' => []}, {'tRNA' => []}, {'snRNA' => []}];

    $matches->{'integrated_virus'} 
        = [{'DNA_Virus' => []}, {'Caulimoviridae' => []}];

    # This is for D. melanogaster (ARS406) and Triticum aestivum (ARS_TA) ARS sequences.
    # We could annotate other ARS such as Helicase, Primase, RNase H, etc.
    $matches->{'autonomous_replication_sequence'}
        = [{'ARS406' => []}, {'ARS_TA' => []}, ];
    
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

Copyright (C) 2013-2015 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

1;
