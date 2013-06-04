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

	my $action = $self->{processor}->{action};
	return unless defined $action;

	if( $action eq "add_change" )
	{
		$self->ajax_add_change( scalar($session->param( "field_name" )) );
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
		print $session->xml->to_string( $div, undef, 1 );
		$session->xml->dispose( $div );
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

	print $session->xml->to_string( $div, undef, 1 );
	$session->xml->dispose( $div );
}

# generate a new action line
sub ajax_add_change
{
	my( $self, $name ) = @_;

	my $prefix = APR::UUID->new->format;

	my $session = $self->{session};

	my $searchexp = $self->get_searchexp;
	EPrints->abort( "Missing cache parameter" ) if !defined $searchexp;

	my $dataset = $searchexp->get_dataset;
	EPrints->abort( "'$name' is not a valid field" ) if !$dataset->has_field( $name );

	my $field;
	foreach my $f ($self->get_fields( $dataset ))
	{
		$field = $f, last if $f->get_name eq $name;
	}
	EPrints->abort( "'$name' is not a valid field" ) if !defined $field;

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
		name => $prefix,
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
					onclick => "\$('$prefix').remove(); return false;",
				) );

				# hint so we can work out how to retrieve the values
				$frag->appendChild( $session->make_element( "input",
					type => "hidden",
					name => $self->get_subtype."_change_".$prefix,
					value => $name
				) );

				return $frag;
			},
		};

	# do some tidying up and turn custom_field into a temporary field object
	$custom_field = $self->custom_field_to_field( $dataset, $custom_field );

	my $div = $session->make_element( "div", id => $prefix );
	$div->appendChild( $custom_field->render_input_field( $session ) );

	$session->send_http_header( content_type => "text/html; charset=UTF-8" );
	binmode(STDOUT, ":utf8");
	print $session->xhtml->to_xhtml( $div );
	$session->xml->dispose( $div );
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
	my $body = $html->appendChild( $session->make_element( "body" ) );

	my $dataset = $searchexp->get_dataset;

	my @actions = $self->get_changes( $dataset );

	if( !@actions )
	{
		$progress->remove();
		$body->appendChild( $session->render_message( "warning", $self->html_phrase( "no_changes" ) ) );
		print $session->xhtml->to_xhtml( $html );
		$session->xml->dispose( $html );
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
		$session->xml->dispose( $value );
	}
	$body->appendChild( $session->render_message( "message", $self->html_phrase( "applied",
		changes => $ul,
	) ) );

	$progress->remove;

	print $session->xhtml->to_xhtml( $html );
	$session->xml->dispose( $html );
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

	print $session->xhtml->to_xhtml( $html );
	$session->xml->dispose( $html );
}

sub render
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my $prefix = $self->get_subtype;

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

	$page->appendChild( $session->make_element( "iframe",
			id => "${prefix}_iframe",
			name => "${prefix}_iframe",
			width => "0px",
			height => "0px",
			style => "border: 0px;",
		) );

	$div = $session->make_element( "div" );
	$page->appendChild( $div );
	$div->appendChild( $searchexp->render_description );

	$div = $session->make_element( "div", id => "${prefix}_sample" );
	$page->appendChild( $div );

	$div = $session->make_element( "div", id => "${prefix}_progress" );
	$page->appendChild( $div );

	my $form = $self->render_form;
	$page->appendChild( $form );

	$form->setAttribute( target => "${prefix}_iframe" );
	$form->setAttribute( id => "${prefix}_form" );
	$form->appendChild( $session->xhtml->hidden_field(
			ajax => 1,
		) );
	
	my $progressid = APR::UUID->new->format; #contains unwanted hyphens
	$progressid =~ s/-//g;
	$form->appendChild( $session->xhtml->hidden_field(
			progressid => $progressid,
		) );

	$form->appendChild( $session->xhtml->tabs(
		[
			$self->html_phrase( "edit_title" ),
			$self->html_phrase( "remove_title" )
		],
		[
			$self->render_changes_form( $searchexp ),
			$self->render_remove_form( $searchexp ),
		],
	) );

	$page->appendChild( $session->make_javascript( <<EOJ ) );
Event.observe(window, 'load', function() {
	new Screen_BatchEdit ('$prefix');
});
EOJ

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
		$self->{session}->xml->dispose( $name );
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

	my $prefix = $self->get_subtype . "_change_";

	my @uuids = map { /^$prefix(.+)$/ ? $1 : () } $session->param;

	my %fields = map { $_->get_name => $_ } $self->get_fields( $dataset );

	foreach my $uuid (@uuids)
	{
		my $name = $session->param( $prefix . $uuid );
		next if !EPrints::Utils::is_set( $name );
		my $action = $session->param( $uuid . "_action" );
		next if !EPrints::Utils::is_set( $action );
		my $field = $fields{$name};
		next if !defined $field;
		do {
			local $field->{multiple} = 0;
			my $value = $field->form_value( $session, undef, $uuid );
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

	my $prefix = $self->get_subtype;

	my $dataset = $searchexp->get_dataset;

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	$div = $session->make_element( "div", id => "${prefix}_changes" );
	$page->appendChild( $div );

	$page->appendChild( $div = $session->make_element( "div" ) );

	my $select = $session->make_element( "select", id => "${prefix}_field_name" );
	$div->appendChild( $select );

	foreach my $field ($self->get_fields( $dataset ))
	{
		my $option = $session->make_element( "option", value => $field->get_name );
		$select->appendChild( $option );

		$option->appendChild( $field->render_name( $session ) );
	}

	$div->appendChild( $session->xhtml->action_button(
			add_change => $self->phrase( "action:add" ),
			id => join('_', $self->get_subtype, "action_add_change"),
		) );

	$page->appendChild( $session->xhtml->action_button(
			edit => $self->phrase( "action:edit" ),
			id => join('_', $self->get_subtype, "action_edit"),
		) );

	return $page;
}

sub render_remove_form
{
	my( $self, $searchexp ) = @_;

	my $processor = $self->{processor};
	my $session = $processor->{session};

	my( $page, $p, $div, $link );

	$page = $session->make_doc_fragment;

	$div = $session->make_element( "div", class => "ep_block" );
	$page->appendChild( $div );

	$div->appendChild( $self->html_phrase( "remove_help" ) );

	$div = $session->make_element( "div", class => "ep_block" );
	$page->appendChild( $div );

	$div->appendChild( $session->xhtml->action_button(
			remove => $session->phrase( "lib/submissionform:action_remove" ),
			id => join('_', $self->get_subtype, "action_remove"),
			_phrase => $self->phrase( "confirm_remove" ),
		) );

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

