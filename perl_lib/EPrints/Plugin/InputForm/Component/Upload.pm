package EPrints::Plugin::InputForm::Component::Upload;

use EPrints;
use EPrints::Plugin::InputForm::Component;
@ISA = ( "EPrints::Plugin::InputForm::Component" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "Upload";
	$self->{visible} = "all";
	$self->{surround} = "None" unless defined $self->{surround};
	return $self;
}

# only returns a value if it belongs to this component
sub update_from_form
{
	my( $self, $processor ) = @_;

	my $eprint = $self->{workflow}->{item};
	my @eprint_docs = $eprint->get_all_documents;

	foreach my $doc ( @eprint_docs )
	{	
		my @fields = $self->doc_fields( $doc );
		my $docid = $doc->get_id;
		my $doc_prefix = $self->{prefix}."_doc".$docid;
		foreach my $field ( @fields )
		{
			my $value = $field->form_value( 
				$self->{session}, 
				$self->{dataobj}, 
				$doc_prefix );
			$doc->set_value( $field->{name}, $value );
		}
		$doc->commit;
	}

	if( $self->{session}->internal_button_pressed )
	{
		my $internal = $self->get_internal_button;

		if( $internal eq "add_format" )
		{
			my $doc_data = { eprintid => $self->{dataobj}->get_id };

			my $repository = $self->{session}->get_repository;
			$doc_data->{format} = $repository->call( 'guess_doc_type', 
				$self->{session},
				$self->{session}->param( $self->{prefix}."_first_file" ) );

			my $doc_ds = $self->{session}->get_repository->get_dataset( 'document' );
			my $document = $doc_ds->create_object( $self->{session}, $doc_data );
			if( !defined $document )
			{
				$processor->add_message( "error", $self->html_phrase( "create_failed" ) );
				return;
			}
			my $success = EPrints::Apache::AnApache::upload_doc_file( 
				$self->{session},
				$document,
				$self->{prefix}."_first_file" );
			if( !$success )
			{
				$document->remove();
				$processor->add_message( "error", $self->html_phrase( "upload_failed" ) );
				return;
			}
			return;
		}

		if( $internal eq "add_format_zip" )
		{
			my $doc_data = { eprintid => $self->{dataobj}->get_id, format=>"other" };

			my $repository = $self->{session}->get_repository;

			my $doc_ds = $self->{session}->get_repository->get_dataset( 'document' );
			my $document = $doc_ds->create_object( $self->{session}, $doc_data );
			if( !defined $document )
			{
				$processor->add_message( "error", $self->html_phrase( "create_failed" ) );
				return;
			}
			my $success = EPrints::Apache::AnApache::upload_doc_archive( 
				$self->{session},
				$document,
				$self->{prefix}."_first_file_zip",
				"zip" );
			if( !$success )
			{
				$document->remove();
				$processor->add_message( "error", $self->html_phrase( "upload_failed" ) );
				return;
			}
			return;
		}

		if( $internal eq "add_format_targz" )
		{
			my $doc_data = { eprintid => $self->{dataobj}->get_id, format=>"other" };

			my $repository = $self->{session}->get_repository;

			my $doc_ds = $self->{session}->get_repository->get_dataset( 'document' );
			my $document = $doc_ds->create_object( $self->{session}, $doc_data );
			if( !defined $document )
			{
				$processor->add_message( "error", $self->html_phrase( "create_failed" ) );
				return;
			}
			my $success = EPrints::Apache::AnApache::upload_doc_archive( 
				$self->{session},
				$document,
				$self->{prefix}."_first_file_targz",
				"targz" );
			if( !$success )
			{
				$document->remove();
				$processor->add_message( "error", $self->html_phrase( "upload_failed" ) );
				return;
			}
			return;
		}

		if( $internal eq "add_format_fromurl" )
		{
			my $doc_data = { eprintid => $self->{dataobj}->get_id, format=>"other" };

			my $repository = $self->{session}->get_repository;

			my $doc_ds = $self->{session}->get_repository->get_dataset( 'document' );
			my $document = $doc_ds->create_object( $self->{session}, $doc_data );
			if( !defined $document )
			{
				$processor->add_message( "error", $self->html_phrase( "create_failed" ) );
				return;
			}
			my $success = $document->upload_url( $self->{session}->param( $self->{prefix}."_first_file_fromurl" ) );
			if( !$success )
			{
				$document->remove();
				$processor->add_message( "error", $self->html_phrase( "upload_failed" ) );
				return;
			}

			$document->set_value( "format", $repository->call( 'guess_doc_type', 
				$self->{session},
				$document->get_value( "main" ) ) );
			$document->commit;

			return;
		}

		if( $internal =~ m/^doc(\d+)_(.*)$/ )
		{
			my $doc = EPrints::DataObj::Document->new(
				$self->{session},
				$1 );
			if( !defined $doc )
			{
				$processor->add_message( "error", $self->html_phrase( "no_document", docid => $self->{session}->make_text($1) ) );
				return;
			}
			if( $doc->get_value( "eprintid" ) != $self->{dataobj}->get_id )
			{
				$processor->add_message( "error", $self->html_phrase( "bad_document" ) );
				return;
			}
			$self->doc_update( $doc, $2, $processor );
			return;
		}

		$processor->add_message( "error",$self->html_phrase( "bad_button", button => $self->{session}->make_text($internal) ));
		return;
	}

	return;
}

