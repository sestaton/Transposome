package Readfq;

use 5.012;
use Moose;
use MooseX::Types::Path::Class;
use namespace::autoclean;

requires 'file';

# class attributes
#has 'file' => (
#      is       => 'ro',
#      isa      => 'Path::Class::File',
#      required => 1,
#      coerce   => 1,
#    );


# class methods
sub read_seq {
    my $self = shift;
    if (-e $self->file) {
        my $fh = $self->file->openr;
	my ($name, $seq, $qual, @aux);
	while (($name, $seq, $qual) = _readfq(\*$fh, \@aux)) {
	    $seq =~ s/(.{80})/$1\n/gs;
	    if ($qual) {
		$qual =~ s/(.{80})/$1\n/gs;
		say join "\n", "@".$name, $seq, "+", $qual;
	    }
	    else {
		say join "\n", ">".$name, $seq;
	    }
	}
    }
}

sub _readfq {
    my ($fh, $aux) = @_;
    @$aux = [undef, 0] if (!@$aux);
    return if ($aux->[1]);
    if (!defined($aux->[0])) {
        while (<$fh>) {
            chomp;
            if (substr($_, 0, 1) eq '>' || substr($_, 0, 1) eq '@') {
                $aux->[0] = $_;
                last;
            }
        }
        if (!defined($aux->[0])) {
            $aux->[1] = 1;
            return;
        }
    }
    my $name;
    if (/^.?(\S+)\s(\d)\S+/) {      # Illumina 1.8+
	$name = $1."/".$2;
    }
    elsif (/^.?(\S+)/) {            # Illumina 1.3+
	$name = $1;
    } else {
	$name = '';                 # ?
    }
    #my $name = /^.(\S+)/? $1 : ''; # Heng Li's original regex
    my $seq = '';
    my $c;
    $aux->[0] = undef;
    while (<$fh>) {
        chomp;
        $c = substr($_, 0, 1);
        last if ($c eq '>' || $c eq '@' || $c eq '+');
        $seq .= $_;
    }
    $aux->[0] = $_;
    $aux->[1] = 1 if (!defined($aux->[0]));
    return ($name, $seq) if ($c ne '+');
    my $qual = '';
    while (<$fh>) {
        chomp;
        $qual .= $_;
        if (length($qual) >= length($seq)) {
            $aux->[0] = undef;
            return ($name, $seq, $qual);
        }
    }
    $aux->[1] = 1;
    return ($name, $seq);
}

# make immutable
__PACKAGE__->meta->make_immutable;
