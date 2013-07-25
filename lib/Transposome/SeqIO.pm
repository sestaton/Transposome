package SeqIO_n;

use 5.012;
use Moose;
use Try::Tiny;
use Carp;
use namespace::autoclean;

with 'File';

# class attributes
has id => (
    is        => 'rw',
    isa       => 'Str',
    reader    => 'get_id',
    writer    => 'set_id',
    #clearer   => 'clear_id',
    predicate => 'has_id',
    );

has seq => (
    is        => 'rw',
    isa       => 'Str',
    reader    => 'get_seq',
    writer    => 'set_seq',
    #clearer   => 'clear_seq',
    predicate => 'has_seq',
    );

has qual => (
    is        => 'rw',
    lazy      => 1,
    default   => undef,
    reader    => 'get_qual',
    writer    => 'set_qual',
    #clearer   => 'clear_qual',
    predicate => 'has_qual',
    );

# class methods
sub next_seq {
    my $self = shift;
    my $fh = shift;

    my ($name, $seq, $qual, @aux);
    my $hline = <$fh>;
    return unless defined $hline;
    chomp $hline;
    try {
	die unless (substr($hline, 0, 1) eq '>' || substr($hline, 0, 1) eq '@');
    }
    catch {
	say "\nERROR: '$hline' does not look like Fasta or Fastq.\nHere is the exception: $_\n";
	exit(1);
    };
    if (substr($hline, 0, 1) eq '>') {
	my $name = _set_id_per_encoding($hline);
	$self->set_id($name);

	my $sline = <$fh>;
	return unless defined $sline;
	chomp $sline;
	try {
	    die if !length($sline);
	}
	catch {
	    say "\nERROR: No sequence for Fasta record '$name'.\nHere is the exception: $_\n";
	    exit(1);
	};
	$seq .= $sline;
        $self->set_seq($seq);

	return $self;
    }
    elsif (substr($hline, 0, 1) eq '@') {
	my $name = _set_id_per_encoding($hline);
	$self->set_id($name);

        my $sline = <$fh>;
        return unless defined $sline;
        chomp $sline;
	try {
	    die if !length($sline);
	}
	catch {
	    say "\nERROR: No sequence for Fastq record '$name'.\nHere is the exception: $_\n";
	    exit(1);
	};
	$seq .= $sline;
        $self->set_seq($seq);

	my $cline = <$fh>;
	return unless defined $cline;
	chomp $cline;
	try {
	    die unless length($cline) && substr($cline, 0, 1) eq '+';
	}
	catch {
	    say "\nERROR: No comment line for Fastq record '$name'.\nHere is the exception: $_\n";
	    exit(1);
	};

	my $qline = <$fh>;
	return unless defined $qline;
	chomp $qline;
	try {
	    die if !length($qline);
	}
	catch {
	    say "\nERROR: No quality scores for '$name'.\nHere is the exception: $_\n"; 
	    exit(1);
	};
	$qual .= $qline;
	try {
	    die unless length($qual) >= length($seq);
	}
	catch {
	    say "\nERROR: Unequal number of quality and scores and bases for '$name'.\nHere is the exception: $_\n";
	    exit(1);
	};
	$self->set_qual($qual);
	return $self;
    }
}

sub _set_id_per_encoding {
    my $hline = shift;
    if ($hline =~ /^.?(\S+)\s(\d)\S+/) {
	return $1."/".$2;
    }
    elsif ($hline =~ /^.?(\S+)/) {
	return $1;
    }
    else {
	return '';
    }
}

__PACKAGE__->meta->make_immutable;

1;