sub doc_update
{
	my( $self, $doc, $doc_internal, $processor ) = @_;

	my $docid = $doc->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;
	
	if( $doc_internal eq "update_doc" )
	{
		return;
	}

	if( $doc_internal eq "delete_doc" )
	{
		$doc->remove();
		return;
	}

	if( $doc_internal eq "add_file" )
	{
		my $success = EPrints::Apache::AnApache::upload_doc_file( 
			$self->{session},
			$doc,
			$doc_prefix."_file" );
		if( !$success )
		{
			$processor->add_message( "error", $self->html_phrase( "upload_failed" ) );
			return;
		}
		return;
	}

	if( $doc_internal =~ m/^delete_(\d+)$/ )
	{
		my $fileid = $1;
		
		my %files_unsorted = $doc->files();
		my @files = sort keys %files_unsorted;

		if( !defined $files[$fileid] )
		{
			$processor->add_message( "error", $self->html_phrase( "no_file" ) );
			return;
		}
		
		$doc->remove_file( $files[$fileid] );
		return;
	}

	if( $doc_internal eq "convert_document" )
	{
		my $eprint = $self->{workflow}->{item};
		my $target = $self->{session}->param( $doc_prefix . "_convert_to" );
		$target ||= '-';
		my( $plugin_id, $type ) = split /-/, $target, 2;
		my $plugin = $self->{session}->plugin( $plugin_id );
		if( !$plugin )
		{
			$processor->add_message( "error", $self->html_phrase( "plugin_error" ) );
			return;
		}
		my $new_doc = $plugin->convert( $eprint, $doc, $type );
		if( !$new_doc )
		{
			$processor->add_message( "error", $self->html_phrase( "conversion_failed" ) );
			return;
		}
		return;
	}

	if( $doc_internal =~ m/^main_(\d+)$/ )
	{
		my $fileid = $1;

		my %files_unsorted = $doc->files();
		my @files = sort keys %files_unsorted;

		if( !defined $files[$fileid] )
		{
			$processor->add_message( "error", $self->html_phrase( "no_file" ) );
			return;
		}
		
		# Pressed "Show First" button for this file
		$doc->set_main( $files[$fileid] );
		$doc->commit;
		return ();
	}
			
	$processor->add_message( "error", $self->html_phrase( "bad_doc_button", button => $self->{session}->make_text($doc_internal) ) );
}
	
sub render_help
{
	my( $self, $surround ) = @_;
	return $self->html_phrase( "help" );
}

sub render_title
{
	my( $self, $surround ) = @_;
	return $self->html_phrase( "title" );
}

# hmmm. May not be true!
sub is_required
{
	my( $self ) = @_;
	return 1;
}

sub get_fields_handled
{
	my( $self ) = @_;

	return ( "documents" );
}

