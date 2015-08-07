use strict;
use warnings;
use File::Spec;
use Capture::Tiny       qw(capture);
use IPC::System::Simple qw(system);
use Transposome::SeqFactory;

use aliased 'Transposome::Test::TestFixture';
use Test::More 'no_plan';

my $test_proper = TestFixture->new( build_proper => 1, destroy => 0 );
my $seq_num = 1;

my $proper_fa_arr = $test_proper->fasta_constructor;
my $proper_fq_arr = $test_proper->fastq_constructor;

# test parsing correctly formatted sequence files
for my $fa ( @$proper_fa_arr ) {
    my $seqio_fa = Transposome::SeqFactory->new( file => $fa )->make_seqio_object;
    while ( my $seq = $seqio_fa->next_seq ) {
        ok( $seq->has_id,  "Fasta sequence $seq_num has an ID" );
        ok( $seq->has_seq, "Fasta sequence $seq_num has a sequence" );
        ok( !$seq->has_qual,
            "Fasta sequence $seq_num does not have quality scores" );
    }
    unlink $fa;
    $seq_num++;
}
$seq_num = 1;

for my $fq (@$proper_fq_arr) {
    my $seqio_fq = Transposome::SeqFactory->new( file => $fq, format => 'fastq' )->make_seqio_object;
    while ( my $seq = $seqio_fq->next_seq ) {
        ok( $seq->has_id,   "Fastq sequence $seq_num has an ID" );
        ok( $seq->has_seq,  "Fastq sequence $seq_num has a sequence" );
        ok( $seq->has_qual, "Fastq sequence $seq_num has quality scores" );
    }
    unlink $fq;
    $seq_num++;
}
$seq_num = 1;

my $fafile = File::Spec->catfile('t', 'test_data', 't_reads.fas.gz');
my $fqfile = File::Spec->catfile('t', 'test_data', 't_reads.fq.gz');

my $seqio_fa1 = Transposome::SeqFactory->new( file => $fafile )->make_seqio_object;
while ( my $seq = $seqio_fa1->next_seq ) {
    ok( $seq->has_id,  "Can read gzipped file - Fasta sequence $seq_num has an ID" );
    ok( $seq->has_seq, "Can read gzipped file - Fasta sequence $seq_num has a sequence" );
    ok( !$seq->has_qual,
	"Can read gzipped file - Fasta sequence $seq_num does not have quality scores" );
}
