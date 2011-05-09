=head1 NAME

EPrints::Plugin::Screen::BatchEdit

=cut

package EPrints::Plugin::Screen::BatchEdit;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ edit remove cancel /];

	# is linked to by the BatchEdit export plugin
	$self->{appears} = [];

	return $self;
}

sub allow_edit { $_[0]->can_be_viewed }
sub allow_remove { $_[0]->can_be_viewed }
sub allow_cancel { $_[0]->can_be_viewed }

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/archive/edit" );
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef;

	my $cacheid = $self->{processor}->{cacheid};

	return $self->SUPER::redirect_to_me_url."&cache=$cacheid";
}

sub hidden_bits
{
	my( $self ) = @_;

	return(
		$self->SUPER::hidden_bits,
		cache => $self->get_searchexp->get_cache_id,
	);
}

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	$self->{processor}->{cacheid} = $self->{session}->param( "cache" );
}

sub get_cache
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	return $session->dataset( "cachemap" )->dataobj( $processor->{cacheid} );
}

sub get_searchexp
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $cacheid = $processor->{cacheid};

	my $cache = $self->get_cache();
	return if !defined $cache;

	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $session->dataset( "eprint" ),
		keep_cache => 1,
	);

	if( $searchexp )
	{
		$searchexp->from_string_raw( $cache->get_value( "searchexp" ) );
		$searchexp->{"cache_id"} = $cacheid;
	}

	return $searchexp;
}

sub action_edit { }
sub action_remove { }
sub action_cancel { }

sub wishes_to_export
{
	my( $self ) = @_;

	return defined $self->{session}->param( "ajax" );
}

sub export
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $action = $session->param( "ajax" );
	return unless defined $action;

	if( $action eq "new_field" )
	{
		$self->ajax_new_field(
			$session->param( "field_name" ),
			$session->param( "c" )
		);
	}
	elsif( $action eq "edit" )
	{
		$self->ajax_edit();
	}
	elsif( $action eq "remove" )
	{
		$self->ajax_remove();
	}
	elsif( $action eq "list" )
	{
		$self->ajax_list();
	}
}

sub ajax_list
{
	my( $self ) = @_;

	my $max = 8;

	my $session = $self->{session};

	my $searchexp = $self->get_searchexp;
	return if !defined $searchexp;

	my $list = $searchexp->perform_search;

	$session->send_http_header( content_type => "text/xml; charset=UTF-8" );
	binmode(STDOUT, ":utf8");

	my $div = $session->make_element( "div" );

	my @records = $list->get_records( 0, $max );
	if( !scalar @records )
	{
		$div->appendChild( $session->render_message( "error", $session->html_phrase( "lib/searchexpression:noresults" ) ) );
		print EPrints::XML::to_string( $div, undef, 1 );
		EPrints::XML::dispose( $div );
		return;
	}

	$div->appendChild( $self->html_phrase( "applying_to",
		count => $session->make_text( $list->count ),
		showing => $session->make_text( $max ) ) );

	my $ul = $session->make_element( "ul" );
	$div->appendChild( $ul );

	foreach my $record (@records)
	{
		my $li = $session->make_element( "li" );
		$ul->appendChild( $li );
		$li->appendChild( $record->render_citation_link() );
	}

	print EPrints::XML::to_string( $div, undef, 1 );
	EPrints::XML::dispose( $div );
}