sub render_content
{
	my( $self, $surround ) = @_;
	
	my $session = $self->{session};
	my $f = $session->make_doc_fragment;
	
	$f->appendChild( $self->_render_add_document );	

	my $eprint = $self->{workflow}->{item};
	my @eprint_docs = $eprint->get_all_documents;

	if( ! scalar @eprint_docs )
	{
		return $f;
	}

	my $view = $session->param( $self->{prefix}."_view" );

	# this overrides the prefix-dependent view. It's used when
	# we're coming in from outside the form and is, to be honest,
	# a dirty little hack.
	if( defined $session->param( "docid" ) )
	{
		$view = $session->param( "docid" );
	}

	my $affected_doc_id;
	my $internal = $self->get_internal_button;
	if( $internal =~ m/^doc(\d+)_(.*)$/ )
	{
		$affected_doc_id = $1;
	}

	my $panel = $self->{session}->make_element( "div", id=>$self->{prefix}."_panels" );
	$f->appendChild( $panel );

	my $imagesurl = $session->get_repository->get_conf( "rel_path" );

	# sort by doc id?	
	foreach my $doc ( @eprint_docs )
	{	
		my $view_id = $doc->get_id;
		my $doc_prefix = $self->{prefix}."_doc".$view_id;
		my $hide = 1;
		if( scalar @eprint_docs == 1 ) { $hide = 0; } 
		if( $view_id eq $view ) { $hide = 0; }	
		if( defined $affected_doc_id && $view_id eq $affected_doc_id ) { $hide = 0; }
		my $doc_div = $self->{session}->make_element( "div", class=>"ep_upload_doc", id=>$doc_prefix."_block" );
		$panel->appendChild( $doc_div );
		my $doc_title_bar = $session->make_element( "div", class=>"ep_upload_doc_title_bar" );


		my $table = $session->make_element( "table", width=>"100%", border=>0 );
		my $tr = $session->make_element( "tr" );
		$doc_title_bar->appendChild( $table );
		$table->appendChild( $tr );
		my $td_left = $session->make_element( "td", align=>"left" );
		$tr->appendChild( $td_left );

		my $table_left = $session->make_element( "table", border=>0 );
		$td_left->appendChild( $table_left );
		my $table_left_tr = $session->make_element( "tr" );
		my $table_left_td_left = $session->make_element( "td", align=>"center" );
		my $table_left_td_right = $session->make_element( "td", align=>"left", class=>"ep_upload_doc_title" );
		$table_left->appendChild( $table_left_tr );
		$table_left_tr->appendChild( $table_left_td_left );
		$table_left_tr->appendChild( $table_left_td_right );
		
		$table_left_td_left->appendChild( $doc->render_icon_link( new_window=>1, preview=>1, public=>0 ) );

		$table_left_td_right->appendChild( $doc->render_citation);
		my %files = $doc->files;
		if( defined $files{$doc->get_main} )
		{
			my $size = $files{$doc->get_main};
			$table_left_td_right->appendChild( $session->make_element( 'br' ) );
			$table_left_td_right->appendChild( $session->make_text( EPrints::Utils::human_filesize($size) ));
		}

		my $td_right = $session->make_element( "td", align=>"right", valign=>"middle" );
		$tr->appendChild( $td_right );

		my $options = $session->make_element( "div", class=>"ep_update_doc_options ep_only_js" );
		my $opts_toggle = $session->make_element( "a", onclick => "EPJS_blur(event); EPJS_toggleSlideScroll('${doc_prefix}_opts',".($hide?"false":"true").",'${doc_prefix}_block');EPJS_toggle('${doc_prefix}_opts_hide',".($hide?"false":"true").",'block');EPJS_toggle('${doc_prefix}_opts_show',".($hide?"true":"false").",'block');return false", href=>"#" );
		$options->appendChild( $opts_toggle );
		$td_right->appendChild( $options );

		my $s_options = $session->make_element( "span", id=>$doc_prefix."_opts_show", class=>"ep_update_doc_options ".($hide?"":"ep_hide") );
		$s_options->appendChild( $self->html_phrase( "show_options" ) );
		$s_options->appendChild( $session->make_text( " " ) );
		$s_options->appendChild( 
			$session->make_element( "img",
				src=>"$imagesurl/style/images/plus.png",
				) );
		$opts_toggle->appendChild( $s_options );

		my $h_options = $session->make_element( "span", id=>$doc_prefix."_opts_hide", class=>"ep_update_doc_options ".($hide?"ep_hide":"") );
		$h_options->appendChild( $self->html_phrase( "hide_options" ) );
		$h_options->appendChild( $session->make_text( " " ) );
		$h_options->appendChild( 
			$session->make_element( "img",
				src=>"$imagesurl/style/images/minus.png",
				) );
		$opts_toggle->appendChild( $h_options );


		#$doc_title->appendChild( $doc->render_description );
		$doc_div->appendChild( $doc_title_bar );
	
		my $content = $session->make_element( "div", id=>$doc_prefix."_opts", class=>"ep_upload_doc_content ".($hide?"ep_no_js":"") );
		my $content_inner = $self->{session}->make_element( "div", id=>$doc_prefix."_opts_inner" );
		$content_inner->appendChild( $self->_render_doc( $doc ) );
		$content->appendChild( $content_inner );
		$doc_div->appendChild( $content );
	}
	
	return $f;
}

