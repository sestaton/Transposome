package Transposome::PairFinder;

use 5.012;
use Moose;
use MooseX::Types::Path::Class;
use namespace::autoclean;
use Encode qw(encode decode);
BEGIN {
  @AnyDBM_File::ISA = qw( DB_File SQLite_File )
      unless @AnyDBM_File::ISA == 1;
}
use AnyDBM_File;                  
use vars qw( $DB_BTREE &R_DUP );  
use AnyDBM_File::Importer qw(:bdb);
use DBM::Deep;
use File::Spec;

=head1 NAME

Transposome::PairFinder - 

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use Transposome::PairFinder;

    my $blast_res = Transposome::PairFinder->new( blast_file => 'myblast.bln' );
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 ATTRIBUTES


=cut

has 'file' => (
      is       => 'ro',
      isa      => 'Path::Class::File',
      required => 1,
      coerce   => 1,
    );

=head1 SUBROUTINES/METHODS

=head2 parse_blast()

=cut

sub parse_blast {
    my ($self, $infile, $percent_id, $percent_cov, $outdir, $memory) = @_;

    my ($iname, $ipath, $isuffix) = fileparse($infile, qr/\.[^.]*/);
    unless (-d $outdir) {
	make_path($outdir, {verbose => 0, mode => 0771,});
    }
    my $int_file = $iname;
    my $idx_file = $iname;
    my $hs_file = $iname;
    $int_file .= "_louvain.int";
    $idx_file .= "_louvain.idx";
    $hs_file .= "_louvain.hs";
    my $int_path = File::Spec->catfile($outdir, $int_file);
    my $idx_path = File::Spec->catfile($outdir, $idx_file);
    my $hs_path = File::Spec->catfile($outdir, $hs_file);

    # counters
    my $total_hits = 0;
    my $parsed_hits = 0;
    my $index = 0;

    open my $in, '<', $infile;
    open my $int, '>', $int_path;
    open my $idx, '>', $idx_path;
    open my $hs, '>', $hs_path;

    if (defined $memory) {
	my %match_pairs;
	my %match_index;

	while (<$in>) {
	    chomp;
	    my ($q_name, $q_len, $q_start, $q_end, $s_name, $s_len,
		$s_start, $s_end, $pid, $score, $e_val, $strand) = split;
	    
	    my $pair = mk_key($q_name, $s_name);
	    my $revpair = mk_key($s_name, $q_name);
	    my $subj_hit_length = ($s_end - $s_start) + 1;
	    my $subj_cov = $subj_hit_length/$s_len;

	    if ($q_start > $q_end) {
		$total_hits++;
		my $neg_query_hit_length = ($q_start - $q_end) + 1;
		my $neg_query_cov = $neg_query_hit_length/$q_len;

		if ( ($neg_query_cov >= $percent_cov) && ($pid >= $percent_id) ) {
		    if (exists $match_pairs{$pair}) {
			push @{$match_pairs{$pair}}, $score;
		    }
		    elsif (exists $match_pairs{$revpair}) {
			push @{$match_pairs{$revpair}}, $score;
		    }
		    else {
			$match_pairs{$pair} = [$score];
			$match_index{$q_name} = $index unless exists $match_index{$q_name};
			$index++;
			$match_index{$s_name} = $index unless exists $match_index{$s_name};
			$index++;
		    }
		}
	    }
	    else {
		$total_hits++;
                my $pos_query_hit_length = ($q_end - $q_start) + 1;
                my $pos_query_cov = $pos_query_hit_length/$q_len;

                if ( ($pos_query_cov >= $percent_cov) && ($pid >= $percent_id) ) {
                    if (exists $match_pairs{$pair}) {
                        push @{$match_pairs{$pair}}, $score;
                    }
                    elsif (exists $match_pairs{$revpair}) {
                        push @{$match_pairs{$revpair}}, $score;
                    }
                    else {
                        $match_pairs{$pair} = [$score];
                        $match_index{$q_name} = $index unless exists $match_index{$q_name};
                        $index++;
                        $match_index{$s_name} = $index unless exists $match_index{$s_name};
                        $index++;
                    }
                }
            }
        }
        close $in;

        for my $idx_mem (sort { $match_index{$a} <=> $match_index{$b} } keys %match_index) {
            say $idx join " ", $idx_mem, $match_index{$idx_mem};
        }
        close $idx;

        while (my ($match, $scores) = each %match_pairs) {
            my $match_score = max(@$scores);
            my ($qry, $sbj) = mk_vec($match);
            my $revmatch = mk_key($sbj, $qry);
            if (exists $match_pairs{$revmatch}) {
                my $rev_match_score = max(@{$match_pairs{$revmatch}});
                if ($rev_match_score > $match_score) {
                    if (exists $match_index{$sbj} && exists $match_index{$qry}) {
			say $hs join "\t", $sbj, $qry, $rev_match_score;
                        say $int join "\t", $match_index{$sbj}, $match_index{$qry}, $rev_match_score;
                        delete $match_pairs{$match};
                    }
                }
                else {
                    delete $match_pairs{$revmatch};
                }
	    }
	    else {
		if (exists $match_index{$qry} && exists $match_index{$sbj}) {
		    say $hs join "\t", $qry, $sbj, $match_score;
		    say $int join "\t", $match_index{$qry}, $match_index{$sbj}, $match_score;
		}
	    }
	}
	close $int;
	close $hs;

	return($idx_path, $int_path, $hs_path);
    }
    else {
	my $dbm = "mgblast_matchpairs.dbm";
	my $dbi = "mgblast_matchindex.dbm";
	
	unlink $dbm if -e $dbm;
	unlink $dbi if -e $dbi;
	
	my $db = DBM::Deep->new( file      => $dbm,
				  locking   => 1,
				  autoflush => 1,
				  type      => DBM::Deep::TYPE_HASH
	    );
	
	my %match_index;
	$DB_BTREE->{cachesize} = 100000;
	$DB_BTREE->{flags} = R_DUP;
	
	tie %match_index, 'AnyDBM_File', $dbi, O_RDWR|O_CREAT, 0666, $DB_BTREE
	    or die "\nERROR: Could not open DBM file $dbi: $!\n";

	while (<$in>) {
	    chomp;
	        my ($q_name, $q_len, $q_start, $q_end, $s_name, $s_len,
		    $s_start, $s_end, $pid, $score, $e_val, $strand) = split;

	    my $pair = mk_key($q_name, $s_name);
	    my $revpair = mk_key($s_name, $q_name);
	    my $enc_pair = encode("UTF-8", $pair, 1);
	    my $enc_revpair = encode("UTF-8", $revpair, 1);
	    my $subj_hit_length = ($s_end - $s_start) + 1;
	    my $subj_cov = $subj_hit_length/$s_len;

	    if ($q_start > $q_end) {
		$total_hits++;
		my $neg_query_hit_length = ($q_start - $q_end) + 1;
		my $neg_query_cov = $neg_query_hit_length/$q_len;

		if ( ($neg_query_cov >= $percent_cov) && ($pid >= $percent_id) ) {
		    if (exists $db->{$enc_pair}) {
			push @{$db->{$enc_pair}}, $score;
		    }
		    elsif (exists $db->{$enc_revpair}) {
			push @{$db->{$enc_revpair}}, $score;
		    }
		    else {
			$db->{$enc_pair} = [$score];
			$match_index{$q_name} = $index unless exists $match_index{$q_name};
			$index++;
			$match_index{$s_name} = $index unless exists $match_index{$s_name};
			$index++;
		    }
		}
	    }
	    else {
		$total_hits++;
		my $pos_query_hit_length = ($q_end - $q_start) + 1;
		my $pos_query_cov = $pos_query_hit_length/$q_len;

		if ( ($pos_query_cov >= $percent_cov) && ($pid >= $percent_id) ) {
		    if (exists $db->{$enc_pair}) {
			push @{$db->{$enc_pair}}, $score;
		    }
		    elsif (exists $db->{$enc_revpair}) {
			push @{$db->{$enc_revpair}}, $score;
		    }
		    else {
			$db->{$enc_pair} = [$score];
			$match_index{$q_name} = $index unless exists $match_index{$q_name};
			$index++;
			$match_index{$s_name} = $index unless exists $match_index{$s_name};
			$index++;
		    }
		}
	    }
	}
	close $in;

	for my $idx_mem (sort { $match_index{$a} <=> $match_index{$b} } keys %match_index) {
	    say $idx join " ", $idx_mem, $match_index{$idx_mem};
	}
	close $idx;

	while (my ($match, $scores) = each %$db) {
	    my $enc_match = encode("UTF-8", $match, 1);
	    my $match_score = max(@$scores);
	    my ($qry, $sbj) = mk_vec($enc_match);
	    my $revmatch = mk_key($sbj, $qry);
	    my $enc_revmatch = encode("UTF-8", $revmatch, 1);
	    if (exists $db->{$enc_revmatch}) {
		my $rev_match_score = max(@{$db->{$enc_revmatch}});
		if ($rev_match_score > $match_score) {
		    if (exists $match_index{$sbj} && exists $match_index{$qry}) {
			say $hs join "\t", $sbj, $qry, $rev_match_score;
			say $int join "\t", $match_index{$sbj}, $match_index{$qry}, $rev_match_score;
			delete $db->{$enc_match};
		    }
		}
		else {
		    delete $db->{$enc_revmatch};
		}
	    }
	    else {
		if (exists $match_index{$qry} && exists $match_index{$sbj}) {
		    say $hs join "\t", $qry, $sbj, $match_score;
		    say $int join "\t", $match_index{$qry}, $match_index{$sbj}, $match_score;
		}
	    }
	}
	close $int;
	close $hs;

	untie %match_index;

	return($idx_path, $int_path, $hs_path);

    }
}

=head1 AUTHOR

S. Evan Staton, C<< <statonse at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-transposome at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Transposome>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::PairFinder


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

#1; # End of Transposome::PairFinder
__PACKAGE__->meta->make_immutable;
