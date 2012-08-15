=head1 NAME

EPrints::Plugin::Screen::Import

=cut


package EPrints::Plugin::Screen::Import;

use base qw( EPrints::Plugin::Screen );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ import_from add all confirm_all cancel /];

	$self->{post_import_screen} = "EPrint::Edit";
	$self->{post_bulk_import_screen} = "Items";

	return $self;
}

sub from
{
	my( $self ) = @_;

	my $action = $self->{processor}->{action};

	if( $action && $action =~ /^(add)_(\d+)$/ )
	{
		$self->{processor}->{action} = $1;
		$self->{processor}->{notes}->{n} = $2;
	}

	return $self->SUPER::from;
}

sub properties_from
{
	my( $self ) = @_;
	
	my $repo = $self->repository;

	$self->SUPER::properties_from;

	$self->{processor}->{format} = $repo->param( "format" );

	if( !defined $self->{processor}->{format} )
	{
		$self->{processor}->add_message( "error", $repo->html_phrase( "general:bad_param" ) );
		return;
	}

	# default dataset to import to
	$self->{processor}->{dataset} = $repo->dataset( "inbox" );
}

sub can_create
{
	my( $self, $dataset ) = @_;

	# check we can create the object
	return 0 unless
		$self->allow( join '_', "create", $dataset->base_id ) ||
		$self->allow( join '/', $dataset->base_id, "create" );

	if( $dataset->id eq "buffer" )
	{
		return 0 if !$self->allow( "eprint/inbox/move_buffer" );
	}
	elsif( $dataset->id eq "archive" )
	{
		return 0 if !$self->allow( "eprint/buffer/move_archive" );
	}

	return 1;
}

sub can_be_viewed
{
	my( $self ) = @_;
	return $self->allow( "create_eprint" );
}

sub allow_import_from { shift->can_be_viewed }
sub allow_cancel { shift->can_be_viewed }

sub allow_add { shift->can_be_viewed }
sub allow_all { shift->can_be_viewed }
sub allow_confirm_all { shift->can_be_viewed }

sub action_import_from
{
	my( $self ) = @_;

	my $uri = $self->repository->current_url( path => "cgi", "users/home" );
	$uri->query_form( $self->hidden_bits );

	$self->{processor}->{redirect} = $uri;
}

sub action_cancel {}

sub action_add
{
	my( $self ) = @_;

	my $repo = $self->{session};
	my $processor = $self->{processor};

	my $results = $self->{processor}->{results};
	return if !defined $results;

	my $dataobj = $results->item( $self->{processor}->{notes}->{n} );

	if( !$self->can_create( $dataobj->get_dataset ) )
	{
		$processor->add_message( "error", $self->html_phrase( "lib/session:no_priv" ) );
		return;
	}

	my $dataset = $dataobj->get_dataset;
	$dataobj = $dataset->create_dataobj( $dataobj->get_data );

	$processor->add_message( "message", $repo->html_phrase( "Plugin/Screen/Import:add",
			dataset => $dataset->render_name,
			dataobj => $dataobj->render_citation( "default",
				url => $dataobj->uri,
			)
		) );

	if( $results->count == 1 )
	{
		$processor->{dataobj} = $processor->{eprint} = $dataobj;
		$processor->{dataobj_id} = $processor->{eprintid} = $dataobj->id;
		$processor->{screenid} = $self->param( "post_import_screen" );
	}
}

sub action_all
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $cache = $self->{processor}->{results};
	return if !defined $cache;

	if( $cache->count <= $self->param( "bulk_import_warn" ) )
	{
		return $self->action_confirm_all;
	}
	else
	{
		my $form = $self->render_form;
		$form->appendChild( $repo->render_action_buttons(
					confirm_all => $repo->phrase( "lib/submissionform:action_confirm" ),
					cancel => $repo->phrase( "lib/submissionform:action_cancel" ),
					_order => [qw( confirm_all cancel )],
				) );
		$self->{processor}->add_message( "message", $repo->html_phrase( "Plugin/Screen/Import:confirm_all",
				n => $repo->make_text( $cache->count ),
				limit => $repo->make_text( $self->param( "bulk_import_limit" ) ),
				form => $form,
			) );
	}
}

sub action_confirm_all
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $cache = $self->{processor}->{results};
	return if !defined $cache;

	my $c = 0;

	$cache->map(sub {
		(undef, undef, my $dataobj) = @_;

		next if !$self->can_create( $dataobj->get_dataset );
		next if $self->search_duplicate( $dataobj );

		$dataobj = $dataobj->get_dataset->create_dataobj( $dataobj->get_data );
		++$c if defined $dataobj;

		goto BULK_LIMIT if $c >= $self->param( "bulk_import_limit" );
	});

	BULK_LIMIT:

	$self->{processor}->add_message( "message", $repo->html_phrase( "Plugin/Screen/Import:all",
			n => $repo->make_text( $c ),
		) );
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $action = $self->{processor}->{action};
	$action = "" if !defined $action;

	my $uri = URI::http->new($self->{processor}->{url});
	$uri->query_form( $self->hidden_bits );

	return $uri;
}

sub render_title
{
	my( $self ) = @_;

	return $self->{session}->html_phrase( "Plugin/Screen/Import:title",
		input => $self->{processor}->{plugin}->html_phrase( "title" )
	);
}

