
package EPrints::Plugin::Screen::Import;

use EPrints::Plugin::Screen;

use Fcntl qw(:DEFAULT :seek);
use File::Temp;

our $MAX_ERR_LEN = 1024;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ import_from test import /];

#	$self->{appears} = [
#		{
#			place => "item_tools",
#			position => 200,
#		}
#	];

	if( $self->{session} )
	{
		# screen to go to after a single item import
		$self->{post_import_screen} = $self->param( "post_import_screen" );
		$self->{post_import_screen} ||= "EPrint::Edit";

		# screen to go to after a bulk import
		$self->{post_bulk_import_screen} = $self->param( "post_bulk_import_screen" );
		$self->{post_bulk_import_screen} ||= "Items";
	}

	return $self;
}

sub properties_from
{
	my( $self ) = @_;
	
	$self->SUPER::properties_from;

	my $plugin_id = $self->{session}->param( "plugin_id" );

	# dataset to import into
	$self->{processor}->{dataset} = $self->{session}->get_repository->get_dataset( "inbox" );

	my $value = $self->{session}->param( "import_documents" );
	$self->{processor}->{import_documents} = defined $value && $value eq "yes";
	
	if( defined $plugin_id )
	{
		my $plugin = $self->{session}->plugin(
			"Import::$plugin_id",
			session => $self->{session},
			dataset => $self->{processor}->{dataset},
			processor => $self->{processor},
			import_documents => $self->{processor}->{import_documents},
		);
		if( !defined $plugin || $plugin->broken )
		{
			$self->{processor}->add_message( "error", $self->{session}->html_phrase( "general:bad_param" ) );
			return;
		}

		if( !($plugin->can_produce( "list/eprint" ) || $plugin->can_produce( "dataobj/eprint" )) )
		{
			$self->{processor}->add_message( "error", $self->{session}->html_phrase( "general:bad_param" ) );
			return;
		}

		$self->{processor}->{plugin} = $plugin;
		$self->{processor}->{plugin_id} = $plugin_id;
	}
}

sub can_be_viewed
{
	my( $self ) = @_;
	return $self->allow( "create_eprint" );
}

sub allow_import_from
{
	my( $self ) = @_;
	return $self->can_be_viewed;
}

sub allow_test
{
	my( $self ) = @_;
	return $self->can_be_viewed;
}

sub allow_import
{
	my( $self ) = @_;
	return $self->can_be_viewed;
}

sub action_import_from
{
	my( $self ) = @_;
}

sub action_test
{
	my ( $self ) = @_;

	my $tmp_file = $self->_make_tmp_file;
	return if !defined $tmp_file;

	$self->_import( 1, 0, $tmp_file ); # dry run with messages
}

sub action_import
{
	my( $self ) = @_;

	my $processor = $self->{processor};

	my $tmp_file = $self->_make_tmp_file;
	return if !defined $tmp_file;

	return unless $self->_import( 1, 1, $tmp_file ); # quiet dry run
	my( $import, $list ) = $self->_import( 0, 0, $tmp_file ); # real run with messages

	my $n = $list->count;

	if( $n == 1 )
	{
		my( $eprint ) = $list->get_records( 0, 1 );
		# remove the bulk import object
		$eprint->set_value( "importid", undef );
		$eprint->commit;
		$import->remove;
		# add in eprint/eprintid for backwards compatibility
		$processor->{dataobj} = $processor->{eprint} = $eprint;
		$processor->{dataobj_id} = $processor->{eprintid} = $eprint->get_id;
		$processor->{screenid} = $self->{post_import_screen};
	}
	elsif( $n > 1 )
	{
		$processor->{dataobj} = $import;
		$processor->{dataobj_id} = $import->get_id;
		$processor->{screenid} = $self->{post_bulk_import_screen};
	}
}

