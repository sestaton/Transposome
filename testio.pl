use strict;
use warnings;
use 5.010;
use blib;
use Transposome::SeqFactory;

my $seqio_fa = Transposome::SeqFactory->new( file => shift, format => 'fastq' )->make_seqio_object;
#say STDERR "can? ",$seqio_fa->can->get_seqtype;
while ( my $seq = $seqio_fa->next_seq ) {
    #say STDERR "id ->", $seq->get_id;
    #ok( $seq->has_id,  "Fasta sequence $seq_num has an ID" );
    #ok( $seq->get_id =~ /\/\d$/,  "Fasta sequence $seq_num has an ID in the expected format" );
    #ok( $seq->has_seq, "Fasta sequence $seq_num has a sequence" );
    #ok( !$seq->has_qual,
    #"Fasta sequence $seq_num does not have quality scores" );
    say join "\n", "@".$seq->get_id, $seq->get_seq, '+', $seq->get_qual;
}