# generate a new action line
sub ajax_new_field
{
	my( $self, $name, $c ) = @_;

	my $session = $self->{session};

	my $searchexp = $self->get_searchexp;
	return if !defined $searchexp;

	my $dataset = $searchexp->get_dataset;
	return if !$dataset->has_field( $name );

	my $field;
	foreach my $f ($self->get_fields( $dataset ))
	{
		$field = $f, last if $f->get_name eq $name;
	}
	return if !defined $field;

	$field = $field->clone;
	my @options;
	if( $field->get_property( "multiple" ) )
	{
		@options = qw( clear delete insert append );
	}
	else
	{
		@options = qw( clear replace );
	}

	# construct a new field called the action number
	# this first sub-field is the action to perform (append, clear etc.)
	my $custom_field = {
		name => $c,
		type => "compound",
		fields => [{
			sub_name => "action",
			type => "set",
			options => \@options,
			title_xhtml => $session->make_doc_fragment,
			render_option => sub {
				my( undef, $option ) = @_;
				return $self->html_phrase( "actionopt:" . ($option||"") );
			},
		}],
	};

	# add the field or sub-fields that represent the field
	# the sub name of the field is the field's name
	# the title is the real field's title
	if( $field->isa( "EPrints::MetaField::Compound" ) )
	{
		for(@{$field->property( "fields" )})
		{
			my $inner_field = EPrints::Utils::clone( $_ );
			$inner_field->{sub_name} = join('_', $name, $inner_field->{sub_name});
			push @{$custom_field->{fields}}, $inner_field;
		}
	}
	else
	{
		$field->{sub_name} = $field->{name};
		push @{$custom_field->{fields}}, $field;
	}

	# and lastly a button to remove action entries and a hidden that tells us
	# the field name of the action name
	push @{$custom_field->{fields}}, {
			name => "batchedit_remove",
			sub_name => "remove",
			type => "text",
			title_xhtml => $session->make_doc_fragment,
			render_input => sub {
				my $frag = $session->make_doc_fragment;
				
				# button to remove the action
				$frag->appendChild( $session->make_element( "input",
					type => "image",
					alt => "Remove",
					src => $session->get_url( path => "static", "style/images/action_remove.png" ),
					onclick => "ep_batchedit_remove_action($c)",
				) );

				# hint so we can work out how to retrieve the values
				$frag->appendChild( $session->make_element( "input",
					type => "hidden",
					name => "action_$c",
					value => $name
				) );

				return $frag;
			},
		};

	# do some tidying up and turn custom_field into a temporary field object
	$custom_field = $self->custom_field_to_field( $dataset, $custom_field );

	my $div = $session->make_element( "div", id => "action_$c" );

	my $title_div = $session->make_element( "div", class => "ep_form_field_name" );
	$div->appendChild( $title_div );
	$title_div->appendChild( $field->render_name( $session ) );

	my $help_div = $session->make_element( "div", class => "ep_form_field_help" );
	$div->appendChild( $help_div );
	$help_div->appendChild( $field->render_help( $session ) );

	my $inputs = $custom_field->render_input_field( $session );
	$div->appendChild( $inputs );

	$session->send_http_header( content_type => "text/xml; charset=UTF-8" );
	binmode(STDOUT, ":utf8");
	print EPrints::XML::to_string( $div, undef, 1 );
	EPrints::XML::dispose( $div );
}

