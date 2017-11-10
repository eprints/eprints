=head1 NAME

EPrints::Plugin::InputForm::Component::Documents

=cut

package EPrints::Plugin::InputForm::Component::Documents;

use EPrints::Plugin::InputForm::Component;
@ISA = ( "EPrints::Plugin::InputForm::Component" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "Documents";
	$self->{visible} = "all";
	$self->{surround} = "None" unless defined $self->{surround};
	# a list of documents to unroll when rendering, 
	# this is used by the POST processing, not GET

	return $self;
}

sub wishes_to_export
{
	my( $self ) = @_;

	return $self->{session}->param( $self->{prefix} . "_export" );
}

# only returns a value if it belongs to this component
sub update_from_form
{
	my( $self, $processor ) = @_;

	my $session = $self->{session};
	my $eprint = $self->{workflow}->{item};
	# cache documents
	$eprint->set_value( "documents", $eprint->value( "documents" ) );
	my @eprint_docs = $eprint->get_all_documents;

	my %update = map { $_ => 1 } $session->param( $self->{prefix} . "_update_doc" );

	# update the metadata for any documents that have metadata
	foreach my $doc ( @eprint_docs )
	{
		# check the page we're coming from included this document
		next if !$update{$doc->id};

		my $doc_prefix = $self->{prefix}."_doc".$doc->id;

		my @fields = $self->doc_fields( $doc );

		foreach my $field ( @fields )
		{
			my $value = $field->form_value( 
				$session, 
				$doc,
				$doc_prefix );
			$doc->set_value( $field->{name}, $value );
		}

		$doc->commit;
	}
	
	if( $session->internal_button_pressed )
	{
		my $internal = $self->get_internal_button;
		if( $internal && $internal =~ m/^doc(\d+)_(.+)$/ )
		{
			my( $docid, $doc_action ) = ($1, $2);
			my $doc = $session->dataset( "document" )->dataobj( $docid );
			if( !defined $doc || $doc->value( "eprintid" ) ne $eprint->id )
			{
				$processor->add_message( "error", $self->html_phrase( "no_document", docid => $session->make_text($docid) ) );
				return;
			}
			$self->_doc_action( $processor, $doc, $doc_action );
			return;
		}
		# reorder by dragging/dropping
		elsif( $internal eq "reorder" )
		{
			$self->_reorder( $processor );
		}
	}

	return;
}

sub get_state_params
{
	my( $self, $processor ) = @_;

	my $params = "";

	my $to_unroll = $processor->{notes}->{upload_plugin}->{to_unroll};
	$to_unroll = {} if !defined $to_unroll;

	my %update = map { $_ => 1 } $self->{session}->param( $self->{prefix} . "_update_doc" );

	my $eprint = $self->{workflow}->{item};
	my @eprint_docs = $eprint->get_all_documents;
	foreach my $doc ( @eprint_docs )
	{
		my $doc_prefix = $self->{prefix}."_doc".$doc->id;

		# check the page we're coming from included this document
		next if !$update{$doc->id};

		my @fields = $self->doc_fields( $doc );
		foreach my $field ( @fields )
		{
			$params .= $field->get_state_params( $self->{session}, $doc_prefix );
			if( $field->has_internal_action( $doc_prefix ) )
			{
				$to_unroll->{$doc->id} = 1;
			}
		}
	}

	foreach my $docid (keys %$to_unroll)
	{
		$params .= "&$self->{prefix}_view=$docid";
	}

	return $params;
}

sub get_state_fragment
{
	my( $self, $processor ) = @_;

	my $to_unroll = $processor->{notes}->{upload_plugin}->{to_unroll};
	$to_unroll = {} if !defined $to_unroll;

	my %update = map { $_ => 1 } $self->{session}->param( $self->{prefix} . "_update_doc" );

	my $eprint = $self->{workflow}->{item};
	foreach my $doc ( $eprint->get_all_documents )
	{
		my $doc_prefix = $self->{prefix}."_doc".$doc->id;
		return $doc_prefix if $to_unroll->{$doc->id};

		# check the page we're coming from included this document
		next if !$update{$doc->id};

		my @fields = $self->doc_fields( $doc );
		foreach my $field ( @fields )
		{
			if( $field->has_internal_action( $doc_prefix ) )
			{
				return $doc_prefix;
			}
		}
	}

	return "";
}

