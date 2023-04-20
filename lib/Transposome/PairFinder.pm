package Transposome::PairFinder;

use 5.010;
use Moose;
use DBI;
use Tie::Hash::DBD;
use Try::Tiny;
use File::Spec;
use File::Basename;
use File::Path qw(make_path);
use POSIX      qw(strftime);
#use Log::Any   qw($log);
use Transposome::Log;
use namespace::autoclean;

with 'Transposome::Role::File', 
     'Transposome::Role::Util';

=head1 NAME

Transposome::PairFinder - Parse mgblast and find best scoring unique matches.

=head1 VERSION

Version 0.12.1

=cut

our $VERSION = '0.12.1';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    use Transposome::PairFinder;

    my $blast_res = Transposome::PairFinder->new( file              => 'myblast.bln',
                                                  dir               => 'transposome_out',
                                                  in_memory         => 1,
                                                  percent_identity  => 90.0,
                                                  fraction_coverage => 0.55 );

=cut

has 'in_memory' => (
    is         => 'ro',
    isa        => 'Bool',
    predicate  => 'has_in_memory',
    lazy       => 1,
    default    => 0,
);

has 'percent_identity' => (
    is        => 'ro',
    isa       => 'Num',
    predicate => 'has_percent_identity',
    lazy      => 1,
    default   => 90.0,
);

has 'fraction_coverage' => (
    is        => 'ro',
    isa       => 'Num',
    predicate => 'has_percent_coverage',
    lazy      => 1,
    default   => 0.55,
);

has 'log_to_screen' => (
    is         => 'ro',
    isa        => 'Bool',
    predicate  => 'has_log_to_screen',
    lazy       => 1,
    default    => 1,
);

sub BUILD {
    my $self = shift;
    try {
	die unless -s $self->file;
    }
    catch {
	#$log->error("There seems to be no content in the input file. Check the blast results and try again. Exiting.");
	say STDERR "\n[ERROR]: There seems to be no content in the input file. Check the blast results and try again. Exiting.\n";
	exit(1);
    };
}

=head1 METHODS

=head2 parse_blast

 Title   : parse_blast
 Usage   : my ($idx_file, $int_file, $edge_file) = $pairfinder_obj->parse_blast;

 Function: Find the best scoring matches for each pair of sequences. 

                                                                            Return_type
 Returns : In order, 1) an index mapping the sequence ID and the            Scalar
                        sequence index used for clustering
                     2) a file containing the index of each sequence        Scalar
                        and match score
                     3) a file containg the pairwise information            Scalar
                        for each best scoring match

 Args    : None. This is class method called on a Transposome::PairFinder
           object.

=cut

