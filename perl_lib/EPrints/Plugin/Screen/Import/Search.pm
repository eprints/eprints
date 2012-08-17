=head1 NAME

EPrints::Plugin::Screen::Import::Search

=cut


package EPrints::Plugin::Screen::Import::Search;

use base "EPrints::Plugin::Screen::Import";

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	push @{$self->{appears}}, {
			place => "user_tasks",
			position => 100,
		};

	push @{$self->{actions}}, qw/ search refine /;

#	$self->{post_import_screen} = "EPrint::Edit";
#	$self->{post_bulk_import_screen} = "Items";

#	$self->{show_stderr} = 1;

#	$self->{encodings} = \@ENCODINGS;
#	$self->{default_encoding} = "iso-8859-1";

	$self->{bulk_import_limit} = 30;
	$self->{bulk_import_warn} = 10;

	return $self;
}

sub properties_from
{
	my( $self ) = @_;
	
	$self->SUPER::properties_from;

	my $repo = $self->repository;
	my $processor = $self->{processor};

	my $plugin_id = $self->{processor}->{format};

	# dataset to import into
	my $dataset = $processor->{dataset} = $repo->dataset( "inbox" );

	if( !defined $plugin_id )
	{
		$processor->add_message( "error", $repo->html_phrase( "general:bad_param" ) );
		return;
	}

	my $cache_id = $repo->param( "cache" );

	my $plugin = $repo->plugin(
		"Search::$plugin_id",
		session => $repo,
		dataset => $dataset,
		processor => $processor,
		cache_id => $cache_id,
	);

	if( !defined $plugin || $plugin->broken )
	{
		$processor->add_message( "error", $repo->html_phrase( "general:bad_param" ) );
		return;
	}

	$processor->{plugin} = $plugin;

	$processor->{notes}->{exp} = $repo->param( "exp" );
}

sub action_import_from
{
	my( $self ) = @_;

	undef $self->{processor}->{plugin};
	undef $self->{processor}->{results};

	return $self->SUPER::action_import_from;
}

sub hidden_bits
{
	my( $self ) = @_;

	return(
		$self->SUPER::hidden_bits,
		($self->{processor}->{plugin} ? (exp => $self->{processor}->{plugin}->serialise) : ()),
		($self->{processor}->{results} ? (cache => $self->{processor}->{results}->cache_id) : ()),
	);
}

sub from
{
	my( $self ) = @_;

	my $processor = $self->{processor};

	my $action = $processor->{action};
	$action = "" if !defined $action;

	# don't do anything
	return if $action eq "import_from";

	my $plugin = $processor->{plugin};

	if( defined $processor->{notes}->{exp} )
	{
		$plugin->from_string( $processor->{notes}->{exp} );
	}
	else
	{
		my @problems = $plugin->from_form( $plugin->get_id );
		for( @problems )
		{
			$self->{processor}->add_message( "warning", $_ );
		}
	}

	if( $action ne "refine" )
	{
		my $results = $processor->{results} = $plugin->execute;
		if( defined $results )
		{
			$results->cache;
		}
	}

	$self->SUPER::from();
}

sub allow_search { shift->can_be_viewed }
sub allow_refine { shift->can_be_viewed }

sub action_search {}
sub action_refine {}

sub render_action_link
{
	my( $self ) = @_;

	my $repo = $self->repository;

	my $frag = $repo->xml->create_document_fragment;

	my @plugins = $repo->get_plugins(
			type => "Search",
			is_external => 1,
			is_advertised => 1,
		);

	foreach my $plugin (@plugins)
	{
		local $self->{processor}->{format} = $plugin->get_subtype;
		my $uri = $repo->current_url( path => "cgi", "users/home" );
		$uri->query_form(
				$self->hidden_bits,
				_action_import_from => 1,
			);
		$frag->appendChild( $repo->xml->create_data_element(
				"a",
				$self->html_phrase( "action:new_search:title",
					format => $plugin->html_phrase( "title" ),
				),
				href => $uri,
			) );
	}

	return $frag;
}

sub render_input
{
	my( $self ) = @_;

	my $plugin = $self->{processor}->{plugin};

	my $form;
	
	{
		# we don't want exp stored in the search form
		local $self->{processor}->{plugin};
		$form = $self->render_form;
	}

	$form->appendChild( $plugin->render_input( $plugin->get_id ) );

	return $form;
}

sub controls_before
{
	my( $self ) = @_;

	my $repo = $self->repository;

	my @controls_before = $self->SUPER::controls_before;

	my $exp = $self->{processor}->{notes}->{exp};

	my $base_url = $repo->current_url( path => "cgi", "users/home" );
	$base_url->query_form( $self->hidden_bits );

	my $url;

	$url = $base_url->clone;
	$url->query_form(
			$url->query_form,
			_action_refine => 1,
		);

	push @controls_before, {
			url => $url,
			label => $repo->html_phrase( "lib/searchexpression:refine" ),
		};

	$url = $base_url->clone;
	$url->query_form(
			$url->query_form,
			_action_new_search => 1,
		);

	push @controls_before, {
			url => $url,
			label => $repo->html_phrase( "lib/searchexpression:new" ),
		};

	return @controls_before;
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