sub _doc_action
{
	my( $self, $processor, $doc, $doc_internal ) = @_;

	local $processor->{document} = $doc;
	my $plugin;
	foreach my $params ($processor->screen->action_list( "document_item_actions" ))
	{
		$plugin = $params->{screen}, last
			if $params->{screen}->get_subtype eq $doc_internal;
	}
	return if !defined $plugin;

	my $return_to = URI->new( $self->{session}->current_url( host => 1 ) );
	$return_to->query_form(
		$processor->screen->hidden_bits
	);

	if( $plugin->param( "ajax" ) && $self->wishes_to_export )
	{
		$self->set_note( "document", $doc );
		$self->set_note( "action", $plugin );
		$self->set_note( "return_to", $return_to );
		return;
	}

	$return_to->query_form(
		screen => $plugin->get_subtype,
		eprintid => $self->{workflow}->{item}->id,
		documentid => $doc->id,
		return_to => $return_to->query,
	);

	$processor->{redirect} = $return_to;
}

sub _reorder
{
	my( $self, $processor ) = @_;

	my @order = $self->{session}->param( join('_',$self->{prefix},'order') );
	return if !@order;

	my @docs = $self->{workflow}->{item}->get_all_documents;
	my %docids = map { $_->id => 1 } @docs;

	@order = grep { $docids{$_} } @order;
	return if !@order;

	my $i = 1;
	my %order = map { $_ => $i++ } @order;

	foreach my $doc (@docs)
	{
		$doc->set_value( "placement", $order{$doc->id} || $i++ );
		$doc->commit;
	}
}

sub has_help
{
	my( $self, $surround ) = @_;
	return $self->{session}->get_lang->has_phrase( $self->html_phrase_id( "help" ) );
}

# hmmm. May not be true!
sub is_required { 0 }

sub get_fields_handled { qw( documents ) }

sub render_content
{
	my( $self, $surround ) = @_;
	
	my $session = $self->{session};
	my $eprint = $self->{workflow}->{item};
	# cache documents
	$eprint->set_value( "documents", $eprint->value( "documents" ) );

	my $f = $session->make_doc_fragment;
	
	$f->appendChild( $self->{session}->make_javascript(
		"Event.observe(window, 'load', function() { new Component_Documents('".$self->{prefix}."') });"
	) );

	my @docs = $eprint->get_all_documents;

	my %unroll = map { $_ => 1 } $session->param( $self->{prefix}."_view" );

	# this overrides the prefix-dependent view. It's used when
	# we're coming in from outside the form and is, to be honest,
	# a dirty little hack.
	if( defined(my $docid = $session->param( "docid" ) ) )
	{
		$unroll{$docid} = 1;
	}

	my $panel = $session->make_element( "div",
		id=>$self->{prefix}."_panels",
	);
	$f->appendChild( $panel );

	foreach my $doc ( @docs )
	{
		my $hide = @docs > 1 && !$unroll{$doc->id};

		$panel->appendChild( $self->_render_doc_div( $doc, $hide ));
	}

	return $f;
}

sub export_mimetype
{
	my( $self ) = @_;

	my $plugin = $self->note( "action" );
	if( defined($plugin) && $plugin->param( "ajax" ) eq "automatic" )
	{
		return $plugin->export_mimetype;
	}

	return $self->SUPER::export_mimetype();
}

sub export
{
	my( $self ) = @_;

	my $frag;

	if( defined(my $plugin = $self->note( "action" )) )
	{
		local $self->{processor}->{document} = $self->note( "document" );
		if( $plugin->param( "ajax" ) eq "automatic" )
		{
			$plugin->from; # call actions
			delete $self->{processor}->{redirect}; # exports don't redirect
			return $plugin->export; # generate the export
		}
		local $self->{processor}->{return_to} = $self->note( "return_to" );
		$frag = $plugin->render;
	}
	else
	{
		my $docid = $self->{session}->param( $self->{prefix} . '_export' );
		return unless $docid;

		my $doc = $self->{session}->dataset( "document" )->dataobj( $docid );
		return $self->{session}->not_found if !defined $doc;

		return if $doc->value( "eprintid" ) != $self->{workflow}->{item}->id;

		my $hide = $self->{session}->param( "docid" );
		$hide = !defined($hide) || $hide ne $docid;
		$frag = $self->_render_doc_div( $doc, $hide );
	}

	print $self->{session}->xhtml->to_xhtml( $frag );
	$self->{session}->xml->dispose( $frag );
}