sub parse_blast {
    my $self = shift;
    #my $config = $self->config;
    
    my ($iname, $ipath, $isuffix) = fileparse($self->file, qr/\.[^.]*/);
    unless (-d $self->dir) {
	make_path($self->dir, {verbose => 0, mode => 0771,});
    }
    my $int_file  = $iname;
    my $idx_file  = $iname;
    my $edge_file = $iname;
    $int_file     .= "_louvain.int";
    $idx_file     .= "_louvain.idx";
    $edge_file    .= "_louvain.edges";
    my $int_path  = File::Spec->catfile($self->dir, $int_file);
    my $idx_path  = File::Spec->catfile($self->dir, $idx_file);
    my $edge_path = File::Spec->catfile($self->dir, $edge_file);
    
    # counters
    my $total_hits  = 0;
    my $parsed_hits = 0;
    my $index       = 0;
    
    my $fh = $self->get_fh;
    
    # log results
    my $log_obj = Transposome::Log->new( config => $self->config, log_to_screen => $self->log_to_screen );
    my $log = $log_obj->get_transposome_logger;
    my $st = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("Transposome::PairFinder::parse_blast started at:   $st.");
    
    my %match_pairs;
    my %match_index;
    my $dbm = File::Spec->catfile($self->dir, "mgblast_matchpairs.dbm");
    my $dbi = File::Spec->catfile($self->dir, "mgblast_matchindex.dbm");
    
    unless ($self->in_memory) {
	unlink $dbm if -e $dbm;
	unlink $dbi if -e $dbi;
	
	my $mi_dbh = DBI->connect("dbi:SQLite:dbname=$dbi", undef, undef, {
	    AutoCommit       => 1,
	    RaiseError       => 1,
	    PrintError       => 0,
	    FetchHashKeyName => 'Name_lc',
	    journal_mode     => 'TRUNCATE',
	    synchronous      => 0,
	});


	tie %match_index, "Tie::Hash::DBD", $mi_dbh;

	my $mp_dbh = DBI->connect("dbi:SQLite:dbname=$dbm", undef, undef, {
	    PrintError       => 0, 
	    RaiseError       => 1,
	    AutoCommit       => 1,
	    FetchHashKeyName => 'NAME_lc',
	    synchronous      => 0,
	    journal_mode     => 'TRUNCATE'
	});

	tie %match_pairs, "Tie::Hash::DBD", $mp_dbh;
    }
    
    while (my $line = <$fh>) {
	chomp $line;
	$self->_validate_format($line);
	my ($q_name, $q_len, $q_start, $q_end, $s_name, $s_len,
	    $s_start, $s_end, $pid, $score, $e_val, $strand) = split /\t/, $line;
	
	my $pair            = $self->mk_key($q_name, $s_name);
	my $revpair         = $self->mk_key($s_name, $q_name);
	my $subj_hit_length = ($s_end - $s_start) + 1;
	my $subj_cov        = $subj_hit_length/$s_len;

	if ($q_start > $q_end) {
	    $total_hits++;
	    my $neg_query_hit_length = ($q_start - $q_end) + 1;
	    my $neg_query_cov        = $neg_query_hit_length/$q_len;

	    if ( ($neg_query_cov >= $self->fraction_coverage) && ($pid >= $self->percent_identity) ) {
		if (exists $match_pairs{$pair}) {
		    $match_pairs{$pair} = $score if $score > $match_pairs{$pair};
		}
		elsif (exists $match_pairs{$revpair}) {
		    $match_pairs{$revpair} = $score if $score > $match_pairs{$revpair};
		}
		else {
		    $match_pairs{$pair}   = $score;
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
	    my $pos_query_cov        = $pos_query_hit_length/$q_len;

	    if ( ($pos_query_cov >= $self->fraction_coverage) && ($pid >= $self->percent_identity) ) {
		if (exists $match_pairs{$pair}) {
		    $match_pairs{$pair} = $score if $score > $match_pairs{$pair};
		}
		elsif (exists $match_pairs{$revpair}) {
		    $match_pairs{$revpair} = $score if $score > $match_pairs{$revpair};
		}
		else {
		    $match_pairs{$pair}   = $score;
		    $match_index{$q_name} = $index unless exists $match_index{$q_name};
		    $index++;
		    $match_index{$s_name} = $index unless exists $match_index{$s_name};
		    $index++;
		}
	    }
	}
    }
    close $fh;
    
    open my $idx, '>', $idx_path or die "\n[ERROR]: Could not open file: $idx_path\n";

    for my $idx_mem (keys %match_index) {
	say $idx join q{ }, $idx_mem, $match_index{$idx_mem};
    }
    close $idx;

    open my $int, '>', $int_path or die "\n[ERROR]: Could not open file: $int_path\n";
    open my $edge,  '>', $edge_path  or die "\n[ERROR]: Could not open file: $edge_path\n";

    for my $match (keys %match_pairs) { 
	my $match_score = $match_pairs{$match}; # assignment simply to document algorithm
	my ($qry, $sbj) = $self->mk_vec($match);
	my $revmatch    = $self->mk_key($sbj, $qry);
	if (exists $match_pairs{$revmatch}) {
	    my $rev_match_score = $match_pairs{$revmatch};
	    if ($rev_match_score > $match_score) {
		if (exists $match_index{$sbj} && exists $match_index{$qry}) {
		    say $edge join "\t", $sbj, $qry, $rev_match_score;
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
		say $edge join "\t", $qry, $sbj, $match_score;
		say $int join "\t", $match_index{$qry}, $match_index{$sbj}, $match_score;
	    }
	}
    }
    close $int;
    close $edge;
    
    untie %match_index unless $self->in_memory;
    untie %match_pairs unless $self->in_memory;
    unlink $dbi if -e $dbi;
    unlink $dbm if -e $dbm;
    
    # log results
    my $ft = POSIX::strftime('%d-%m-%Y %H:%M:%S', localtime);
    $log->info("Transposome::PairFinder::parse_blast completed at: $ft.");
    $log->info("Final output files are:\n$int_file,\n$idx_file,\n$edge_file.");
    
    return ($idx_path, $int_path, $edge_path);

}

=head2 _validate_format

 Title   : _validate_format

 Usage   : This is a private method, do not use it directly.

 Function: Ensure the data is in the correct format and exit
           with a clear message.

 Returns : Nothing. This is a Transposome::Class method to be called
           on a line.

                                                                            Arg_type
 Args    : Receives a line from an open filehandle.                         Scalar

=cut

sub _validate_format {
    my $self = shift;
    my ($line) = @_;
    my @f = split /\t/, $line;
    unless (@f == 12) {
	#$log->error("'$line' is not the correct format in file: ".$self->file.". Exiting.");
	say STDERR "\n[ERROR]: '$line' is not the correct format in file: ".$self->file.". Exiting.\n";
	exit(1);
    }
}

=head1 AUTHOR

S. Evan Staton, C<< <evan at evanstaton.com> >>

=head1 BUGS

Please report any bugs or feature requests through the project site at 
L<https://github.com/sestaton/Transposome/issues>. I will be notified,
and there will be a record of the issue. Alternatively, I can also be 
reached at the email address listed above to resolve any questions.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Transposome::PairFinder


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2023 S. Evan Staton.

This program is distributed under the MIT (X11) License, which should be distributed with the package. 
If not, it can be found here: L<http://www.opensource.org/licenses/mit-license.php>

=cut

__PACKAGE__->meta->make_immutable;

1;