sub render
{
	my ( $self ) = @_;

	my $session = $self->{session};
	my $plugin = $self->{processor}->{plugin};

	my $f = $session->make_doc_fragment;

	if( $self->{processor}->{results} )
	{
		$f->appendChild( $self->render_results );
	}
	else
	{
		$f->appendChild( $self->render_input );
	}

	return $f;
}

sub render_input
{
	EPrints->abort( "render_input not subclassed" );
}

sub item
{
	my( $self, $i ) = @_;

	return ($self->slice($i,1))[0];
}
sub count { shift->{processor}->{results}->count }
*get_records = \&slice;
sub slice
{
	my( $self, $offset, $count ) = @_;

	my $import = $self->{processor}->{results};

	$offset ||= 0;

	return () if $offset >= $import->value( "count" );

	if( !defined $count || $offset + $count > $import->value( "count" ) )
	{
		$count = $import->value( "count" ) - $offset;
	}

	my @records = $import->slice( $offset, $count );

	# query for more records
	if( @records < $count && $import->is_set( "query" ) )
	{
		$_->remove for @records;
		@records = ();

		while(@records < $count)
		{
			$self->run_import(
					query => $self->{processor}->{notes}->{query},
					quiet => 1,
					offset => $offset + @records,
				);

			my @chunk = $import->slice( $offset + @records, $count - @records );
			push @records, @chunk;
			last if !@chunk; # no more records found
		}
	}

	# convert import cache objects into the actual objects
	local $_;
	for(@records)
	{
		my $dataset = $self->{session}->dataset( $_->value( "datasetid" ) );
		$_ = $dataset->make_dataobj( $_->value( "epdata" ) );
		if( $dataset->base_id eq "eprint" )
		{
			$_->set_value( "eprint_status", "inbox" );
		}
	}

	return @records;
}

sub render_results
{
	my ( $self ) = @_;

	my $session = $self->{session};

	my $f = $session->make_doc_fragment;

	my $results = $self->{processor}->{results};

	my $form = $self->render_form;
	$f->appendChild( $form );

	if( $results->count )
	{
		my $div = $form->appendChild( $session->make_element( "div",
				class => "ep_block"
			) );
		$div->appendChild( $session->render_action_buttons(
					all => $session->phrase( "Plugin/Screen/Import:action:all:title" ),
					_order => [qw( all )],
				) );
	}

	$form->appendChild( EPrints::Paginate->paginate_list(
			$session,
			undef,
			$results,
			params => {$self->hidden_bits},
			container => $session->make_element(
				"table",
				class=>"ep_paginate_list ep_columns"
			),
			render_result => sub {
				my( undef, $result, undef, $n ) = @_;

				return $self->render_result_row( $result, $n );
			},
			controls_before => [$self->controls_before],
		) );

	return $f;
}

sub controls_before {}

sub render_result_row
{
	my( $self, $dataobj, $n ) = @_;

	my $repo = $self->{session};
	my $xhtml = $repo->xhtml;
	my $xml = $repo->xml;
	my $dataset = $dataobj->{dataset};

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( my $tr = $repo->make_element( "tr", class => ($n % 2 ? "row_a" : "row_b") ) );
	my $td;

	$td = $tr->appendChild( $repo->make_element( "td", class => "ep_columns_cell" ) );
	$td->appendChild( $repo->make_text( $n ) );

	$td = $tr->appendChild( $repo->make_element( "td", class => "ep_columns_cell" ) );
	$td->appendChild( $dataset->render_name );

	$td = $tr->appendChild( $repo->make_element( "td", class => "ep_columns_cell" ) );
	$td->appendChild( $dataobj->render_citation );

	$td = $tr->appendChild( $repo->make_element( "td", class => "ep_columns_cell" ) );

	my @action_buttons;

	# previously imported
	if( defined( my $dupe = $self->search_duplicate( $dataobj ) ) )
	{
		push @action_buttons, $xml->create_data_element( "a", [
					[
						"img",
						undef,
						src => $repo->current_url( path => "static", "style/images/action_view.png" ),
						alt => $repo->phrase( "Plugin/Screen/Import:action:view:title" ),
					],
				],
				href => $dupe->uri,
				title => $repo->phrase( "Plugin/Screen/Import:action:view:title" ),
			);
	}
	else
	{
		$tr->setAttribute(
			class => $tr->getAttribute( "class" ) . " ep_diff_add"
		);
	}

	# add as a new record for the current user
	push @action_buttons, $xhtml->action_icon(
			"add_" . $n,
			$repo->current_url( path => "static", "style/images/action_import.png" ),
			alt => $repo->phrase( "Plugin/Screen/Import:action:add:title" ),
			title => $repo->phrase( "Plugin/Screen/Import:action:add:title" ),
		);

	$td->appendChild( $xhtml->action_list( \@action_buttons ) );

	return $frag;
}

sub search_duplicate
{
	my( $self, $dataobj ) = @_;

	return if !$dataobj->exists_and_set( "source" );

	my $dataset = $dataobj->{dataset};
	$dataset = $self->repository->dataset( $dataset->base_id );

	my $dupe = $dataset->search( filters => [
			{ meta_fields => [qw( source )], value => $dataobj->value( "source" ), match => "EX", }
		],
		limit => 1,
	)->item( 0 );

	return $dupe;
}

sub _vis_level
{
	my( $self ) = @_;

	my $user = $self->{session}->current_user;

	return $user->is_staff ? "staff" : "all";
}

sub hidden_bits
{
	my( $self ) = @_;

	return(
		$self->SUPER::hidden_bits,
		format => $self->{processor}->{format},
	);
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

