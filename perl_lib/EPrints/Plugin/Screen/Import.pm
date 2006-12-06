
package EPrints::Plugin::Screen::Import;

use EPrints::Plugin::Screen;

use Fcntl qw(:DEFAULT :seek);

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ test import /];

	$self->{appears} = [
		{
			place => "item_tools",
			position => 200,
		}
	];

	return $self;
}

sub properties_from
{

	my( $self ) = @_;
	
	$self->SUPER::properties_from;

	my $pluginid = $self->{session}->param( "pluginid" );
	
	if( defined $pluginid )
	{
		my $plugin = $self->{session}->plugin( $pluginid, dataset=>$self->{session}->get_repository->get_dataset( "inbox" ) );
		if( !defined $plugin || $plugin->broken )
		{
			$self->{processor}->add_message( "error", $self->{session}->html_phrase( "general:bad_param" ) );
			return;
		}

		my $req_plugin_type = "list/eprint";
		unless( $plugin->can_produce( $req_plugin_type ) )
		{
			$self->{processor}->add_message( "error", $self->{session}->html_phrase( "general:bad_param" ) );
			return;
		}

		$self->{processor}->{plugin} = $plugin;

	}

}

sub allow_test
{
	my( $self ) = @_;
	return $self->allow( "create_eprint" );
}

sub allow_import
{
	my( $self ) = @_;
	return $self->allow_test;
}

sub action_test
{
	my ( $self ) = @_;

	$self->_import( 1 );
}

sub action_import
{
	my ( $self ) = @_;

	$self->_import( 0 );
	$self->{processor}->{screenid} = "Items";
}

sub _import
{
	my( $self, $dryrun ) = @_;

	my $session = $self->{session};
	my $ds = $session->get_repository->get_dataset( "inbox" );

	# Write to temp file
	my $fh = $self->{session}->{query}->upload( "import_filename" );
	seek( $fh, 0, SEEK_SET );

	my( $buffer );
	my $tmp_file = "/tmp/eprints.import.$$";
	open( TMP, ">$tmp_file" ) || die "Could not write to $tmp_file";
	while( read( $fh, $buffer, 1024 ) )
	{
		print TMP $buffer;
	}
	close TMP;

	# Build command
	my $import_script = $EPrints::SystemSettings::conf->{base_path}."/bin/import";
	my $ds_id = "inbox";
	my $cmd = $import_script." --scripted ".$session->get_repository->get_id." ".$ds_id." ".$self->{processor}->{plugin}->get_subtype." --user ".$self->{processor}->{user}->get_id." ".$tmp_file;
	$cmd .= " --parse-only" if $dryrun;

	# Run command without user check
	my $pid = open( OUTPUT, "EPRINTS_NO_CHECK_USER=1 $cmd 2>&1|" );
	my @imp_out = <OUTPUT>;
	close OUTPUT;

	# Remove temp file
	if( -e $tmp_file )
	{
		unlink( $tmp_file );
	}

	my @misc = ();
	my $ok = 0;
	my $parsed = 0;
	my @ids;
	foreach my $line ( @imp_out )
	{
		if( $line !~ s/^EPRINTS_IMPORT: // )
		{
			push @misc,$line unless $line =~ /^\s+$/s;
			next;
		}
		chomp $line;
		if( $line =~ m/ITEM_IMPORTED (\d+)/ )
		{
			push @ids, $1;
		}
		if( $line =~ m/ITEM_PARSED/ )
		{
			$parsed++;
		}
		if( $line =~ m/^DONE (\d+)$/ )
		{
			$ok = 1;
		}
	}

	my $list = EPrints::List->new(
		dataset => $ds,
		session => $session,
		ids=>\@ids );

	if( $dryrun )
	{
		if( $ok )
		{
			$self->{processor}->add_message( "message", $session->html_phrase(
				"Plugin/Screen/Import:test_completed", 
				count => $session->make_text( $parsed ) ) );
		}
		else
		{
			$self->{processor}->add_message( "warning", $session->html_phrase( 
				"Plugin/Screen/Import:test_failed", 
				count => $session->make_text( $parsed ) ) );
		}
	}
	else
	{
		if( $ok )
		{
			$self->{processor}->add_message( "message", $session->html_phrase( 
				"Plugin/Screen/Import:import_completed", 
				count => $session->make_text( $list->count ) ) );
		}
		else
		{
			$self->{processor}->add_message( "warning", $session->html_phrase( 
				"Plugin/Screen/Import:import_failed", 
				count => $session->make_text( $list->count ) ) );
		}
	}

	if( scalar @misc > 0 )
	{
		my $pre = $session->make_element( "pre" );
		$pre->appendChild( $session->make_text( join( "", @misc[0..99] ) ) );
		$self->{processor}->add_message( "warning", $session->html_phrase(
			"Plugin/Screen/Import:import_errors",
			errors => $pre ) );
	}
	
}

sub redirect_to_me_url
{
	my( $self ) = @_;
	return $self->SUPER::redirect_to_me_url."&import_filename=" . $self->{session}->param( "import_filename" ) . "&pluginid=" . $self->{processor}->{plugin}->get_id;
}

sub render
{
	my ( $self ) = @_;

	my $session = $self->{session};
	my $ds = $session->get_repository->get_dataset( "inbox" );

	my $page = $session->make_doc_fragment;

	# TODO: preamble/instructions

	my $form =  $session->render_form( "post" );
	$form->appendChild( $session->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
	$page->appendChild( $form );

	$form->appendChild( $session->render_upload_field( "import_filename" ) );

	$form->appendChild( $session->make_element( "br" ) );

	my @plugins = $session->plugin_list( 
			type=>"Import",
			can_produce=>"dataobj/".$ds->confid );

	my $select = $session->make_element( "select", name => "pluginid" );
	$form->appendChild( $select );

	for( @plugins )
	{
		my $plugin = $session->plugin( $_ );
		next if $plugin->broken;
		my $opt = $session->make_element( "option", value => $_  );
		$opt->setAttribute( "selected", "selected" ) if $self->{processor}->{plugin} && $_ eq $self->{processor}->{plugin}->get_id;
		$opt->appendChild( $plugin->render_name );
		$select->appendChild( $opt );
	}

	$form->appendChild( $session->render_action_buttons( 
		test => $session->phrase( "Plugin/Screen/Import:action:test:title" ), 
		import => $session->phrase( "Plugin/Screen/Import:action:import:title" ) ) );

	return $page;

}

1;
