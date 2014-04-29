package TestUtils;

use 5.012;
use Moose;
use MooseX::Types::Path::Class;
use Method::Signatures;
use File::Temp;
use namespace::autoclean;

with 'TestUtils::TestConfig';

=head1 NAME

TestUtils - Methods for mocking data or data structures for testing Transposome.

=head1 VERSION

Version 0.06.1

=cut

our $VERSION = '0.06.1';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    use TestUtils;

    my $test = TestUtils->new( build_all => 1, destroy => 0 );
    my $fa_arr = $test->fasta_constructor;

=cut

has 'destroy' => (
    traits  => ['Bool'],
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has 'build_proper' => (
    traits  => ['Bool'],
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has 'build_problematic' => (
    traits  => ['Bool'],
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has 'build_all' => (
    traits  => ['Bool'],
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

=head2 fasta_constructor

 Title   : fasta_constructor

 Usage   : my $test = TestUtils->new( build_all => 1, destroy => 0 );                                                                                                         
           my $fa_arr = $test->fasta_constructor; 
           
 Function: Create temporary sequence files for testing Transposome.

                                                                            Return_type
 Returns : An array of sequences.                                           ArrayRef
           
 Args    : None. This is a class method called on TestUtils object.

=cut

method fasta_constructor {
    if ( $self->build_all ) {
        my $proper_fa      = $self->_build_proper_fa_data;
        my $problematic_fa = $self->_build_problematic_fa_data;
        if ( $self->destroy ) {
            unlink $proper_fa;
            unlink $problematic_fa;
        }
        else {
            return [ $proper_fa, $problematic_fa ];
        }
    }
    elsif ( $self->build_proper ) {
        my $proper_fa = $self->_build_proper_fa_data;
        if ( $self->destroy ) {
            unlink $proper_fa;
        }
        else {
            return [$proper_fa];
        }
    }
    elsif ( $self->build_problematic ) {
        my $problematic_fa = $self->_build_problematic_fa_data;
        if ( $self->destroy ) {
            unlink $problematic_fa;
        }
        else {
            return [$problematic_fa];
        }
    }
}

=head2 fastq_constructor

 Title   : fastq_constructor

 Usage   : my $test = TestUtils->new( build_all => 1, destroy => 0 );                                                                                                         
           my $fq_arr = $test->fastq_constructor; 
           
 Function: Create temporary sequence files for testing Transposome.

                                                                            Return_type
 Returns : An array of sequences.                                           ArrayRef
           
 Args    : None. This is a class method called on TestUtils object.

=cut

method fastq_constructor {
    if ( $self->build_all ) {
        my $proper_fq      = $self->_build_proper_fq_data;
        my $problematic_fq = $self->_build_problematic_fq_data;
        if ( $self->destroy ) {
            unlink $proper_fq;
            unlink $problematic_fq;
        }
        else {
            return [ $proper_fq, $problematic_fq ];
        }
    }
    elsif ( $self->build_proper ) {
        my $proper_fq = $self->_build_proper_fq_data;
        if ( $self->destroy ) {
            unlink $proper_fq;
        }
        else {
            return [$proper_fq];
        }
    }
    elsif ( $self->build_problematic ) {
        my $problematic_fq = $self->_build_problematic_fq_data;
        if ( $self->destroy ) {
            unlink $problematic_fq;
        }
        else {
            return [$problematic_fq];
        }
    }
}

=head2 blast_constructor

 Title   : blast_constructor

 Usage   : my $test = TestUtils->new( build_proper => 1, destroy => 0 );                                                                                                         
           my $bl_arr = $test->blast_constructor; 
           
 Function: Create temporary blast files for testing Transposome.

                                                                            Return_type
 Returns : An array containing a single blast file.                         ArrayRef
           
 Args    : None. This is a class method called on TestUtils object.

=cut

method blast_constructor {
    if ( $self->build_proper ) {
        my $proper_bl = $self->_build_blast_data;
        if ( $self->destroy ) {
            unlink $proper_bl;
        }
        else {
            return [$proper_bl];
        }
    }
}

=head2 _build_proper_fa_data

 Title   : _build_proper_fa_data

 Usage   : This is a private method, don't use it directly.
           
 Function: Create properly formatted Fasta data for testing Transposome.

                                                                            Return_type
 Returns : A properly formatted Fasta file.                                 Scalar

                                                                            Arg_type
 Args    : None. This is a method called on a TestUtils object.

=cut

method _build_proper_fa_data {
    my $tmpfa = File::Temp->new(
        TEMPLATE => "transposome_fa_XXXX",
        DIR      => 't',
        SUFFIX   => ".fasta",
        UNLINK   => 0
    );

    my $tmpfa_name = $tmpfa->filename;

    say $tmpfa '>HWI-ST766:139:D13WEACXX:3:1101:1210:2183 1:N:0:GATCAG';
    say $tmpfa
      'CTAGCACTCCTACAAAATTCATCCACCACACAGGCTCACGAAATTGCTCTCTCTCTCTAAACTCTGATTTCTAATTTCAAGTGCTTAACCCTAACCCTAA';
    say $tmpfa '>HWI-ST766:139:D13WEACXX:3:1101:1296:2221 1:N:0:GATCAG';
    say $tmpfa
      'GGGTCGGTGATACATAGTACTTCGACCCTGGGTATAAGTGCGGTAGTAATACTCCAATTCAGACAACCCAGGCTGAATTGGAGGCCCATCATAACCCGCA';
    say $tmpfa '>HWI-ST766:139:D13WEACXX:3:1101:1399:2247 1:N:0:GATCAG';
    say $tmpfa
      'ATCTATATCTATAAAAGTATTTTTTTTTGTATGATTTATAACCTGATATCTTTTCATGCTTAGACCCATGTTTGGCAAACCTTACCAAGAACGGAAAAAA';
    say $tmpfa '>HWI-ST765:123:D0TEDACXX:5:1101:2872:2088/1';
    say $tmpfa
      'TTGTCTTCCAGATAATTCCGCTATGTTCAACAAATATGTTAGATTCAAGTTTTTCTTGATAAACCTATTTAAAACCATGA';
    say $tmpfa
      'AACTGATTCAATCGATTCAATATTGTGTTATAAAGTTTATTTCTATTTCCGTTGCAACTTAAATCTGATTTACATTCATT';
    say $tmpfa
      'TTACTTAAACAAACACAATCAAAAGAAACTCAGATCCTACAAGGGGTTTGAATTGGAATTGAACAAACTCGTGGGACCCC';
    say $tmpfa
      'TAGACTGACCGGCTATATACTCAACCTGCTCTAAAGTAAGTGTGGGACACTCGAGCGTGTCGTAAAGAAGACGGTGACTG';
    say $tmpfa
      'AGTGCAATGATTTGTTCGAGAGTTTTGCACATTCTGATATGGACTACAGCACTGCCAGCAGGACTTCCATTCCTGTTACT';
    say $tmpfa
      'ACCACGTTCGTTAATTTAGTTAATTTAATTTAATTGCAAATTTTGGATTTTTAGAAACTCTCCCTCTCAAACATAAAAAA';
    say $tmpfa
      'TAGTTAGTGTCGCATCAGTGTCAGTTCAATTAAGTCCAAATAAAGTAATCAATGCAATTGCCAAAGAGTCCGCGGCAACG';
    say $tmpfa
      'GCGCCAAAAAACTTGATGTGCTAAAAGTAGTTTAATAAAACAACTAGCGTGTTGGGCTGACGCCAACCAAATGACGGTGG';
    say $tmpfa
      'TTAGGATGGCGGTCAGGTCCTCGACGTTAGCCAATGTGGGCCACCATGTCTCATTGCGAAGTTCAGCGTTGATTATGTTC';
    say $tmpfa
      'TCATGCATACAGGGGTATGGCGATCCCGGACCCAAGTCAGCGACATGGACTCAAGCTTTTAATCGAAGACTACCCGTACG';
    say $tmpfa 'CTTCTGAC';
    say $tmpfa '>HWI-ST765:123:D0TEDACXX:5:1101:11717:2411/1';
    say $tmpfa
      'ACACAATGTGCAAGCCAATTAGAAGCCAACTGGACAGCACTGAAGGCTTGGAAAAGTGGCTATAAAAGTTACATAAATAA';
    say $tmpfa
      'AGAAGATGTTTTATTTCAAATTATATTGGAATAAATCCAAGTTTCTTATTACACACTTGCATTTAGGGGTAAACCCTAAT';
    say $tmpfa 'TATTTGAAATAAAACATCTTCTTTATTTATGTAACTTTTATA';
    say $tmpfa '>HWI-ST765:123:D0TEDACXX:5:1101:16191:2473/1';
    say $tmpfa
      'TTTTATCATCTTCCTCTTAGTTTGTTCTCTCTATTTATTCGTGTCCCTTTTTTTTATTTATTGTATTAGCAAACTAAATA';
    say $tmpfa
      'TCTATATCTAAAATATGGTTAGGTTAATTGGCGTTTATGGTTATTTCGGTTTTTGTGTTTTTTGATAAAAATATGGTTGT';
    say $tmpfa
      'ATTCTTGTATATAGTTTATTGATGTTTCGATAAATAAAACCTCCATCCCCTCTCATCTATCCAAAGCCAACCGTATAATC';
    say $tmpfa
      'ATGGAACTTGAGAAACAACGCATTCGAGCAAAATATCTCAACAAGAAGTCTATGTTTATGTTTTCCCTTTTATTTATTTT';
    say $tmpfa
      'GTTTTTATGAACTTTTGTGATATTGTTGATCACTAGCAGTGGTGTAGCATTGGTGCTATTTGGTACGGTTTACCCTGCAC';
    say $tmpfa
      'GCGGCATTTGCGGTACTTCACACTAGCATGATGATGAAGGGTGCAATCGTTGCACAAGGGTGCAGTTCCGTTGTATGGCT';
    say $tmpfa 'TTCTAGCAGGGGGTTGAGTTGGTTG';

    return $tmpfa_name;
}

=head2 _build_proper_fq_data

 Title   : _build_proper_fq_data

 Usage   : This is a private method, don't use it directly.
           
 Function: Create properly formatted Fastq data for testing Transposome.

                                                                            Return_type
 Returns : A properly formatted Fastq file.                                 Scalar

                                                                            Arg_type
 Args    : None. This is a method called on a TestUtils object.

=cut

method _build_proper_fq_data {
    my $tmpfq = File::Temp->new(
        TEMPLATE => "transposome_fq_XXXX",
        DIR      => 't',
        SUFFIX   => ".fastq",
        UNLINK   => 0
    );

    my $tmpfq_name = $tmpfq->filename;

    say $tmpfq '@HWI-ST766:139:D13WEACXX:3:1101:1210:2183 1:N:0:GATCAG';
    say $tmpfq
      'CTAGCACTCCTACAAAATTCATCCACCACACAGGCTCACGAAATTGCTCTCTCTCTCTAAACTCTGATTTCTAATTTCAAGTGCTTAACCCTAACCCTAA';
    say $tmpfq '+';
    say $tmpfq
      '@?@ADFFDHHHHFHIIIBH>DHIHHIGIEGAHIGEFHIIHGHGEHEBGII@EHIIIIGGHIHGEGIFCCC3?CHCE?CBCD;BCACCAC@?;=A=?A9?9';
    say $tmpfq '@HWI-ST766:139:D13WEACXX:3:1101:1296:2221 1:N:0:GATCAG';
    say $tmpfq
      'GGGTCGGTGATACATAGTACTTCGACCCTGGGTATAAGTGCGGTAGTAATACTCCAATTCAGACAACCCAGGCTGAATTGGAGGCCCATCATAACCCGCA';
    say $tmpfq '+';
    say $tmpfq
      '@@@DDADDFHBFFI>A>CHC@4CGHC<F9FGG0??DG?BDDHGGGBEDCG>GGGBGG:CEHEEA@DEB>ABAA=A5>>>C<A9188??99::@>@C<5<B';
    say $tmpfq '@HWI-ST766:139:D13WEACXX:3:1101:1399:2247 1:N:0:GATCAG';
    say $tmpfq
      'ATCTATATCTATAAAAGTATTTTTTTTTGTATGATTTATAACCTGATATCTTTTCATGCTTAGACCCATGTTTGGCAAACCTTACCAAGAACGGAAAAAA';
    say $tmpfq '+';
    say $tmpfq
      '@C@DFF8DHHFGFGIII?FIIIIIIIIIE?FGGGCHGGGCHIIIIIGIFIIIIIIIIGIIIIHHGFFFFD;BDED@ACDDBCDCDDCCBACCD@?B>A89';
    say $tmpfq '@HWI-ST765:123:D0TEDACXX:5:1101:11717:2411/1';
    say $tmpfq
      'ACAATGAAACTTAACATTAGCAAAGATATTATTTATCTTGTGCACAAATACCGCACAATACAGACGTAAATTACTATTAG';
    say $tmpfq
      'ATTTGTAGATTTGATTGGGGTACAATGAAACTTAACATTAGCAAAGATATTATTTATCTTGTGCACAAATACCGCACAAT';
    say $tmpfq
      'ACAGACGTAAATTACTATTAGATTTGTAGATTTGATTGGGGTACAATGAAACTTAACATTAGCAAAGATATTATTTATCT';
    say $tmpfq 'TGTGCACAAATACCGCACAATACAGACGTAAATTACTATTAGATTTGTAGATTTGATTGGG';
    say $tmpfq '+';
    say $tmpfq
      'd\ddcdaddTdddYa``aLc`dcdcd\dccaaddUa^a\\^c``c^cSa^b\cK`^^_ccbLcYYb_]``RUYBXZIQ]B';
    say $tmpfq
      '[Y^T^]WL\V\\_BBaa`L^^d\ddcdaddTdddYa``aLc`dcdcd\dccaaddUa^a\\^c``c^cSa^b\cK`^^_c';
    say $tmpfq
      'cbLcYYb_]``RUYBXZIQ]B[Y^T^]WL\V\\_BBaa`L^^d\ddcdaddTdddYa``aLc`dcdcd\dccaaddUa^a';
    say $tmpfq
      '\\^c``c^cSa^b\cK`^^_ccbLcYYb_]``RUYBXZIQ]B[Y^T^]WL\V\\_BBaa`L^^^^^^';
    say $tmpfq '@HWI-ST765:123:D0TEDACXX:5:1101:11717:2411/2';
    say $tmpfq
      'GAAACTGTTTTAGCAAATAACTTAACTTGAATATTTTTCACACATATTTCTAGCACACTACCTCACTTAACTAATTTGAT';
    say $tmpfq 'CACTTACTTACTTCGGTAATT';
    say $tmpfq '+';
    say $tmpfq
      'eeeedff`ecd[abdaaca^_ddd`add^abbbdddc_]b\b\b^dddadaXYbbaT`aabbdJY\b_\\K^^K^SaVIW';
    say $tmpfq '_```Y]L^ZZK]]TM_\RMZbe';
    say $tmpfq '@HWI-ST765:123:D0TEDACXX:5:1101:11717:2413/1';
    say $tmpfq
      'CTTTTGTGATTTTGAGCTCATTTCATCCTGAAAATACAAAAGGAAGACAAAAACACTATTTTTCCAACATTAGTACTTAA';
    say $tmpfq
      'AAAGGGTTAGTTTTATGCCTTCTTTTGTGATTTTGAGCTCATTTCATCCTGAAAATACAAAAGGAAGACAAAAACACTAT';
    say $tmpfq
      'TTTTCCAACATTAGTACTTAAAAAGGGTTAGTTTTATGCCTTCTTTTGTGATTTTGAGCTCATTTCATCCTGAAAATACA';
    say $tmpfq
      'AAAGGAAGACAAAAACACTATTTTTCCAACATTAGTACTTAAAAAGGGTTAGTTTTATGCCTTCTTTTGTGATTTTGAGC';
    say $tmpfq
      'TCATTTCATCCTGAAAATACAAAAGGAAGACAAAAACACTATTTTTCCAACATTAGTACTTAAAAAGGGTTAGTTTTATG';
    say $tmpfq
      'CCTTCTTTTGTGATTTTGAGCTCATTTCATCCTGAAAATACAAAAGGAAGACAAAAACACTATTTTTCCAACATTAGTAC';
    say $tmpfq
      'TTAAAAAGGGTTAGTTTTATGCCTTCTTTTGTGATTTTGAGCTCATTTCATCCTGAAAATACAAAAGGAAGACAAAAACA';
    say $tmpfq 'CTATTTTTCCAACATTAGTACTTAAAAAGGGTTAGTTTTATGCCTT';
    say $tmpfq '+';
    say $tmpfq
      'fd^fcff]cdffffaceeebddd`aad\`^ececadY`ddLbY\`^`K`b^c_IQLYa`addbbbbbY_cbYb_TU]\_]';
    say $tmpfq
      'IYW]^bY`LY]ba`R`J`]^Yfd^fcff]cdffffaceeebddd`aad\`^ececadY`ddLbY\`^`K`b^c_IQLYa`';
    say $tmpfq
      'addbbbbbY_cbYb_TU]\_]IYW]^bY`LY]ba`R`J`]^Yfd^fcff]cdffffaceeebddd`aad\`^ececadY`';
    say $tmpfq
      'ddLbY\`^`K`b^c_IQLYa`addbbbbbY_cbYb_TU]\_]IYW]^bY`LY]ba`R`J`]^Yfd^fcff]cdfffface';
    say $tmpfq
      'eebddd`aad\`^ececadY`ddLbY\`^`K`b^c_IQLYa`addbbbbbY_cbYb_TU]\_]IYW]^bY`LY]ba`R`J';
    say $tmpfq
      '`]^Yfd^fcff]cdffffaceeebddd`aad\`^ececadY`ddLbY\`^`K`b^c_IQLYa`addbbbbbY_cbYb_TU';
    say $tmpfq
      ']\_]IYW]^bY`LY]ba`R`J`]^Yfd^fcff]cdffffaceeebddd`aad\`^ececadY`ddLbY\`^`K`b^c_IQ';
    say $tmpfq 'LYa`addbbbbbY_cbYb_TU]\_]IYW]^bY`LY]ba`R`J`]^Y';

    return $tmpfq_name;
}

=head2 _build_problematic_fa_data

 Title   : _build_problematic_fa_data

 Usage   : This is a private method, don't use it directly.
           
 Function: Create improperly formatted Fasta data for testing Transposome.

                                                                            Return_type
 Returns : An improperly formatted Fasta file.                              Scalar

                                                                            Arg_type
 Args    : None. This is a method called on a TestUtils object.

=cut

method _build_problematic_fa_data {
    my $tmpfa = File::Temp->new(
        TEMPLATE => "transposome_fa_XXXX",
        DIR      => 't',
        SUFFIX   => ".fasta",
        UNLINK   => 0
    );

    my $tmpfa_name = $tmpfa->filename;

    say $tmpfa '>HWI-ST766:139:D13WEACXX:3:1101:1210:2183 1:N:0:GATCAG';
    say $tmpfa
      'CTAGCACTCCTACAAAATTCATCCACCACACAGGCTCACGAAATTGCTCTCTCTCTCTAAACTCTGATTTCTAATTTCAAGTGCTTAACCCTAACCCTAA';
    say $tmpfa 'HWI-ST766:139:D13WEACXX:3:1101:1296:2221 1:N:0:GATCAG';
    say $tmpfa
      'GGGTCGGTGATACATAGTACTTCGACCCTGGGTATAAGTGCGGTAGTAATACTCCAATTCAGACAACCCAGGCTGAATTGGAGGCCCATCATAACCCGCA';
    say $tmpfa '>HWI-ST766:139:D13WEACXX:3:1101:1399:2247 1:N:0:GATCAG';
    say $tmpfa
      'ATCTATATCTATAAAAGTATTTTTTTTTGTATGATTTATAACCTGATATCTTTTCATGCTTAGACCCATGTTTGGCAAACCTTACCAAGAACGGAAAAAA';

    return $tmpfa_name;
}

=head2 _build_problematic_fq_data

Title   : _build_problematic_fq_data

 Usage   : This is a private method, don't use it directly.
           
 Function: Create improperly formatted Fastq data for testing Transposome.

                                                                            Return_type
 Returns : A improperly formatted Fastq file.                               Scalar

                                                                            Arg_type
 Args    : None. This is a method called on a TestUtils object.

=cut

method _build_problematic_fq_data {
    my $tmpfq = File::Temp->new(
        TEMPLATE => "transposome_fq_XXXX",
        DIR      => 't',
        SUFFIX   => ".fastq",
        UNLINK   => 0
    );

    my $tmpfq_name = $tmpfq->filename;

    say $tmpfq '@HWI-ST766:139:D13WEACXX:3:1101:1210:2183 1:N:0:GATCAG';
    say $tmpfq
      'CTAGCACTCCTACAAAATTCATCCACCACACAGGCTCACGAAATTGCTCTCTCTCTCTAAACTCTGATTTCTAATTTCAAGTGCTTAACCCTAACCCTAA';
    say $tmpfq ' ';
    say $tmpfq
      '@?@ADFFDHHHHFHIIIBH>DHIHHIGIEGAHIGEFHIIHGHGEHEBGII@EHIIIIGGHIHGEGIFCCC3?CHCE?CBCD;BCACCAC@?;=A=?A9?9';
    say $tmpfq '@HWI-ST766:139:D13WEACXX:3:1101:1296:2221 1:N:0:GATCAG';
    say $tmpfq
      'GGGTCGGTGATACATAGTACTTCGACCCTGGGTATAAGTGCGGTAGTAATACTCCAATTCAGACAACCCAGGCTGAATTGGAGGCCCATCATAACCCGCA';
    say $tmpfq '+';
    say $tmpfq
      '@@@DDADDFHBFFI>A>CHC@4CGHC<F9FGG0??DG?BDDHGGGBEDCG>GGGBGG:CEHEEA@DEB>ABAA=A5>>>C<A9188??99::@>@C<5<B';
    say $tmpfq '@HWI-ST766:139:D13WEACXX:3:1101:1399:2247 1:N:0:GATCAG';
    say $tmpfq
      'ATCTATATCTATAAAAGTATTTTTTTTTGTATGATTTATAACCTGATATCTTTTCATGCTTAGACCCATGTTTGGCAAACCTTACCAAGAACGGAAAAAA';
    say $tmpfq '+';
    say $tmpfq
      '@C@DFF8DHHFGFGIII?FIIIIIIIIIE?FGGGCHGGGCHIIIIIGIFIIIIIIIIGIIIIHHGFFFFD;BDED@ACDDBCDCDDCCBACCD@?B>A89';

    return $tmpfq_name;
}

=head2 _build_blast_data

 Title   : _build_blast_data

 Usage   : This is a private method, don't use it directly.
           
 Function: Create properly formatted mgblast data for testing Transposome.

                                                                            Return_type
 Returns : A properly formatted mgblast file in "-D 4" format.              Scalar

                                                                            Arg_type
 Args    : None. This is a method called on a TestUtils object.

=cut

method _build_blast_data {
    my $tmpbl = File::Temp->new(
        TEMPLATE => "transposome_mgblast_XXXX",
        DIR      => 't',
        SUFFIX   => ".bln",
        UNLINK   => 0
    );

    my $tmpbl_name = $tmpbl->filename;

    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:17438:115036/1\t101\t44\t101\tHWI-ST765:123:D0TEDACXX:5:1101:12043:4285/1\t101\t2\t59\t98.28\t222\t1e-23\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:1551:114654/2\t101\t48\t101\tHWI-ST765:123:D0TEDACXX:5:1101:11359:5882/1\t101\t1\t54\t100.00\t215\t1e-23\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:13484:117932/1\t101\t97\t32\tHWI-ST765:123:D0TEDACXX:5:1101:11359:5882/1\t101\t33\t98\t86.76\t180\t2e-09\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:13484:117932/1\t101\t51\t1\tHWI-ST765:123:D0TEDACXX:5:1101:8358:7944/1\t101\t17\t68\t90.38\t147\t5e-10\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:13484:117932/2\t101\t98\t24\tHWI-ST765:123:D0TEDACXX:5:1101:16013:10464/2\t101\t27\t101\t98.67\t288\t7e-34\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:15810:122811/1\t101\t95\t12\tHWI-ST765:123:D0TEDACXX:5:1101:13502:12176/1\t101\t18\t101\t85.71\t233\t6e-13\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:7754:116900/2\t101\t82\t33\tHWI-ST765:123:D0TEDACXX:5:1101:8007:12894/1\t101\t48\t97\t88.00\t129\t5e-07\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:9317:126753/1\t101\t24\t100\tHWI-ST765:123:D0TEDACXX:5:1101:8319:12929/1\t101\t1\t77\t92.21\t258\t4e-23\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:8859:117217/2\t101\t3\t101\tHWI-ST765:123:D0TEDACXX:5:1101:18255:14859/1\t101\t1\t99\t94.95\t355\t1e-38\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:16361:121330/1\t101\t36\t101\tHWI-ST765:123:D0TEDACXX:5:1101:18255:14859/1\t101\t1\t65\t90.91\t211\t6e-16\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:8859:117217/1\t101\t7\t101\tHWI-ST765:123:D0TEDACXX:5:1101:18255:14859/2\t101\t1\t96\t93.75\t331\t7e-34\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:9276:123517/1\t101\t101\t25\tHWI-ST765:123:D0TEDACXX:5:1101:18255:14859/2\t101\t22\t101\t90.00\t245\t6e-19\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:3077:117839/1\t101\t61\t12\tHWI-ST765:123:D0TEDACXX:5:1101:5837:15926/2\t101\t1\t50\t92.00\t156\t9e-12\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:9909:122734/1\t101\t83\t1\tHWI-ST765:123:D0TEDACXX:5:1101:17834:16525/2\t101\t4\t86\t86.90\t238\t9e-15\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:2682:118050/1\t101\t67\t1\tHWI-ST765:123:D0TEDACXX:5:1101:9518:21105/2\t101\t1\t67\t100.00\t267\t2e-31\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:13390:128768/2\t101\t9\t99\tHWI-ST765:123:D0TEDACXX:5:1101:3931:21360/2\t101\t11\t101\t91.30\t289\t1e-26\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:21340:123173/1\t101\t39\t101\tHWI-ST765:123:D0TEDACXX:5:1101:2638:22795/1\t101\t1\t63\t95.24\t227\t6e-22\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:4638:137613/2\t101\t101\t22\tHWI-ST765:123:D0TEDACXX:5:1101:13813:23416/1\t101\t10\t89\t98.75\t299\t8e-37\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:3305:126706/2\t101\t15\t84\tHWI-ST765:123:D0TEDACXX:5:1101:17859:24343/1\t101\t32\t101\t95.71\t241\t4e-26\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:13484:117932/1\t101\t19\t101\tHWI-ST765:123:D0TEDACXX:5:1101:20882:24393/1\t101\t1\t83\t89.41\t255\t2e-19\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:7585:115280/2\t101\t101\t47\tHWI-ST765:123:D0TEDACXX:5:1101:4893:26487/1\t101\t47\t101\t89.47\t167\t5e-10\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:18226:134617/2\t101\t16\t100\tHWI-ST765:123:D0TEDACXX:5:1101:17057:26511/1\t101\t3\t87\t88.37\t254\t2e-18\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:19094:136354/2\t101\t61\t1\tHWI-ST765:123:D0TEDACXX:5:1101:17057:26511/2\t101\t1\t60\t95.08\t215\t4e-20\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:16496:139942/1\t101\t85\t8\tHWI-ST765:123:D0TEDACXX:5:1101:12085:27467/1\t101\t1\t78\t89.87\t238\t6e-19\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:19571:142480/2\t101\t6\t101\tHWI-ST765:123:D0TEDACXX:5:1101:20911:29753/1\t101\t5\t100\t86.46\t275\t9e-18\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:2629:123247/2\t101\t92\t1\tHWI-ST765:123:D0TEDACXX:5:1101:20625:30688/2\t101\t1\t93\t92.47\t311\t1e-29\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:19571:142480/2\t101\t101\t31\tHWI-ST765:123:D0TEDACXX:5:1101:3620:31025/1\t101\t29\t99\t92.96\t241\t6e-22\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:19571:142480/1\t101\t81\t1\tHWI-ST765:123:D0TEDACXX:5:1101:3620:31025/2\t101\t1\t81\t88.89\t251\t2e-18\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:19571:142480/2\t101\t1\t89\tHWI-ST765:123:D0TEDACXX:5:1101:3620:31025/2\t101\t13\t101\t92.13\t299\t7e-28\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:4917:144291/1\t101\t3\t99\tHWI-ST765:123:D0TEDACXX:5:1101:6625:33522/1\t101\t1\t97\t91.75\t321\t3e-30\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:2730:139061/1\t101\t3\t60\tHWI-ST765:123:D0TEDACXX:5:1101:6625:33522/2\t101\t42\t99\t94.83\t203\t6e-19\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:4917:144291/2\t101\t2\t74\tHWI-ST765:123:D0TEDACXX:5:1101:6625:33522/2\t101\t23\t95\t93.15\t244\t4e-23\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:15057:115107/2\t101\t78\t1\tHWI-ST765:123:D0TEDACXX:5:1101:7847:34148/1\t101\t1\t78\t92.31\t263\t1e-23\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:14539:122239/1\t101\t1\t96\tHWI-ST765:123:D0TEDACXX:5:1101:7847:34148/2\t101\t6\t101\t88.66\t293\t2e-22\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:12325:144634/1\t101\t97\t16\tHWI-ST765:123:D0TEDACXX:5:1101:6603:34769/1\t101\t3\t83\t91.57\t248\t4e-23\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:3657:145116/1\t101\t25\t101\tHWI-ST765:123:D0TEDACXX:5:1101:2396:36587/1\t101\t4\t80\t93.51\t264\t2e-25\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:9276:123517/2\t101\t91\t1\tHWI-ST765:123:D0TEDACXX:5:1101:4295:36795/2\t101\t1\t91\t94.51\t323\t7e-34\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:10944:135807/2\t101\t66\t1\tHWI-ST765:123:D0TEDACXX:5:1101:10882:36858/1\t101\t14\t79\t93.94\t218\t2e-21\t-";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:10944:135807/2\t101\t1\t55\tHWI-ST765:123:D0TEDACXX:5:1101:10882:36858/2\t101\t42\t96\t96.36\t198\t2e-19\t+";
    say $tmpbl
      "HWI-ST765:123:D0TEDACXX:5:1302:15710:114878/1\t101\t99\t15\tHWI-ST765:123:D0TEDACXX:5:1101:13409:37402/1\t101\t2\t86\t90.59\t260\t4e-23\t-";

    return $tmpbl_name;
}

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2014 S. Evan Staton

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