sub doc_fields
{
	my( $self, $document ) = @_;

	my $ds = $self->{session}->get_repository->get_dataset('document');
	my @fields = @{$self->{config}->{doc_fields}};

	my %files = $document->files;
	if( scalar keys %files > 1 )
	{
		push @fields, $ds->get_field( "main" );
	}
	
	return @fields;
}


sub _render_doc
{
	my( $self, $doc ) = @_;

	my $session = $self->{session};	

	my $doc_cont = $session->make_element( "div" );


	my $docid = $doc->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my @fields = $self->doc_fields( $doc );

	if( scalar @fields )
	{
		my $table = $session->make_element( "table", class=>"ep_upload_fields ep_multi" );
		$doc_cont->appendChild( $table );
		my $first = 1;
		foreach my $field ( @fields )
		{
			$table->appendChild( $session->render_row_with_help(
				class=>($first?"ep_first":""),
				label=>$field->render_name($session),
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
			));
			$first = 0;
		}
	}

	my $tool_div = $session->make_element( "div", class=>"ep_upload_doc_toolbar" );

	my $update_button = $session->render_button(
		name => "_internal_".$doc_prefix."_update_doc",
		value => $self->phrase( "update" ), 
		class => "ep_form_internal_button",
		);
	$tool_div->appendChild( $update_button );

	my $msg = $self->phrase( "delete_document_confirm" );
	my $delete_fmt_button = $session->render_button(
		name => "_internal_".$doc_prefix."_delete_doc",
		value => $self->phrase( "delete_document" ), 
		class => "ep_form_internal_button",
		onclick => "if( window.event ) { window.event.cancelBubble = true; } return confirm(".EPrints::Utils::js_string($msg).");",
		);
	$tool_div->appendChild( $delete_fmt_button );

	$doc_cont->appendChild( $tool_div );



	my $files = $session->make_element( "div", class=>"ep_upload_files" );
	$doc_cont->appendChild( $files );
	$files->appendChild( $self->_render_filelist( $doc ) );
	my $block = $session->make_element( "div", class=>"ep_block" );
	$block->appendChild( $self->_render_add_file( $doc ) );
	$doc_cont->appendChild( $block );
	$block = $session->make_element( "div", class=>"ep_block" );
	$block->appendChild( $self->_render_convert_document( $doc ) );
	$doc_cont->appendChild( $block );

	return $doc_cont;
}
			

sub _render_add_document
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $add = $session->make_doc_fragment;

	my $tabs = [qw/ file zip targz fromurl /];	
	my $links = { file=>"", zip=>"", targz=>"", fromurl=>"" };
	my $labels = {
		file=>$session->make_text( "File" ), 
		zip=>$session->make_text( "Zip File" ), 
		targz=>$session->make_text( ".tar.gz File" ), 
		fromurl=>$session->make_text( "From URL" ), 
	};
	
	my $newdoc = $self->{session}->make_element( 
			"div", 
			class => "ep_upload_newdoc" );
	$add->appendChild( $newdoc );
	my $tab_block = $session->make_element( "div", class=>"ep_only_js" );	
	$tab_block->appendChild( 
		$self->{session}->render_tabs( 
			id_prefix => $self->{prefix}."_upload",
			current => "file",
			tabs => $tabs,
			labels => $labels,
			links => $links,
		));
	$newdoc->appendChild( $tab_block );
		
	my $panel = $self->{session}->make_element( 
			"div", 
			id => $self->{prefix}."_upload_panels", 
			class => "ep_tab_panel" );
	$newdoc->appendChild( $panel );