sub _make_tmp_file
{
	my( $self ) = @_;

	my $query = $self->{session}->get_query;
	my $tmp_file;
	my $import_fh;
	my $import_data;

	my $filled_in = 0;
	for(qw( import_filename bulk_import_filename ))
	{
		if( EPrints::Utils::is_set( $query->param( $_ ) ) )
		{
			$filled_in++;
			$import_fh = $query->upload( $_ );
		}
	}

	for(qw( import_data bulk_import_data import_uri bulk_import_uri ))
	{
		if( EPrints::Utils::is_set( $query->param( $_ ) ) )
		{
			$filled_in++;
			$import_data = $query->param( $_ );
		}
	}

	# nothing supplied
	if( $filled_in == 0 )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "nothing_to_import" ) );
		return undef;
	}
	# more than one thing filled in?!
	elsif( $filled_in > 1 )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "multiple_inputs" ) );
		return undef;
	}

	if( defined $import_fh )
	{
		$tmp_file = $import_fh;
	}
	else
	{
		# Write import records to temp file
		$tmp_file = File::Temp->new( UNLINK => 1 );
		$tmp_file->autoflush;

		# Write a Byte Order Mark for utf-8 if the plugin is a TextFile type,
		# which will cause utf-8 to be read correctly
		my $plugin = $self->{processor}->{plugin};
		if( $plugin->isa( "EPrints::Plugin::Import::TextFile" ) )
		{
			binmode($tmp_file);
			print $tmp_file pack("CCC", 0xef, 0xbb, 0xbf);
		}
		print $tmp_file $import_data;
	}

	return $tmp_file;
}

sub _import
{
	my( $self, $dryrun, $quiet, $tmp_file ) = @_;

	seek($tmp_file, 0, SEEK_SET);

	my $session = $self->{session};
	my $dataset = $self->{processor}->{dataset};
	my $user = $self->{processor}->{user};
	my $plugin = $self->{processor}->{plugin};

	my $import;
	if( !$dryrun )
	{
		$import = $session->get_repository->get_dataset( "import" )->create_object( $session, {} );
	}

	my $handler = EPrints::Plugin::Screen::Import::Handler->new(
		processor => $self->{processor},
		user => $user,
		quiet => $quiet,
		import => $import,
	);

	$plugin->{Handler} = $handler;
	$plugin->{parse_only} = $dryrun;

	my $err_file = File::Temp->new(
		UNLINK => 1
	);

	# We'll capture anything from STDERR that an import library may
	# spew out
	{
	# Perl complains about OLD_STDERR being used only once with warnings
	no warnings;
	open(OLD_STDERR, ">&STDERR") or die "Failed to save STDERR";
	}
	open(STDERR, ">$err_file") or die "Failed to redirect STDERR";

	my @problems;

	# Don't let an import plugin die() on us
	my $list = eval {
		$plugin->input_fh(
			dataset=>$dataset,
			fh=>$tmp_file,
			user=>$user,
		);
	};
	push @problems, "Unhandled exception in ".$plugin->{id}.": $@" if $@;

	my $count = $dryrun ? $handler->{parsed} : $handler->{wrote};

	open(STDERR,">&OLD_STDERR") or die "Failed to restore STDERR";

	seek( $err_file, 0, SEEK_SET );

	my $err = "";

	while(<$err_file>)
	{
		$_ =~ s/\s+$//;
		next unless length($_);
		$err .= "$_\n";
		last if length($err) > $MAX_ERR_LEN;
	}

	if( length($err) )
	{
		push @problems, "Unhandled warning in ".$plugin->{id}.": $err";
	}

	for(@problems)
	{
		s/^(.{$MAX_ERR_LEN}).*$/$1 .../s;
		s/\t/        /g; # help _mktext out a bit
		my @lines = EPrints::DataObj::History::_mktext( $session, $_, 0, 0, 80 );
		my $pre = $session->make_element( "pre" );
		$pre->appendChild( $session->make_text( join( "\n", @lines )));
		$self->{processor}->add_message( "warning", $pre );
	}

	my $ok = (scalar(@problems) == 0 and $count > 0);

	if( $dryrun )
	{
		if( $ok )
		{
			$self->{processor}->add_message( "message", $self->html_phrase(
				"test_completed", 
				count => $session->make_text( $count ) ) ) unless $quiet;
		}
		else
		{
			$self->{processor}->add_message( "warning", $self->html_phrase( 
				"test_failed", 
				count => $session->make_text( $count ) ) );
		}
	}
	else
	{
		if( $ok )
		{
			$self->{processor}->add_message( "message", $self->html_phrase( 
				"import_completed", 
				count => $session->make_text( $count ) ) );
		}
		else
		{
			$self->{processor}->add_message( "warning", $self->html_phrase( 
				"import_failed", 
				count => $session->make_text( $count ) ) );
		}
	}

	return( $import, $list );
}

sub redirect_to_me_url { }

sub render_title
{
	my( $self ) = @_;

	return $self->html_phrase( "title",
		input => $self->{session}->make_text( $self->{processor}->{plugin_id} ) );
}

