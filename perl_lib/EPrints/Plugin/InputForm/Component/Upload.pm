package EPrints::Plugin::InputForm::Component::Upload;

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

	if( defined $self->{_documents} )
	{
		$self->{_documents}->update_from_form( $processor );
	}

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

	if( defined $self->{_documents} )
	{
		$html->appendChild( $self->{_documents}->render_content( $surround ) );
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

	# backwards compatibility
	if( $config_dom->getElementsByTagName( "field" )->length > 0 )
	{
		$self->{_documents} = $self->{session}->plugin( "InputForm::Component::Documents",
			processor => $self->{processor},
			workflow => $self->{workflow} );
		$self->{_documents}->parse_config( $config_dom );
	}
}


1;
