package SeqIO;

use 5.012;
use Moose;
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
    if (substr($hline, 0, 1) eq '>' || substr($hline, 0, 1) eq '@') {
	if ($hline =~ /^.?(\S+)\s(\d)\S+/) {      # Illumina 1.8+
	    $name = $1."/".$2;
	    $self->set_id($name);
	}
	elsif ($hline =~ /^.?(\S+)/) {            # Illumina 1.3+
	    $name = $1;
	    $self->set_id($name);
	} else {
	    $name = '';                           # ?
	    $self->set_id($name);
	}
	#say $self->id;
    }
    my $sline = <$fh>;
    return unless defined $sline;
    chomp $sline;
    my $c = substr($sline, 0, 1);
    last if ($c eq '>' || $c eq '@' || $c eq '+');
    $seq .= $sline;
    $self->set_seq($seq);
    #say $self->seq;
    return $self if ($c ne '+');
    
    my $qline = <$fh>;
    chomp $qline;
    return unless defined $qline;
    $qual .= $qline;
    if (length($qual) >= length($seq)) {
	$self->set_qual($qual);
	return $self;
    }
}

__PACKAGE__->meta->make_immutable;

1;