sub ajax_edit
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $progressid = $session->param( "progressid" );

	my $searchexp = $self->get_searchexp;
	EPrints->abort( "Missing search expression" ) if !defined $searchexp;

	my $list = $searchexp->perform_search;
	my $progress = $session->dataset( "upload_progress" )->create_dataobj({
		progressid => $progressid,
		received => 0,
		size => $list->count
	}) or EPrints->abort( "Error creating progress object" );

	my $request = $session->get_request;

	$request->content_type( "text/html; charset=UTF-8" );
	my $html = $session->make_element( "html" );
	my $body = $html->appendChild( $session->make_element( "body",
		onload => "window.top.window.ep_batchedit_finished()"
	) );

	my $dataset = $searchexp->get_dataset;

	my @actions = $self->get_changes( $dataset );

	if( !@actions )
	{
		$progress->remove();
		$body->appendChild( $session->render_message( "warning", $self->html_phrase( "no_changes" ) ) );
		print $session->xhtml->to_xhtml( $html );
		EPrints::XML::dispose( $html );
		return;
	}

	$list->map(sub {
		my( $session, $dataset, $dataobj ) = @_;

		foreach my $act (@actions)
		{
			my $field = $act->{"field"};
			my $action = $act->{"action"};
			my $value = $act->{"value"};
			my $orig_value = $field->get_value( $dataobj );

			if( $field->get_property( "multiple" ) )
			{
				if( $action eq "clear" )
				{
					$field->set_value( $dataobj, [] );
				}
				elsif( $action eq "delete" )
				{
					my $values = EPrints::Utils::clone( $orig_value );
					@$values = grep { cmp_deeply($value, $_) != 0 } @$values;
					$field->set_value( $dataobj, $values );
				}
				elsif( $action eq "insert" )
				{
					my @values = ($value, @$orig_value);
					$field->set_value( $dataobj, \@values );
				}
				elsif( $action eq "append" )
				{
					my @values = (@$orig_value, $value);
					$field->set_value( $dataobj, \@values );
				}
			}
			else
			{
				if( $action eq "clear" )
				{
					$field->set_value( $dataobj, undef );
				}
				elsif( $action eq "replace" )
				{
					$field->set_value( $dataobj, $value );
				}
			}
		}

		$dataobj->commit;

		$progress->set_value( "received", $progress->value( "received" ) + 1 );
		$progress->commit;
	});

	my $ul = $session->make_element( "ul" );
	foreach my $act (@actions)
	{
		my $field = $act->{"field"};
		my $action = $act->{"action"};
		my $value = $act->{"value"};
		my $li = $session->make_element( "li" );
		$ul->appendChild( $li );
		$value = defined($value) ?
			$field->render_single_value( $session, $value ) :
			$session->html_phrase( "lib/metafield:unspecified" );
		$li->appendChild( $self->html_phrase( "applied_$action",
			value => $session->make_text( EPrints::Utils::tree_to_utf8( $value ) ),
			fieldname => $field->render_name,
		) );
		EPrints::XML::dispose( $value );
	}
	$body->applied( $session->render_message( "message", $self->html_phrase( "applied",
		changes => $ul,
	) ) );

	$progress->remove;

	print EPrints::XHTML::to_xhtml( $html );
	EPrints::XML::dispose( $html );
}

sub ajax_remove
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $progressid = $session->param( "progressid" );

	my $searchexp = $self->get_searchexp;
	EPrints->abort( "Missing search expression" ) if !defined $searchexp;

	my $list = $searchexp->perform_search;
	my $progress = $session->dataset( "upload_progress" )->create_dataobj({
		progressid => $progressid,
		received => 0,
		size => $list->count
	}) or EPrints->abort( "Error creating progress object" );

	my $request = $session->get_request;
	my $html = $session->make_element( "html" );
	my $body = $html->appendChild( $session->make_element( "body",
		onload => "window.top.window.ep_batchedit_finished()"
	) );

	$request->content_type( "text/html; charset=UTF-8" );

	my $dataset = $searchexp->get_dataset;

	$list->map(sub {
		my( $session, $dataset, $dataobj ) = @_;

		$dataobj->remove;

		$progress->set_value( "received", $progress->value( "received" ) + 1 );
		$progress->commit;
	});

	$body->appendChild( $session->render_message( "message", $self->html_phrase( "removed" ) ) );

	$progress->remove;

	print EPrints::XHTML::to_xhtml( $html );
	EPrints::XML::dispose( $html );
}

