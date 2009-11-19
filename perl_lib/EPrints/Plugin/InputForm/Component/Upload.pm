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
	# a list of documents to unroll when rendering, 
	# this is used by the POST processing, not GET

	return $self;
}

# only returns a value if it belongs to this component
sub update_from_form
{
	my( $self, $processor ) = @_;

	my $session = $self->{session};
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
				$session, 
				$self->{dataobj}, 
				$doc_prefix );
			$doc->set_value( $field->{name}, $value );
		}
		$doc->commit;
	}
	
	#Get all docs including volatiles
	my @eprint_all_docs = @{($eprint->get_value( "documents" ))};

	if( $session->internal_button_pressed )
	{
		my $internal = $self->get_internal_button;
		if( $internal =~ m/^add_format_(.+)$/ )
		{
			my $method = $1;
			my @plugins = $self->_get_upload_plugins(
					prefix => $self->{prefix},
					dataobj => $self->{dataobj},
				);
			foreach my $plugin (@plugins)
			{
				if( $plugin->get_id eq $method )
				{
					$plugin->update_from_form( $processor );
					return;
				}
			}
			EPrints::abort( "'$method' is not a supported upload method" );
		}
	}

	return;
}

sub get_state_params
{
	my( $self, $processor ) = @_;

	my $params = "";

	my $tounroll = {};
	if( $processor->{notes}->{upload_plugin}->{to_unroll} )
	{
		$tounroll = $processor->{notes}->{upload_plugin}->{to_unroll};
	}
	if( $self->{session}->internal_button_pressed )
	{
		my $internal = $self->get_internal_button;
		# modifying existing document
		if( $internal =~ m/^doc(\d+)_(.*)$/ )
		{
			$tounroll->{$1} = 1;
		}
	}
	if( scalar keys %{$tounroll} )
	{
		$params .= "&".$self->{prefix}."_view=".join( ",", keys %{$tounroll} );
	}

	return $params;
}

sub _swap_placements
{
	my( $docs, $l, $r ) = @_;

	my( $left, $right ) = @$docs[$l,$r];

	my $t = $left->get_value( "placement" );
	$left->set_value( "placement", $right->get_value( "placement" ) );
	$right->set_value( "placement", $t );

	$t = $docs->[$l];
	$docs->[$l] = $docs->[$r];
	$docs->[$r] = $t;
}

