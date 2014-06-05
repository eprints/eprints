=head1 NAME

EPrints::Plugin::Export::GScholar

=cut

package EPrints::Plugin::Export::GScholar;

use EPrints::Plugin::Export;
@ISA = ( "EPrints::Plugin::Export" );

use URI;

use strict;

our $SCHOLAR = URI->new( "http://scholar.google.com/scholar" );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Google Scholar Update";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "staff";
	$self->{advertise} = 0;
	$self->{suffix} = ".txt";
	$self->{mimetype} = "text/plain";

	if( defined $self->repository && $self->repository->has_dataset( 'eprint' ) ) 
	{
		my $ds = $self->repository->dataset( 'eprint' );

		if( !defined $ds || !$ds->has_field( 'gscholar' ) )
		{
			$self->{disable} = 1;
		}
	}

	return $self;
}

sub output_dataobj
{
	my( $self, $eprint ) = @_;

	if( !EPrints::Utils::require_if_exists( "WWW::Mechanize::Sleepy" ) )
	{
		EPrints->abort( "Requires WWW::Mechanize::Sleepy" );
	}

	my $field = $eprint->get_dataset->get_field( "gscholar" );

	my $cite_data = get_cites( $self->{session}, $eprint );
	if( EPrints::Utils::is_set( $cite_data ) )
	{
		$cite_data->{datestamp} = EPrints::Time::get_iso_timestamp();
		$eprint->set_value( "gscholar", $cite_data );
		$eprint->commit;
	}
	return $eprint->get_id . "\n";
}

sub get_cites
{
	my( $session, $eprint ) = @_;

	return undef if !$eprint->is_set( "title" );
	return undef if !$eprint->is_set( "creators_name" );

	our $MECH = WWW::Mechanize::Sleepy->new(
		sleep => '5..15',
		autocheck => 1,
	);

	$MECH->agent_alias( "Linux Mozilla" ); # Engage cloaking device!

	my $title = $eprint->get_value( "title" );
	$title =~ s/^(.{30,}?):\s.*$/$1/; # strip sub-titles

	my $creator = (@{$eprint->get_value( "creators_name" )})[0];
	$creator = $creator->{family};

	my $eprint_link = $eprint->get_url;
	$eprint_link =~ s/(\d+\/)/(?:archive\/0+)?$1/;

	my $quri = $SCHOLAR->clone;

	utf8::encode( $title );
	utf8::encode( $creator );
	$quri->query_form(
			q => "$title author:$creator"
			);

	my $cluster_id;

	print STDERR "GET $quri\n" if $session->{noise} > 1;
	my $r = $MECH->get( $quri );
	die $r->code unless $r->is_success;

	# The EPrint URL
	my $by_url = $MECH->find_link( url_regex => qr/^$eprint_link/ );
	# An exact match for the title
	my $title_re = $title;
	while( length( $title_re ) > 70 )
	{
		last unless $title_re =~ s/\s*\S+$//;
	}
	$title_re =~ s/[^\w\s]/\.?/g;
	$title_re =~ s/\s+/(?:\\s|(?:<\\\/?b>))+/g;
	my $by_title = $MECH->find_link( text_regex => qr/^(?:<b>)?$title_re/i );
	print STDERR "Title regexp=".(qr/^(?:<b>)?$title_re/i)."\n" if $session->{noise} > 2;
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
			if( $links[$i]->text =~ /^all \d+ versions/ )
			{
				$cluster_id = {$links[$i]->URI->query_form}->{"cluster"};
				last;
			}
			if( $links[$i]->text =~ /^Cited by \d+/ )
			{
				$cluster_id = {$links[$i]->URI->query_form}->{"cites"};
				last;
			}
			if( $links[$i]->text =~ /Web Search/ )
			{
				last;
			}
		}
	}

	unless( $cluster_id )
	{
		my @clusters = $MECH->find_all_links( text_regex => qr/all \d+ versions/i );
		for(@clusters)
		{
			my $url = $_->URI;
			print STDERR "GET $url\n" if $session->{noise} > 1;
			$MECH->get( $url );

			my $by_link = $MECH->find_link( url_regex => qr/^$eprint_link/ );

			$MECH->back;

			if( $by_link )
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

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