sub _render_doc_div 
{
	my( $self, $doc, $hide ) = @_;

	my $session = $self->{session};

	my $docid = $doc->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $imagesurl = $session->current_url( path => "static" );

	my $files = $doc->get_value( "files" );
	do {
		my %idx = map { $_ => $_->value( "filename" ) } @$files;
		@$files = sort { $idx{$a} cmp $idx{$b} } @$files;
	};

	my $doc_div = $self->{session}->make_element( "div", class=>"ep_upload_doc", id=>$doc_prefix."_block" );

	# provide <a> link to this document
	$doc_div->appendChild( $session->make_element( "a", name=>$doc_prefix ) );

	# note which documents should be updated
	$doc_div->appendChild( $session->render_hidden_field( $self->{prefix}."_update_doc", $docid ) );

	# note the document placement
	$doc_div->appendChild( $session->render_hidden_field( $self->{prefix}."_doc_placement", $doc->value( "placement" ) ) );

	my $doc_title_bar = $session->make_element( "div", class=>"ep_upload_doc_title_bar" );
	$doc_div->appendChild( $doc_title_bar );

	my $doc_expansion_bar = $session->make_element( "div", class=>"ep_upload_doc_expansion_bar ep_only_js" );
	$doc_div->appendChild( $doc_expansion_bar );

	my $content = $session->make_element( "div", id=>$doc_prefix."_opts", class=>"ep_upload_doc_content ".($hide?"ep_no_js":"") );
	$doc_div->appendChild( $content );


	my $table = $session->make_element( "table", width=>"100%", border=>0 );
	my $tr = $session->make_element( "tr" );
	$doc_title_bar->appendChild( $table );
	$table->appendChild( $tr );
	my $td_left = $session->make_element( "td", align=>"left", valign=>"middle", width=>"60%" );
	$tr->appendChild( $td_left );

	$td_left->appendChild( $self->_render_doc_icon_info( $doc, $files ) );

	my $td_right = $session->make_element( "td", align=>"right", valign=>"middle", class => "ep_upload_doc_actions" );
	$tr->appendChild( $td_right );

	$td_right->appendChild( $self->_render_doc_actions( $doc ) );

        my @fields = $self->doc_fields( $doc );
        return $doc_div if !scalar @fields;

	my $opts_toggle = $session->make_element( "a", onclick => "EPJS_blur(event); EPJS_toggleSlideScroll('${doc_prefix}_opts',".($hide?"false":"true").",'${doc_prefix}_block');EPJS_toggle('${doc_prefix}_opts_hide',".($hide?"false":"true").",'block');EPJS_toggle('${doc_prefix}_opts_show',".($hide?"true":"false").",'block');return false" );
	$doc_expansion_bar->appendChild( $opts_toggle );

	my $s_options = $session->make_element( "div", id=>$doc_prefix."_opts_show", class=>"ep_update_doc_options ".($hide?"":"ep_hide") );
	$s_options->appendChild( $self->html_phrase( "show_options" ) );
	$s_options->appendChild( $session->make_text( " " ) );
	$s_options->appendChild( 
			$session->make_element( "img",
				src=>"$imagesurl/style/images/plus.png",
				) );
	$opts_toggle->appendChild( $s_options );

	my $h_options = $session->make_element( "div", id=>$doc_prefix."_opts_hide", class=>"ep_update_doc_options ".($hide?"ep_hide":"") );
	$h_options->appendChild( $self->html_phrase( "hide_options" ) );
	$h_options->appendChild( $session->make_text( " " ) );
	$h_options->appendChild( 
			$session->make_element( "img",
				src=>"$imagesurl/style/images/minus.png",
				) );
	$opts_toggle->appendChild( $h_options );


	my $content_inner = $self->{session}->make_element( "div", id=>$doc_prefix."_opts_inner" );
	$content->appendChild( $content_inner );

	$content_inner->appendChild( $self->_render_doc_metadata( $doc )->{content} );
	return $doc_div;
}

sub _render_doc_icon_info
{
	my( $self, $doc, $files ) = @_;

	my $session = $self->{session};

	my $table = $session->make_element( "table", border=>0 );
	my $tr = $session->make_element( "tr" );
	my $td_left = $session->make_element( "td", align=>"center" );
	my $td_right = $session->make_element( "td", align=>"left", class=>"ep_upload_doc_title" );
	$table->appendChild( $tr );
	$tr->appendChild( $td_left );
	$tr->appendChild( $td_right );

	$td_left->appendChild( $doc->render_icon_link( new_window=>1, preview=>1, public=>0 ) );

	$td_right->appendChild( $doc->render_citation );
	my $size = 0;
	foreach my $file (@$files)
	{
		$size += $file->value( "filesize" );
	}
	if( $size > 0 )
	{
		$td_right->appendChild( $session->make_element( 'br' ) );
		$td_right->appendChild( $session->make_text( EPrints::Utils::human_filesize($size) ));
	}

	return $table;
}