##############
{
	my $inner_panel = $self->{session}->make_element( 
			"div", 
			id => $self->{prefix}."_upload_panel_file" );
	$panel->appendChild( $inner_panel );

	$inner_panel->appendChild( $self->html_phrase( "new_document" ) );

	my $ffname = $self->{prefix}."_first_file";	
	my $file_button = $session->make_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		);
	my $upload_progress_url = $session->get_url( path => "cgi" ) . "/users/lookup/upload_progress";
	my $onclick = "return startEmbeddedProgressBar(this.form,{'url':".EPrints::Utils::js_string( $upload_progress_url )."});";
	my $add_format_button = $session->render_button(
		value => $self->phrase( "add_format" ), 
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_add_format",
		onclick => $onclick );
	$inner_panel->appendChild( $file_button );
	$inner_panel->appendChild( $session->make_text( " " ) );
	$inner_panel->appendChild( $add_format_button );
	my $progress_bar = $session->make_element( "div", id => "progress" );
	$inner_panel->appendChild( $progress_bar );

	my $script = $session->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($self->phrase("really_next"))." ); } return true; } );" );
	$inner_panel->appendChild( $script);
}

$panel->appendChild( $session->make_element( "div", style=>"height: 1em", class=>"ep_no_js" ) );

{
	my $inner_panel = $self->{session}->make_element( 
			"div", 
			class => "ep_no_js",
			id => $self->{prefix}."_upload_panel_zip" );
	$panel->appendChild( $inner_panel );

	$inner_panel->appendChild( $session->make_text( "New document (from ZIP file): " ) );

	my $ffname = $self->{prefix}."_first_file_zip";	
	my $file_button = $session->make_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		);
	my $add_format_button = $session->render_button(
		value => $self->phrase( "add_format" ), 
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_add_format_zip" );
	$inner_panel->appendChild( $file_button );
	$inner_panel->appendChild( $session->make_text( " " ) );
	$inner_panel->appendChild( $add_format_button );

	my $script = $session->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($self->phrase("really_next"))." ); } return true; } );" );
	$inner_panel->appendChild( $script);
}

$panel->appendChild( $session->make_element( "div", style=>"height: 1em", class=>"ep_no_js" ) );

{
	my $inner_panel = $self->{session}->make_element( 
			"div", 
			class => "ep_no_js",
			id => $self->{prefix}."_upload_panel_targz" );
	$panel->appendChild( $inner_panel );

	$inner_panel->appendChild( $session->make_text( "New document (from .tar.gz file): " ));

	my $ffname = $self->{prefix}."_first_file_targz";	
	my $file_button = $session->make_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		);
	my $add_format_button = $session->render_button(
		value => $self->phrase( "add_format" ), 
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_add_format_targz" );
	$inner_panel->appendChild( $file_button );
	$inner_panel->appendChild( $session->make_text( " " ) );
	$inner_panel->appendChild( $add_format_button );

	my $script = $session->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($self->phrase("really_next"))." ); } return true; } );" );
	$inner_panel->appendChild( $script);
}

$panel->appendChild( $session->make_element( "div", style=>"height: 1em", class=>"ep_no_js" ) );

{
	my $inner_panel = $self->{session}->make_element( 
			"div", 
			class => "ep_no_js",
			id => $self->{prefix}."_upload_panel_fromurl" );
	$panel->appendChild( $inner_panel );

	$inner_panel->appendChild( $session->make_text( "Capture from URL: " ));

	my $ffname = $self->{prefix}."_first_file_fromurl";	
	my $file_button = $session->make_element( "input",
		name => $ffname,
		size => "30",
		id => $ffname,
		);
	my $add_format_button = $session->render_button(
		value => $self->phrase( "add_format" ), 
		class => "ep_form_internal_button",
		name => "_internal_".$self->{prefix}."_add_format_fromurl" );
	$inner_panel->appendChild( $file_button );
	$inner_panel->appendChild( $session->make_text( " " ) );
	$inner_panel->appendChild( $add_format_button );
}
##############

	
	return $add; 
}