sub _render_input_data_tab
{
	my( $self, $prefix, $plugin ) = @_;

	my $session = $self->{session};

	my $value;
	my $set = 0;

	my $textarea = $session->make_element(
		"textarea",
		name => $prefix."import_data",
		rows => 10,
		cols => 50,
		wrap => "virtual" );
	$value = $session->param( $prefix."import_data" );
	if( EPrints::Utils::is_set($value) )
	{
		$set = 1;
		$textarea->appendChild( $session->make_text( $value ) );
	}

	$value = $session->param( $prefix."import_uri" );
	my $inputuri = $session->make_element(
		"input",
		type => "text",
		name => $prefix."import_uri",
		value => $value );
	$set = 1 if EPrints::Utils::is_set( $value );

	my $fileupload = $session->render_upload_field( $prefix."import_filename" );

	my $phrase_id = $plugin->html_phrase_id( $prefix."input:form" );
	if( !$session->get_lang->has_phrase( $phrase_id ) )
	{
		$phrase_id = $self->html_phrase_id( $prefix."input:form" );
	}

	my $content = $session->html_phrase(
		$phrase_id,
		$prefix.input_text_area => $textarea,
		$prefix.input_uri => $inputuri,
		$prefix.input_file_upload => $fileupload,
	);

	return {
		id => $prefix."input_tab",
		title => $self->html_phrase( $prefix."input:title" ),
		content => $content,
		set => $set,
	};
}

