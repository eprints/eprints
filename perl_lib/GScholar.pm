package GScholar;

use strict;
use warnings;

use WWW::Mechanize::Sleepy;
use URI;

our $MECH = WWW::Mechanize::Sleepy->new(
	sleep => '3..10',
	autocheck => 1,
);

$MECH->agent_alias( "Linux Mozilla" ); # Engage cloaking device!

our $SCHOLAR = URI->new( "http://scholar.google.com/scholar" );

sub get_cites
{
	my( $session, $eprint ) = @_;

	my $title = $eprint->get_value( "title" );
	$title =~ s/^(.{30,}?):\s.*$/$1/; # strip sub-titles

	my $creator = (@{$eprint->get_value( "creators_name" )})[0];
	$creator = $creator->{family};

	my $eprint_link = $eprint->get_url;

	my $quri = $SCHOLAR->clone;

	$quri->query_form(
			q => "allintitle:($title) author:$creator"
			);

	my $cluster_id;

	print STDERR "GET $quri\n" if $session->{noise} > 1;
	$MECH->get( $quri );

	# The EPrint URL
	my $by_url = $MECH->find_link( url_regex => qr/^$eprint_link/ );
	# An exact match for the title
	my $title_re = substr($title,0,200);
	$title_re =~ s/[^\w\s]/\.?/g;
	$title_re =~ s/\s+/(?:\\s|(?:<\\\/?b>))+/g;
	my $by_title = $MECH->find_link( text_regex => qr/^(?:<b>)?$title_re/i );
	for( grep { defined $_ } $by_url, $by_title )
	{
		my @links = $MECH->links;
		my $i;
		for($i = 0; $i < @links; ++$i)
		{
			last if $links[$i]->url eq $_->url;
		}
		for(; $i < @links; ++$i)
		{
			last if $links[$i]->text =~ /^all \d+ versions/;
			last if $links[$i]->text =~ /^Cited by \d+/;
			if( $links[$i]->text =~ /Web Search/ )
			{
				$i = @links;
				last;
			}
		}
		if( $links[$i] )
		{
			$cluster_id = {$links[$i]->URI->query_form}->{"cluster"};
		}
	}

	unless( $cluster_id )
	{
		my @clusters = $MECH->find_all_links( text_regex => qr/all \d+ versions/ );
		for(@clusters)
		{
			my $url = $_->URI;
			print STDERR "GET $url\n" if $session->{noise} > 1;
			$MECH->get( $url );

			$eprint_link = $MECH->find_link( url_regex => qr/^$eprint_link/ );

			$MECH->back;

			if( $eprint_link )
			{
				$cluster_id = {$url->query_form}->{cluster};
				last;
			}
		}
	}

	unless( $cluster_id )
	{
		print STDERR "No match for ".$eprint->get_id."\n" if $session->{noise} > 1;
		return undef;
	}

	my $cites = 0;
	my $cites_link = $MECH->find_link(
			text_regex => qr/Cited by \d+/,
			url_regex => qr/\b$cluster_id\b/
		);

	if( $cites_link )
	{
		$cites_link->text =~ /(\d+)/;
		$cites = $1;
	}

	return {
		cluster => $cluster_id,
		impact => $cites,
	};
}

1;