sub _render_add_file
{
	my( $self, $document ) = @_;

	my $session = $self->{session};
	
	# Create a document-specific prefix
	my $docid = $document->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $hide = 0;
	my %files = $document->files;
	$hide = 1 if( scalar keys %files == 1 );

	my $f = $session->make_doc_fragment;	
	if( $hide )
	{
		my $hide_add_files = $session->make_element( "div", id=>$doc_prefix."_af1" );
		my $show = $self->{session}->make_element( "a", class=>"ep_only_js", href=>"#", onclick => "EPJS_blur(event); if(!confirm(".EPrints::Utils::js_string($self->phrase("really_add")).")) { return false; } EPJS_toggle('${doc_prefix}_af1',true);EPJS_toggle('${doc_prefix}_af2',false);return false", );
		$hide_add_files->appendChild( $self->html_phrase( 
			"add_files",
			link=>$show ));
		$f->appendChild( $hide_add_files );
	}

	my %l = ( id=>$doc_prefix."_af2", class=>"ep_upload_add_file_toolbar" );
	$l{class} .= " ep_no_js" if( $hide );
	my $toolbar = $session->make_element( "div", %l );
	my $file_button = $session->make_element( "input",
		name => $doc_prefix."_file",
		id => "filename",
		type => "file",
		);
	my $upload_button = $session->render_button(
		name => "_internal_".$doc_prefix."_add_file",
		class => "ep_form_internal_button",
		value => $self->phrase( "add_file" ),
		);
	$toolbar->appendChild( $file_button );
	$toolbar->appendChild( $session->make_text( " " ) );
	$toolbar->appendChild( $upload_button );
	$f->appendChild( $toolbar );

	return $f; 
}

sub _render_convert_document
{
	my( $self, $document ) = @_;

	my $session = $self->{session};
	
	# Create a document-specific prefix
	my $docid = $document->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $convert_plugin = $session->plugin( 'Convert' );

	my $dataset = $document->get_dataset();
	my $field = $dataset->get_field( 'format' );
	my %document_formats = map { ($_ => 1) } $field->tags( $session );

	my %available = $convert_plugin->can_convert( $document );

	# Only provide conversion for plugins that
	#  1) Provide a phrase (i.e. are public-facing)
	#  2) Provide a conversion to a format in document_types
	foreach my $type (keys %available)
	{
		unless( exists($available{$type}->{'phraseid'}) and
				exists($document_formats{$type}) )
		{
			delete $available{$type}
		}
	}

	my $f = $session->make_doc_fragment;	

	unless( scalar(%available) )
	{
		return $f;
	}

	my $select_button = $session->make_element( "select",
		name => $doc_prefix."_convert_to",
		id => "format",
		);
	my $option = $session->make_element( "option" );
	$select_button->appendChild( $option );
	# Use $available{$a}->{preference} for ordering?
	foreach my $type (keys %available)
	{
		my $plugin_id = $available{$type}->{ "plugin" }->get_id();
		my $phrase_id = $available{$type}->{ "phraseid" };
		my $option = $session->make_element( "option",
			value => $plugin_id . '-' . $type
		);
		$option->appendChild( $session->html_phrase( $phrase_id ));
		$select_button->appendChild( $option );
	}
	my $upload_button = $session->render_button(
		name => "_internal_".$doc_prefix."_convert_document",
		class => "ep_form_internal_button",
		value => $self->phrase( "convert_document_button" ),
		);

	my $table = $session->make_element( "table", class=>"ep_multi" );
	$f->appendChild( $table );

	my %l = ( id=>$doc_prefix."_af2", class=>"ep_convert_document_toolbar" );
	my $toolbar = $session->make_element( "div", %l );

	$toolbar->appendChild( $select_button );
	$toolbar->appendChild( $session->make_text( " " ) );
	$toolbar->appendChild( $upload_button );

	$table->appendChild( $session->render_row_with_help(
				label=>$self->html_phrase( "convert_document" ),
				field=>$toolbar,
				help=>$self->html_phrase( "convert_document_help" ),
				help_prefix=>$doc_prefix."_convert_document_help",
				));

	return $f; 
}



