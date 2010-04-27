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
			my @screen_opts = $self->{processor}->list_items(
				"upload_methods",
				params => {
					processor => $self->{processor},
				},
			);
			my @methods = map { $_->{screen} } @screen_opts;
			my $i = 0;
			foreach my $plugin (@methods)
			{
				if( $plugin->get_id eq $method )
				{
					$plugin->from( $self->{prefix} );
					$self->{processor}->{notes}->{upload_plugin}->{ctab} = $i;
					return;
				}
				$i++;
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
	my $ctab = $processor->{notes}->{upload_plugin}->{ctab} || "";
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
	$params .= "&".$self->{prefix}."_tab=".$ctab;

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
	
	my @screen_opts = $self->{processor}->list_items( 
			"upload_methods",
			params => {
				processor => $self->{processor},
			},
		);
	my @methods = map { $_->{screen} } @screen_opts;

	my $html = $session->make_doc_fragment;

	# no upload methods so don't do anything
	return $html if @screen_opts == 0;

	my @labels;
	my @tabs;
	foreach my $plugin ( @methods )
	{
		my $name = $plugin->get_id;
		push @labels, $plugin->render_title();
		my $div = $session->make_element( "div", class => "ep_block" );
		push @tabs, $div;
		$div->appendChild( $plugin->render( $self->{prefix} ) );
	}

	$html->appendChild( $self->{session}->xhtml->tabs( \@labels, \@tabs,
		basename => $self->{prefix},
		current => $self->{session}->param( $self->{prefix} . "_tab" ),
	) );

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