sub _render_doc_actions
{
	my( $self, $doc ) = @_;

	my $session = $self->{session};

	my $doc_prefix = $self->{prefix}."_doc".$doc->id;

	my $table = $session->make_element( "table" );

	my( $tr, $td );

	$tr = $session->make_element( "tr" );
	$table->appendChild( $tr );

	my $screen = $self->{processor}->screen;
	my $uri = URI->new( 'http:' );
	$uri->query_form( $screen->hidden_bits );

	# allow document actions to test the document for viewing
	local $self->{processor}->{document} = $doc;

	foreach my $params ($screen->action_list( "document_item_actions" ))
	{
		$td = $session->make_element( "td" );
		$tr->appendChild( $td );

		my $aux = $params->{screen};
		my $action = $params->{action};
		my $name = "_internal_".$doc_prefix."_".$aux->get_subtype;
		my $title = $action ? $aux->phrase( "action:$action:title" ) : $aux->phrase( "title" );
		my $icon = $action ? $aux->action_icon_url( $action ) : $aux->icon_url;
		my $input = $td->appendChild(
			$session->make_element( "input",
				type => "image",
				class => "ep_form_action_icon",
				name => $name,
				src => $icon,
				title => $title,
				alt => $title,
				value => $title,
				rel => ($aux->param( "ajax" ) ? $aux->param( "ajax" ) : "") ) );
	}

	return $table;
}

sub _render_related_docs
{
	my( $self, $doc ) = @_;

	my $session = $self->{session};
	my $eprint = $self->{workflow}->{item};

	my $div = $session->make_element( "div", id=>$self->{prefix}."_panels" );

	$doc->search_related( "isVolatileVersionOf" )->map(sub {
			my( undef, undef, $dataobj ) = @_;

			# in the future we might get other objects coming back
			next if !$dataobj->isa( "EPrints::DataObj::Document" );

			$div->appendChild( $self->_render_volatile_div( $dataobj ) );
		});

	if( !$div->hasChildNodes )
	{
		return ();
	}

	return {
		id => "related_".$doc->id,
		   title => $self->html_phrase("related_files"),
		   content => $div,
	};
}

sub _render_volatile_div
{
	my( $self, $doc ) = @_;

	my $session = $self->{session};

	my $doc_prefix = $self->{prefix}."_doc".$doc->id;

	my $doc_div = $self->{session}->make_element( "div", class=>"ep_upload_doc", id=>$doc_prefix."_block" );

	my $doc_title_bar = $session->make_element( "div", class=>"ep_upload_doc_title_bar" );

	my $table = $session->make_element( "table", width=>"100%", border=>0 );
	my $tr = $session->make_element( "tr" );
	$doc_title_bar->appendChild( $table );
	$table->appendChild( $tr );
	my $td_left = $session->make_element( "td", valign=>"middle" );
	$tr->appendChild( $td_left );

	$td_left->appendChild( $self->_render_doc_icon_info(
			$doc,
			[] # $doc->value( "files" )
		) );

	my $td_right = $session->make_element( "td", align=>"right", valign=>"middle", width=>"20%" );
	$tr->appendChild( $td_right );
	my $msg = $self->phrase( "unlink_document_confirm" );
	my $unlink_button = $session->render_button(
			name => "_internal_".$doc_prefix."_unlink_doc",
			value => $self->phrase( "unlink_document" ),
			class => "ep_form_internal_button",
			onclick => "if( window.event ) { window.event.cancelBubble = true; } return confirm(".EPrints::Utils::js_string($msg).");",
			);
	$td_right->appendChild($unlink_button);
	$doc_div->appendChild( $doc_title_bar );

	return $doc_div;
}

sub doc_fields
{
	my( $self, $document ) = @_;

	return @{$self->{config}->{doc_fields}};
}

