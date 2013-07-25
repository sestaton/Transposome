package TestUtils;

use 5.012;
use Moose;
use File::Temp;
use Cwd;
use namespace::autoclean;

has destroy => (
    is        => 'ro',
    isa       => 'Bool',
    predicate => 'has_destroy',
    default   => 0,
    );

has build_proper => (
    is        => 'ro',
    isa       => 'Bool',
    predicate => 'has_build_proper',
    default   => 0,
    );

has build_problematic => (
    is        => 'ro',
    isa       => 'Bool',
    predicate => 'has_build_problematic',
    default   => 0,
    );

has build_all => (
    is        => 'ro',
    isa       => 'Bool',
    predicate => 'has_build_all',
    default   => 0,
    );

sub fasta_constructor {
    my ($self) = @_;
    if ($self->has_build_all) {
	my $proper_fa = $self->_build_proper_fa_data;
	my $problematic_fa = $self->_build_problematic_fa_data;
	if ($self->has_destroy) {
	    unlink $proper_fa;
	    unlink $problematic_fa;
	}
	else {
	    return [ $proper_fa, $problematic_fa ];
	}
    }
    elsif ($self->has_build_proper) {
	my $proper_fa = $self->_build_proper_fa_data;
	if ($self->has_destroy) {
	    unlink $proper_fa;
	}
	else {
	    return [ $proper_fa ];
	}
    }
    elsif ($self->has_build_problematic) {
	my $problematic_fa = $self->_build_problematic_fa_data;
	if ($self->has_destroy) {
	    unlink $problematic_fa;
	}
	else {
	    return [ $problematic_fa ];
	}
    }
}

sub fastq_constructor {
       my ($self) = @_;
    if ($self->has_build_all) {
	my $proper_fq = $self->_build_proper_fq_data;
	my $problematic_fq = $self->_build_problematic_fq_data;
	if ($self->has_destroy) {
	    unlink $proper_fq;
	    unlink $problematic_fq;
	}
	else {
	    return [ $proper_fq, $problematic_fq ];
	}
    }
    elsif ($self->has_build_proper) {
	my $proper_fq = $self->_build_proper_fq_data;
	if ($self->has_destroy) {
	    unlink $proper_fq;
	}
	else {
	    return [ $proper_fq ];
	}
    }
    elsif ($self->has_build_problematic) {
	my $problematic_fq = $self->_build_problematic_fq_data;
	if ($self->has_destroy) {
	    unlink $problematic_fq;
	}
	else {
	    return [ $problematic_fq ];
	}
    }
}

# private methods
sub _build_proper_fa_data {
    my $cwd = getcwd();
    my $tmpfa = File::Temp->new( TEMPLATE => "transposome_fa_XXXX",
                                 DIR      => $cwd,
                                 SUFFIX   => ".fasta",
                                 UNLINK   => 0 );

    my $tmpfa_name = $tmpfa->filename;
    say $tmpfa '>HWI-ST766:139:D13WEACXX:3:1101:1210:2183 1:N:0:GATCAG';
    say $tmpfa 'CTAGCACTCCTACAAAATTCATCCACCACACAGGCTCACGAAATTGCTCTCTCTCTCTAAACTCTGATTTCTAATTTCAAGTGCTTAACCCTAACCCTAA';
    say $tmpfa '>HWI-ST766:139:D13WEACXX:3:1101:1296:2221 1:N:0:GATCAG';
    say $tmpfa 'GGGTCGGTGATACATAGTACTTCGACCCTGGGTATAAGTGCGGTAGTAATACTCCAATTCAGACAACCCAGGCTGAATTGGAGGCCCATCATAACCCGCA';
    say $tmpfa '>HWI-ST766:139:D13WEACXX:3:1101:1399:2247 1:N:0:GATCAG';
    say $tmpfa 'ATCTATATCTATAAAAGTATTTTTTTTTGTATGATTTATAACCTGATATCTTTTCATGCTTAGACCCATGTTTGGCAAACCTTACCAAGAACGGAAAAAA';

    return $tmpfa_name;
}