sub render
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	my $searchexp = $self->get_searchexp;
	if( !defined $searchexp )
	{
		$processor->add_message( "error", $self->html_phrase( "invalid_cache" ) );
		return $page;
	}

	my $list = $searchexp->perform_search;
	if( $list->count == 0 || !$list->slice(0,1) )
	{
		$processor->add_message( "error", $session->html_phrase( "lib/searchexpression:noresults" ) );
		return $page;
	}

	my $iframe = $session->make_element( "iframe",
			id => "ep_batchedit_iframe",
			name => "ep_batchedit_iframe",
			width => "0px",
			height => "0px",
			style => "border: 0px;",
	);
	$page->appendChild( $iframe );

	$page->appendChild( $self->render_cancel_form( $searchexp ) );

	$p = $session->make_element( "p" );
	$page->appendChild( $p );
	$p->appendChild( $searchexp->render_description );

	$p = $session->make_element( "div", id => "ep_batchedit_sample" );
	$page->appendChild( $p );

	$div = $session->make_element( "div", id => "ep_progress_container" );
	$page->appendChild( $div );

	$div = $session->make_element( "div", id => "ep_batchedit_inputs" );
	$page->appendChild( $div );

	$div->appendChild( $session->xhtml->tabs(
		[
			$self->html_phrase( "edit_title" ),
			$self->html_phrase( "remove_title" )
		],
		[
			$self->render_changes_form( $searchexp ),
			$self->render_remove_form( $searchexp ),
		],
	) );

	return $page;
}

sub get_fields
{
	my( $self, $dataset ) = @_;

	my @fields;

	my %fieldnames;

	foreach my $field ($dataset->get_fields)
	{
		next if defined $field->{sub_name};
		next if $field->get_name eq $dataset->get_key_field->get_name;
		next if
			!$field->isa( "EPrints::MetaField::Compound" ) &&
			!$field->get_property( "show_in_fieldlist" );

		push @fields, $field;
		my $name = $field->render_name( $self->{session} );
		$fieldnames{$field} = lc(EPrints::Utils::tree_to_utf8( $name ) );
		EPrints::XML::dispose( $name );
	}

	@fields = sort { $fieldnames{$a} cmp $fieldnames{$b} } @fields;

	return @fields;
}