sub _render_doc_metadata
{
	my( $self, $doc ) = @_;

	my $session = $self->{session};	

	my @fields = $self->doc_fields( $doc );

	return () if !scalar @fields;

	my $doc_cont = $session->make_element( "div" );

	my $docid = $doc->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $table = $session->make_element( "table", class=>"ep_upload_fields ep_multi" );
	$doc_cont->appendChild( $table );
	my $first = 1;
	foreach my $field ( @fields )
	{
		my $label = $field->render_name($session);
		if( $field->{required} ) # moj: Handle for_archive
		{
			$label = $self->{session}->html_phrase( 
				"sys:ep_form_required",
				label=>$label );
		}

		$table->appendChild( $session->render_row_with_help(
			label=>$label,
			field=>$field->render_input_field(
								$session,
								$doc->get_value( $field->get_name ),
								undef,
								0,
								undef,
								$doc,
								$doc_prefix ),
			help=>$field->render_help($session),
			help_prefix=>$doc_prefix."_".$field->get_name."_help",
			no_toggle=>$self->{no_toggle}
		));
		$first = 0;
	}

	my $tool_div = $session->make_element( "div", class=>"ep_upload_doc_toolbar" );

	my $update_button = $session->render_button(
		name => "_internal_".$doc_prefix."_update_doc",
		value => $self->phrase( "update" ), 
		class => "ep_form_internal_button",
		);
	$tool_div->appendChild( $update_button );

	$doc_cont->appendChild( $tool_div );
	
	return ({
		id => "metadata_".$doc->get_id,
		   title => $self->html_phrase("Metadata"),
		   content => $doc_cont,
	});
}

sub validate
{
	my( $self ) = @_;
	
	my @problems = ();

	my $for_archive = $self->{workflow}->{for_archive};

	my $eprint = $self->{workflow}->{item};
	my $session = $self->{session};
	
	push @problems, $eprint->validate_field( "documents" );

	# legacy, use a field_validate.pl
	my @req_formats;
	if( defined(my $f = $session->config( "required_formats" )) )
	{
		if( ref($f) eq "CODE" )
		{
			push @req_formats, &$f( $eprint );
		}
		else
		{
			push @req_formats, @$f;
		}
	}
	my @docs = $eprint->get_all_documents;

	my $ok = 0;
	$ok = 1 if( scalar @req_formats == 0 );

	my $doc;
	foreach $doc ( @docs )
	{
		my $docformat = $doc->get_value( "format" );
		foreach( @req_formats )
		{
			$ok = 1 if( $docformat eq $_ );
		}
	}

	if( !$ok )
	{
		my $doc_ds = $session->dataset( "document" );
		my $fieldname = $session->make_element( "span", class=>"ep_problem_field:documents" );
		my $prob = $session->make_doc_fragment;
		$prob->appendChild( $session->html_phrase( 
			"lib/eprint:need_a_format",
			fieldname=>$fieldname ) );
		my $ul = $session->make_element( "ul" );
		$prob->appendChild( $ul );
		
		foreach( @req_formats )
		{
			my $li = $session->make_element( "li" );
			$ul->appendChild( $li );
			$li->appendChild( $session->render_type_name( "document", $_ ) );
		}
			
		push @problems, $prob;
	}

	foreach $doc (@docs)
	{
		my $probs = $doc->validate( $for_archive );

		foreach my $field ( @{$self->{config}->{doc_fields}} )
		{
			my $for_archive = defined($field->{required}) &&
				$field->{required} eq "for_archive";

			# cjg bug - not handling for_archive here.
			if( $field->{required} && !$doc->is_set( $field->{name} ) )
			{
				my $fieldname = $session->make_element( "span", class=>"ep_problem_field:documents" );
				$fieldname->appendChild( $field->render_name( $self->{session} ) );
				my $problem = $session->html_phrase(
					"lib/eprint:not_done_field" ,
					fieldname=>$fieldname );
				push @{$probs}, $problem;
			}
			
			push @{$probs}, $doc->validate_field( $field->{name} );
		}

		foreach my $doc_problem (@$probs)
		{
			my $prob = $self->html_phrase( "document_problem",
					document => $doc->render_description,
					problem =>$doc_problem );
			push @problems, $prob;
		}
	}

	return @problems;
}

sub parse_config
{
	my( $self, $config_dom ) = @_;

	$self->{config}->{doc_fields} = [];

	my @fields = $config_dom->getElementsByTagName( "field" );

	my $doc_ds = $self->{session}->get_dataset( "document" );

	foreach my $field_tag ( @fields )
	{
		my $field = $self->xml_to_metafield( $field_tag, $doc_ds );
		return if !defined $field;
		push @{$self->{config}->{doc_fields}}, $field;
	}
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