sub _render_filelist
{
	my( $self, $document ) = @_;

	my $session = $self->{session};
	
	if( !defined $document )
	{
		EPrints::abort( "No document for file upload component" );
	}
	
	my %files = $document->files;
	my $main_file = $document->get_main;
	my $num_files = scalar keys %files;
	
	my $docid = $document->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;

	my $table = $session->make_element( "table", class => "ep_upload_file_table" );
	my $tbody = $session->make_element( "tbody" );
	$table->appendChild( $tbody );

	if( !defined $document || $num_files == 0 ) 
	{
		$tbody->appendChild( $self->_render_placeholder );
		return $table;
	}

	my $imagesurl = $session->get_repository->get_conf( "rel_path" );

	my $i = 0;
	foreach my $filename ( sort keys %files )
	{
		my $tr = $session->make_element( "tr" );
	
		my $td_filename = $session->make_element( "td" );
		my $a = $session->render_link( $document->get_url( $filename ), "_blank" );
		$a->appendChild( $session->make_text( $filename ) );
		
		$td_filename->appendChild( $a );
		$tr->appendChild( $td_filename );
		
		my $td_filesize = $session->make_element( "td" );
		my $size = EPrints::Utils::human_filesize( $files{$filename} );
		$size =~ m/^([0-9]+)([^0-9]*)$/;
		my( $n, $units ) = ( $1, $2 );
		$td_filesize->appendChild( $session->make_text( $n ) );
		$td_filesize->appendChild( $session->make_text( $units ) );
		$tr->appendChild( $td_filesize );
		
		my $td_delete = $session->make_element( "td" );
		my $del_btn_text = $session->html_phrase( "lib/submissionform:delete" );
		my $del_btn = $session->make_element( "input", 
			type => "image", 
			src => "$imagesurl/style/images/delete.png",
			name => "_internal_".$doc_prefix."_delete_$i",
			onclick => "EPJS_blur(event); return confirm( ".EPrints::Utils::js_string($self->phrase( "delete_file_confirm", filename => $filename ))." );",
			value => $self->phrase( "delete_file" ) );
			
		$td_delete->appendChild( $del_btn );
		$tr->appendChild( $td_delete );
		
#		my $td_filetype = $session->make_element( "td" );
#		$td_filetype->appendChild( $session->make_text( "" ) );
#		$tr->appendChild( $td_filetype );
			
		$tbody->appendChild( $tr );
		$i++;
	}
	
	return $table;
}

sub _render_placeholder
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $placeholder = $session->make_element( "tr", id => "placeholder" );
	my $td = $session->make_element( "td", colspan => "3" );
	$td->appendChild( $self->html_phrase( "upload_blurb" ) );
	$placeholder->appendChild( $td );
	return $placeholder;
}

sub validate
{
	my( $self ) = @_;
	
	my @problems = ();

	my $for_archive = $self->{workflow}->{for_archive};

	my $eprint = $self->{workflow}->{item};
	my $session = $self->{session};
	
        my @req_formats = $eprint->required_formats;
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
		my $doc_ds = $eprint->{session}->get_repository->get_dataset( 
			"document" );
		my $fieldname = $eprint->{session}->make_element( "span", class=>"ep_problem_field:documents" );
		my $prob = $eprint->{session}->make_doc_fragment;
		$prob->appendChild( $eprint->{session}->html_phrase( 
			"lib/eprint:need_a_format",
			fieldname=>$fieldname ) );
		my $ul = $eprint->{session}->make_element( "ul" );
		$prob->appendChild( $ul );
		
		foreach( @req_formats )
		{
			my $li = $eprint->{session}->make_element( "li" );
			$ul->appendChild( $li );
			$li->appendChild( $eprint->{session}->render_type_name( "document", $_ ) );
		}
			
		push @problems, $prob;

	}

	foreach $doc (@docs)
	{
		my $probs = $doc->validate( $for_archive );
		foreach (@$probs)
		{
			my $prob = $eprint->{session}->make_doc_fragment;
			$prob->appendChild( $doc->render_description );
			$prob->appendChild( 
				$eprint->{session}->make_text( ": " ) );
			$prob->appendChild( $_ );
			push @problems, $prob;
		}
	}

	return @problems;
}


sub parse_config
{
	my( $self, $config_dom ) = @_;
	
	$self->{config}->{fields} = [];

# moj: We need some default phrases for when these aren't specified.
#	$self->{config}->{title} = ""; 
#	$self->{config}->{help} = ""; 

	my @fields = $config_dom->getElementsByTagName( "field" );

	my $doc_ds = $self->{session}->get_repository->get_dataset( "document" );

	foreach my $field_tag ( @fields )
	{
		my $field = $self->xml_to_metafield( $field_tag, $doc_ds );
		push @{$self->{config}->{doc_fields}}, $field;
	}
}



1;