sub get_changes
{
	my( $self, $dataset ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my @actions;

	my @idx = map { /_(\d+)$/; $1 } grep { /^action_\d+$/ } $session->param;

	my %fields = map { $_->get_name => $_ } $self->get_fields( $dataset );

	foreach my $i (@idx)
	{
		my $name = $session->param( "action_" . $i );
		next if !EPrints::Utils::is_set( $name );
		my $action = $session->param( $i . "_action" );
		next if !EPrints::Utils::is_set( $action );
		my $field = $fields{$name};
		next if !defined $field;
		do {
			local $field->{multiple} = 0;
			my $value = $field->form_value( $session, undef, $i );
			push @actions, {
				action => $action,
				field => $field,
				value => $value,
			};
		};
	}

	return @actions;
}

sub render_changes_form
{
	my( $self, $searchexp ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $dataset = $searchexp->get_dataset;

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	my %buttons = (
		edit => $self->phrase( "action:edit" ),
	);

	my $form = $session->render_input_form(
		dataset => $dataset,
#		fields => \@input_fields,
		show_help => 0,
		show_names => 1,
#		top_buttons => \%buttons,
		buttons => \%buttons,
		hidden_fields => {
			screen => $processor->{screenid},
			cache => $searchexp->get_cache_id,
			max_action => 0,
			ajax => "edit",
			progressid => "", # set by JavaScript
		},
	);
	$page->appendChild( $form );
	$form->setAttribute( id => "ep_batchedit_form" );
	$form->setAttribute( target => "ep_batchedit_iframe" );
	$form->setAttribute( onsubmit => "return ep_batchedit_submitted();" );

	my $container = $session->make_element( "div" );
	# urg, fragile!
	for($form->childNodes)
	{
		if( $_->nodeName eq "input" && $_->getAttribute( "type" ) eq "hidden" )
		{
			$form->insertBefore( $container, $_ );
			last;
		}
	}

	$div = $session->make_element( "div", id => "ep_batchedit_actions" );
	$container->appendChild( $div );

	my $select = $session->make_element( "select", id => "ep_batchedit_field_name" );
	$container->appendChild( $select );

	foreach my $field ($self->get_fields( $dataset ))
	{
		my $option = $session->make_element( "option", value => $field->get_name );
		$select->appendChild( $option );

		$option->appendChild( $field->render_name( $session ) );
	}

	my $add_button = $session->make_element( "button", class => "ep_form_action_button", onclick => "ep_batchedit_add_action(); return false" );
	$container->appendChild( $add_button );

	$add_button->appendChild( $self->html_phrase( "add_action" ) );

	return $page;
}

sub render_cancel_form
{
	my( $self, $searchexp ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $dataset = $searchexp->get_dataset;

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	my $form = $session->render_input_form(
		dataset => $dataset,
		show_help => 0,
		show_names => 1,
		buttons => {},
		hidden_fields => {
			screen => $processor->{screenid},
			cache => $searchexp->get_cache_id,
		},
	);
	$form->setAttribute( id => "ep_batchedit_cancel_form" );
	$page->appendChild( $form );

	return $page;
}

sub render_remove_form
{
	my( $self, $searchexp ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $dataset = $searchexp->get_dataset;

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	$div = $session->make_element( "div", class => "ep_block" );
	$page->appendChild( $div );

	$div->appendChild( $self->html_phrase( "remove_help" ) );

	$div = $session->make_element( "div", class => "ep_block" );
	$page->appendChild( $div );

	my %buttons = (
		remove => $session->phrase( "lib/submissionform:action_remove" ),
	);

	my $form = $session->render_input_form(
		dataset => $dataset,
		show_help => 0,
		show_names => 1,
		buttons => \%buttons,
		hidden_fields => {
			screen => $processor->{screenid},
			cache => $searchexp->get_cache_id,
			ajax => "remove",
		},
	);
	$form->setAttribute( target => "ep_batchedit_iframe" );
	my $message = EPrints::Utils::js_string( $self->phrase( "confirm_remove" ) );
	$form->setAttribute( onsubmit => "return ep_batchedit_remove_submitted( $message );" );
	$div->appendChild( $form );
	$form->setAttribute( id => "ep_batchremove_form" );

	return $page;
}

sub custom_field_to_field
{
	my( $self, $dataset, $data ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	$data->{fields_cache} = [];

	my $field = EPrints::MetaField->new(
		dataset => $dataset,
		%{$data},
	);

	foreach my $inner_field (@{$field->property( "fields_cache" )})
	{
		next if $inner_field eq $field->property( "fields_cache" )->[0];
		next if $inner_field eq $field->property( "fields_cache" )->[-1];

		delete $inner_field->{multiple};
		local $inner_field->{name} = $inner_field->{sub_name};
		$inner_field->{title_xhtml} = $inner_field->render_name( $session );
		$inner_field->{render_option} = sub {
			my( undef, $option ) = @_;

			local $inner_field->{name} = $inner_field->{sub_name};
			local $inner_field->{render_option};

			return $inner_field->render_option( $session, $option );
		};
	}

	return $field;
}

sub cmp_deeply
{
	my( $var_a, $var_b ) = @_;

	if( !EPrints::Utils::is_set($var_a) )
	{
		return 0;
	}
	elsif( !EPrints::Utils::is_set($var_b) )
	{
		return -1;
	}

	my $rc = 0;

	$rc ||= ref($var_a) cmp ref($var_b);
	$rc ||= _cmp_hash($var_a, $var_b) if( ref($var_a) eq "HASH" );
	$rc ||= $var_a cmp $var_b if( ref($var_a) eq "" );

	return $rc;
}

sub _cmp_hash
{
	my( $var_a, $var_b ) = @_;

	my $rc = 0;

	for(keys %$var_a)
	{
		$rc ||= cmp_deeply( $var_a->{$_}, $var_b->{$_} );
	}

	return $rc;
}

sub render_links
{
	my( $self ) = @_;

	my $frag = $self->SUPER::render_links;

	$frag->appendChild( $self->{session}->make_javascript( undef,
		src => $self->{session}->current_url( path => "static", "javascript/screen_batchedit.js" ) )
	);

	return $frag;
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

=cut