sub doc_update
{
	my( $self, $doc, $doc_internal, $eprint_docs, $processor ) = @_;

	my $docid = $doc->get_id;
	my $doc_prefix = $self->{prefix}."_doc".$docid;
	$processor->{notes}->{upload_plugin}->{to_unroll}->{$docid} = 1;

	if( $doc_internal eq "up" or $doc_internal eq "down" )
	{	
		return if scalar @$eprint_docs < 2;
		foreach my $eprint_doc (@$eprint_docs)
		{
			next if $eprint_doc->is_set( "placement" );
			$eprint_doc->set_value( "placement", $eprint_doc->get_value( "pos" ) );
		}
		my $loc;
		for($loc = 0; $loc < @$eprint_docs; ++$loc)
		{
			last if $eprint_docs->[$loc]->get_id == $doc->get_id;
		}
		if( $doc_internal eq "up" )
		{
			if( $loc == 0 )
			{
				for(my $i = 0; $i < $#$eprint_docs; ++$i)
				{
					_swap_placements( $eprint_docs, $i, $i+1 );
				}
			}
			else
			{
				_swap_placements( $eprint_docs, $loc, $loc-1 );
			}
		}
		if( $doc_internal eq "down" )
		{
			if( $loc == $#$eprint_docs )
			{
				for(my $i = $#$eprint_docs; $i > 0; --$i)
				{
					_swap_placements( $eprint_docs, $i, $i-1 );
				}
			}
			else
			{
				_swap_placements( $eprint_docs, $loc, $loc+1 );
			}
		}
		# We don't need to create lots of commits on the parent eprint
		my $eprint = $eprint_docs->[0]->get_parent;
		$eprint->set_under_construction( 1 );
		$_->commit() for @$eprint_docs;
		$eprint->set_under_construction( 0 );
		$eprint->commit(1);
		return;
	}

	if( $doc_internal eq "update_doc" )
	{
		return;
	}

	if( $doc_internal eq "delete_doc" )
	{
		$doc->remove();
		return;
	}

	if( $doc_internal eq "unlink_doc" )
        {
                my $relation = EPrints::Utils::make_relation( "isVolatileVersionOf" );
                my $parent = $doc->get_related_objects($relation)->[0];
                print STDERR "\n" . $parent->get_id . "\n";
                $parent->remove_object_relations(
                        $doc,
                        EPrints::Utils::make_relation( "hasVolatileVersion" ),
                );
                $parent->commit;
                $doc->remove_object_relations(
                        $parent,
                        EPrints::Utils::make_relation( "isVolatileVersionOf" ),
                );
                $doc->commit;
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
		$doc->remove_object_relations(
				$new_doc,
				EPrints::Utils::make_relation( "hasVolatileVersion" ) =>
				EPrints::Utils::make_relation( "isVolatileVersionOf" )
			);
		$new_doc->make_thumbnails();
		$doc->commit();
		$new_doc->commit();
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

sub has_help
{
	my( $self, $surround ) = @_;
	return $self->{session}->get_lang->has_phrase( $self->html_phrase_id( "help" ) );
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
	return 0;
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
	
	my @methods = $self->_get_upload_plugins(
			prefix => $self->{prefix},
			dataobj => $self->{dataobj}
		);

	my $html = $session->make_doc_fragment;

	# no upload methods so don't do anything
	return $html if @methods == 0;

	my $tabs = [];
	my $labels = {};
	my $links = {};
	foreach my $plugin ( @methods )
	{
		my $name = $plugin->get_id;
		push @$tabs, $name;
		$labels->{$name} = $plugin->render_tab_title();
		$links->{$name} = "";
	}

	my $newdoc = $self->{session}->make_element( 
			"div", 
			class => "ep_upload_newdoc" );
	$html->appendChild( $newdoc );
	my $tab_block = $session->make_element( "div", class=>"ep_only_js" );	
	$tab_block->appendChild( 
		$self->{session}->render_tabs( 
			id_prefix => $self->{prefix}."_upload",
			current => $tabs->[0],
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

	my $first = 1;
	foreach my $plugin ( @methods )
	{
		my $inner_panel;
		if( $first )
		{
			$inner_panel = $self->{session}->make_element( 
				"div", 
				id => $self->{prefix}."_upload_panel_".$plugin->get_id );
		}
		else
		{
			# padding for non-javascript enabled browsers
			$panel->appendChild( 
				$session->make_element( "div", style=>"height: 1em", class=>"ep_no_js" ) );
			$inner_panel = $self->{session}->make_element( 
				"div", 
				class => "ep_no_js",
				id => $self->{prefix}."_upload_panel_".$plugin->get_id );	
		}
		$panel->appendChild( $inner_panel );

		$inner_panel->appendChild( $plugin->render_add_document() );
		$first = 0;
	}

	return $html;
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

		foreach my $field ( @{$self->{config}->{doc_fields}} )
		{
			my $for_archive = 0;
			
			if( $field->{required} eq "for_archive" )
			{
				$for_archive = 1;
			}

			# cjg bug - not handling for_archive here.
			if( $field->{required} && !$doc->is_set( $field->{name} ) )
			{
				my $fieldname = $self->{session}->make_element( "span", class=>"ep_problem_field:documents" );
				$fieldname->appendChild( $field->render_name( $self->{session} ) );
				my $problem = $self->{session}->html_phrase(
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

sub _get_upload_plugins
{
	my( $self, %opts ) = @_;

	my %plugins;

	my @plugins;
	if( defined $self->{config}->{methods} )
	{
		METHOD: foreach my $method (@{$self->{config}->{methods}})
		{
			my $plugin = $self->{session}->plugin( "InputForm::UploadMethod::$method", %opts );
			if( !defined $plugin )
			{
				$self->{session}->get_repository->log( "Unknown upload method in Component::Upload: '$method'" );
				next METHOD;
			}
			push @plugins, $plugin;
		}
	}
	else
	{
		METHOD: foreach my $plugin ( $self->{session}->plugin_list( type => 'InputForm' ) )
		{
			$plugin = $self->{session}->plugin( $plugin, %opts );
			next METHOD if !$plugin->isa( "EPrints::Plugin::InputForm::UploadMethod" );
			next METHOD if ref($plugin) eq "EPrints::Plugin::InputForm::UploadMethod";
			push @plugins, $plugin;
		}
	}

	foreach my $plugin ( @plugins )
	{
		foreach my $appearance ( @{$plugin->{appears}} )
		{
			$plugins{ref($plugin)} = [$appearance->{position},$plugin];
		}
	}

	return
		map { $plugins{$_}->[1] }
		sort { $plugins{$a}->[0] <=> $plugins{$b}->[0] || $a cmp $b }
		keys %plugins;
}

sub parse_config
{
	my( $self, $config_dom ) = @_;

	$self->{config}->{doc_fields} = [];

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

	my @uploadmethods = $config_dom->getElementsByTagName( "upload-methods" );
	if( defined $uploadmethods[0] )
	{
		$self->{config}->{methods} = [];

		my @methods = $uploadmethods[0]->getElementsByTagName( "method" );
	
		foreach my $method_tag ( @methods )
		{	
			my $method = EPrints::XML::to_string( EPrints::XML::contents_of( $method_tag ) );
			push @{$self->{config}->{methods}}, $method;
		}
	}

}


1;