sub render
{
	my ( $self ) = @_;

	my $session = $self->{session};
	my $plugin = $self->{processor}->{plugin};

	my $page = $session->make_doc_fragment;

	# Preamble
	my $imagesurl = $session->get_repository->get_conf( "rel_path" )."/style/images";

	my $box = $session->make_element( "div", style=>"text-align: left" );
	$page->appendChild( $box );
	$box->appendChild( EPrints::Box::render( 
 		session => $session,
		id => "ep_review_instructions",
		title => $session->html_phrase( "Plugin/Screen/Items:help_title" ),
		content => $self->html_phrase( "intro" ),
		collapsed => 1,
		show_icon_url => "$imagesurl/help.gif",
	) );

	my $form = $session->render_form( "post" );
	$page->appendChild( $form );
	# add hidden values
	$form->appendChild( $session->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
	$form->appendChild( $session->render_hidden_field( "plugin_id", $self->{processor}->{plugin_id} ) );

	my @tabs;
	my $default_tab = 0;

	# build a list of tabs containing the available data input methods
	if( $plugin->can_produce( "dataobj/eprint" ) )
	{
		push @tabs, $self->_render_input_data_tab( "", $plugin );
		$default_tab = $#tabs if $tabs[$#tabs]->{set};
	}
	if( $plugin->can_produce( "list/eprint" ) )
	{
		push @tabs, $self->_render_input_data_tab( "bulk_", $plugin );
		$default_tab = $#tabs if $tabs[$#tabs]->{set};
	}

	# with no tabs just render a toolbox
	if( @tabs == 1 )
	{
		# unused title
		EPrints::XML::dispose( $tabs[0]->{title} );
		$form->appendChild( $session->render_toolbox( undef, $tabs[0]->{content} ) );
	}
	# render tabbed input
	elsif( @tabs > 1 )
	{
		# render the input tabs
		my $id_prefix = "import_data_input";

		$form->appendChild( $session->render_tabs(
			id_prefix => $id_prefix,
			current => $tabs[$default_tab]->{id},
			tabs => [map { $_->{id} } @tabs],
			labels => {map { $_->{id} => $_->{title} } @tabs},
			links => {map { $_->{id} => "" } @tabs},
			) );

		# panel that all the tab content sits in
		my $panel = $session->make_element( "div",
			id => "${id_prefix}_panels",
			class => "ep_tab_panel",
		);
		$form->appendChild( $panel );

		# populate each of the panels
		foreach my $tab (@tabs)
		{
			my $view_div = $session->make_element( "div",
				id => "${id_prefix}_panel_".$tab->{id},
			);
			if( $tab ne $tabs[$default_tab] )
			{
				$view_div->setAttribute( "style", "display: none" );
			}
			$view_div->appendChild( $tab->{content} );

			$panel->appendChild( $view_div );
		}
	}

	if( $session->get_repository->get_conf( "enable_web_imports" ) )
	{
		$form->appendChild( $session->make_element( "br" ) );
		my $importfiles = $session->render_input_field( type=>"checkbox", name=>"import_documents", value=>"yes", class=>"ep_form_checkbox", id=>"import_documents" );
		if( $self->{processor}->{import_documents} )
		{
			$importfiles->setAttribute( "checked", "yes" );
		}
		$importfiles->appendChild( $session->make_element( "label", 
			for => "import_documents",
		) )->appendChild( $self->html_phrase( "import_documents" ) );
		$form->appendChild( $session->render_toolbox( undef, $importfiles ) );
	}

	$form->appendChild( $session->render_action_buttons( 
		_class => "ep_form_button_bar",
		test => $self->phrase( "action:test:title" ), 
		import => $self->phrase( "action:import:title" ),
		_order => [qw( test import )] ) );

	return $page;
}

sub _vis_level
{
	my( $self ) = @_;

	return "all";
}

sub _get_import_plugins
{
	my( $self ) = @_;

	my %opts =  (
			type=>"Import",
#			can_produce=>"list/eprint",
			is_visible=>$self->_vis_level,
	);

	return
		$self->{session}->plugin_list( %opts, can_produce => "list/eprint" ),
		$self->{session}->plugin_list( %opts, can_produce => "dataobj/eprint" );
}

sub render_action_button
{
	my( $self, $params, $asicon ) = @_;

	return $self->render_import_bar;
}

sub render_import_bar
{
	my( $self ) = @_;

	my $session = $self->{session};

	my @plugins = $self->_get_import_plugins;
	if( scalar @plugins == 0 ) 
	{
		return $session->make_doc_fragment;
	}

	my $tools = $session->make_doc_fragment;
	my $options = {};
	foreach my $plugin_id ( @plugins ) 
	{
		$plugin_id =~ m/^[^:]+::(.*)$/;
		my $id = $1;
		my $plugin = $session->plugin( $plugin_id );
		my $dom_name = $plugin->render_name;
		if( $plugin->is_tool )
		{
			my $type = "tool";
			my $span = $session->make_element( "span", class=>"ep_search_$type" );
			my $url = $self->export_url( $id );
			my $a1 = $session->render_link( $url );
			my $icon = $session->make_element( "img", src=>$plugin->icon_url(), alt=>"[$type]", border=>0 );
			$a1->appendChild( $icon );
			my $a2 = $session->render_link( $url );
			$a2->appendChild( $dom_name );
			$span->appendChild( $a1 );
			$span->appendChild( $session->make_text( " " ) );
			$span->appendChild( $a2 );

			$tools->appendChild( $session->make_text( " " ) );
			$tools->appendChild( $span );	
		}
		else
		{
			my $option = $session->make_element( "option", value=>$id );
			$option->appendChild( $dom_name );
			$options->{EPrints::XML::to_string($dom_name)} = $option;
		}
	}

	my $select = $session->make_element( "select", name=>"plugin_id" );
	foreach my $optname ( sort keys %{$options} )
	{
		$select->appendChild( $options->{$optname} );
	}
	my $button = $session->make_doc_fragment;
	$button->appendChild( $session->render_button(
			name=>"_action_import_from",
			value=>$self->phrase( "action:import_from:title" ) ) );
	$button->appendChild( 
		$session->render_hidden_field( "screen", substr($self->{id},8) ) ); 

	my $form = $session->render_form( "GET" );
	$form->appendChild( $self->html_phrase( "import_section",
					tools => $tools,
					menu => $select,
					button => $button ));

	return $form;
}

package EPrints::Plugin::Screen::Import::Handler;

sub new
{
	my( $class, %self ) = @_;

	$self{wrote} = 0;
	$self{parsed} = 0;

	bless \%self, $class;
}

sub message
{
	my( $self, $type, $msg ) = @_;

	unless( $self->{quiet} )
	{
		$self->{processor}->add_message( $type, $msg );
	}
}

sub parsed
{
	my( $self, $epdata ) = @_;

	$self->{parsed}++;
}

sub object
{
	my( $self, $dataset, $dataobj ) = @_;

	$self->{wrote}++;

	if( $dataset->confid eq "eprint" )
	{
		$dataobj->set_value( "userid", $self->{user}->get_id );
		if( defined $self->{import} )
		{
			$dataobj->set_value( "importid", $self->{import}->get_id );
		}
		$dataobj->commit;
	}	
}

1;