sub _build_proper_fq_data {
    my $cwd = getcwd();
    my $tmpfq = File::Temp->new( TEMPLATE => "transposome_fq_XXXX",
                                 DIR      => $cwd,
                                 SUFFIX   => ".fastq",
                                 UNLINK   => 0 );

    my $tmpfq_name = $tmpfq->filename;
    
    say $tmpfq '@HWI-ST766:139:D13WEACXX:3:1101:1210:2183 1:N:0:GATCAG';
    say $tmpfq 'CTAGCACTCCTACAAAATTCATCCACCACACAGGCTCACGAAATTGCTCTCTCTCTCTAAACTCTGATTTCTAATTTCAAGTGCTTAACCCTAACCCTAA';
    say $tmpfq '+';
    say $tmpfq '@?@ADFFDHHHHFHIIIBH>DHIHHIGIEGAHIGEFHIIHGHGEHEBGII@EHIIIIGGHIHGEGIFCCC3?CHCE?CBCD;BCACCAC@?;=A=?A9?9';
    say $tmpfq '@HWI-ST766:139:D13WEACXX:3:1101:1296:2221 1:N:0:GATCAG';
    say $tmpfq 'GGGTCGGTGATACATAGTACTTCGACCCTGGGTATAAGTGCGGTAGTAATACTCCAATTCAGACAACCCAGGCTGAATTGGAGGCCCATCATAACCCGCA';
    say $tmpfq '+';
    say $tmpfq '@@@DDADDFHBFFI>A>CHC@4CGHC<F9FGG0??DG?BDDHGGGBEDCG>GGGBGG:CEHEEA@DEB>ABAA=A5>>>C<A9188??99::@>@C<5<B';
    say $tmpfq '@HWI-ST766:139:D13WEACXX:3:1101:1399:2247 1:N:0:GATCAG';
    say $tmpfq 'ATCTATATCTATAAAAGTATTTTTTTTTGTATGATTTATAACCTGATATCTTTTCATGCTTAGACCCATGTTTGGCAAACCTTACCAAGAACGGAAAAAA';
    say $tmpfq '+';
    say $tmpfq '@C@DFF8DHHFGFGIII?FIIIIIIIIIE?FGGGCHGGGCHIIIIIGIFIIIIIIIIGIIIIHHGFFFFD;BDED@ACDDBCDCDDCCBACCD@?B>A89';

    return $tmpfq_name;
}

sub _build_problematic_fa_data {
    my $cwd = getcwd();
    my $tmpfa = File::Temp->new( TEMPLATE => "transposome_fa_XXXX",
                                 DIR      => $cwd,
                                 SUFFIX   => ".fasta",
                                 UNLINK   => 0 );

    my $tmpfa_name = $tmpfa->filename;
    
    say $tmpfa '>HWI-ST766:139:D13WEACXX:3:1101:1210:2183 1:N:0:GATCAG';
    say $tmpfa 'CTAGCACTCCTACAAAATTCATCCACCACACAGGCTCACGAAATTGCTCTCTCTCTCTAAACTCTGATTTCTAATTTCAAGTGCTTAACCCTAACCCTAA';
    say $tmpfa 'HWI-ST766:139:D13WEACXX:3:1101:1296:2221 1:N:0:GATCAG';
    say $tmpfa 'GGGTCGGTGATACATAGTACTTCGACCCTGGGTATAAGTGCGGTAGTAATACTCCAATTCAGACAACCCAGGCTGAATTGGAGGCCCATCATAACCCGCA';
    say $tmpfa '>HWI-ST766:139:D13WEACXX:3:1101:1399:2247 1:N:0:GATCAG';
    say $tmpfa 'ATCTATATCTATAAAAGTATTTTTTTTTGTATGATTTATAACCTGATATCTTTTCATGCTTAGACCCATGTTTGGCAAACCTTACCAAGAACGGAAAAAA';

    return $tmpfa_name;
}

sub _build_problematic_fq_data {
    my $cwd = getcwd();
    my $tmpfq = File::Temp->new( TEMPLATE => "transposome_fq_XXXX",
                                 DIR      => $cwd,
                                 SUFFIX   => ".fastq",
                                 UNLINK   => 0 );

    my $tmpfq_name = $tmpfq->filename;

    say $tmpfq '@HWI-ST766:139:D13WEACXX:3:1101:1210:2183 1:N:0:GATCAG';
    say $tmpfq 'CTAGCACTCCTACAAAATTCATCCACCACACAGGCTCACGAAATTGCTCTCTCTCTCTAAACTCTGATTTCTAATTTCAAGTGCTTAACCCTAACCCTAA';
    say $tmpfq ' ';
    say $tmpfq '@?@ADFFDHHHHFHIIIBH>DHIHHIGIEGAHIGEFHIIHGHGEHEBGII@EHIIIIGGHIHGEGIFCCC3?CHCE?CBCD;BCACCAC@?;=A=?A9?9';
    say $tmpfq '@HWI-ST766:139:D13WEACXX:3:1101:1296:2221 1:N:0:GATCAG';
    say $tmpfq 'GGGTCGGTGATACATAGTACTTCGACCCTGGGTATAAGTGCGGTAGTAATACTCCAATTCAGACAACCCAGGCTGAATTGGAGGCCCATCATAACCCGCA';
    say $tmpfq '+';
    say $tmpfq '@@@DDADDFHBFFI>A>CHC@4CGHC<F9FGG0??DG?BDDHGGGBEDCG>GGGBGG:CEHEEA@DEB>ABAA=A5>>>C<A9188??99::@>@C<5<B';
    say $tmpfq '@HWI-ST766:139:D13WEACXX:3:1101:1399:2247 1:N:0:GATCAG';
    say $tmpfq 'ATCTATATCTATAAAAGTATTTTTTTTTGTATGATTTATAACCTGATATCTTTTCATGCTTAGACCCATGTTTGGCAAACCTTACCAAGAACGGAAAAAA';
    say $tmpfq '+';
    say $tmpfq '@C@DFF8DHHFGFGIII?FIIIIIIIIIE?FGGGCHGGGCHIIIIIGIFIIIIIIIIGIIIIHHGFFFFD;BDED@ACDDBCDCDDCCBACCD@?B>A89';

    return $tmpfq_name;
}

__PACKAGE__->meta->make_immutable;
