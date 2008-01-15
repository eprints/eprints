
package EPrints::Plugin::Screen::Import;

use EPrints::Plugin::Screen;

use Fcntl qw(:DEFAULT :seek);
use File::Temp qw/ tempfile /;

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

sub can_be_viewed
{
	my( $self ) = @_;
	return $self->allow( "create_eprint" );
}

sub allow_test
{
	my( $self ) = @_;
	return $self->can_be_viewed;
}

sub allow_import
{
	my( $self ) = @_;
	return $self->allow_test;
}

sub action_test
{
	my ( $self ) = @_;

	my $tmp_file = $self->make_tmp_file;
	return if !defined $tmp_file;

	$self->_import( 1, 0, $tmp_file ); # dry run with messages

	undef $tmp_file;
}

sub action_import
{
	my ( $self ) = @_;

	my $tmp_file = $self->make_tmp_file;
	return if !defined $tmp_file;

	my $ok = $self->_import( 1, 1, $tmp_file ); # quiet dry run
	$self->_import( 0, 0, $tmp_file ) if $ok; # real run with messages

	undef $tmp_file;

	$self->{processor}->{screenid} = "Items";
}


sub make_tmp_file
{
	my ( $self ) = @_;

	# Write import records to temp file
	my $tmp_file = new File::Temp;
	$tmp_file->autoflush;

	my $import_fh = $self->{session}->{query}->upload( "import_filename" );
	my $import_data = $self->{session}->param( "import_data" );

	unless( defined $import_fh || ( defined $import_data && $import_data ne "" ) )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "nothing_to_import" ) );
		return undef;
	}

	if( defined $import_fh )
	{
		seek( $import_fh, 0, SEEK_SET );

		my( $buffer );
		while( read( $import_fh, $buffer, 1024 ) )
		{
			print $tmp_file $buffer;
		}
	}
	else
	{
		print $tmp_file $import_data;
	}

	return $tmp_file;
}

sub _import
{
	my( $self, $dryrun, $quiet, $tmp_file ) = @_;

	my $session = $self->{session};
	my $ds = $session->get_repository->get_dataset( "inbox" );

	# Build command
	my $import_script = $EPrints::SystemSettings::conf->{base_path}."/bin/import";
	my $ds_id = "inbox";
	my $cmd = $import_script." --scripted ".$session->get_repository->get_id." ".$ds_id." ".$self->{processor}->{plugin}->get_subtype." --user ".$self->{processor}->{user}->get_id." ".$tmp_file->filename;
	$cmd .= " --parse-only" if $dryrun;

	# Run command without user check
	my $pid = open( OUTPUT, "EPRINTS_NO_CHECK_USER=1 $cmd 2>&1|" );
	my @imp_out = <OUTPUT>;
	close OUTPUT;

	# Parse command output
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
			$self->{processor}->add_message( "message", $self->html_phrase(
				"test_completed", 
				count => $session->make_text( $parsed ) ) ) unless $quiet;
		}
		else
		{
			$self->{processor}->add_message( "warning", $self->html_phrase( 
				"test_failed", 
				count => $session->make_text( $parsed ) ) );
		}
	}
	else
	{
		if( $ok )
		{
			$self->{processor}->add_message( "message", $self->html_phrase( 
				"import_completed", 
				count => $session->make_text( $list->count ) ) );
		}
		else
		{
			$self->{processor}->add_message( "warning", $self->html_phrase( 
				"import_failed", 
				count => $session->make_text( $list->count ) ) );
		}
	}

	if( scalar @misc > 0 && !$quiet )
	{
		my $text = substr(join( "", @misc[0..99]),0,40000);
		my @lines = EPrints::DataObj::History::_mktext( $session, $text, 0, 0, 80 );

		my $pre = $session->make_element( "pre" );
		$pre->appendChild( $session->make_text( join( "\n", @lines ) ) );
		$self->{processor}->add_message( "warning", $self->html_phrase(
			"import_errors",
			errors => $pre ) );
	}

	return $ok;

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

	# Preamble
	$page->appendChild( $self->html_phrase( "intro" ) );

	my $form =  $session->render_form( "post" );
	$form->appendChild( $session->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
	$page->appendChild( $form );

	my $table = $session->make_element( "table", width=>"100%" );

	my $frag = $session->make_doc_fragment;
	$frag->appendChild( $session->make_element(
		"textarea",
		name => "import_data",
		rows => 10,
		cols => 50,
		wrap => "virtual" ) );
	$frag->appendChild( $session->make_element( "br" ) );
	$frag->appendChild( $session->make_element( "br" ) );
	$frag->appendChild( $session->render_upload_field( "import_filename" ) );

	$table->appendChild( $session->render_row_with_help(
		help => $session->make_doc_fragment,
		label => $self->html_phrase( "step1" ),
		class => "ep_first",
		field => $frag,
	));
	
	my @plugins = $session->plugin_list( 
			type=>"Import",
			is_advertised=>1,
			can_produce=>"list/".$ds->confid );

	my $select = $session->make_element( "select", name => "pluginid" );
	$table->appendChild( $session->render_row_with_help(
		help => $session->make_doc_fragment,
		label => $self->html_phrase( "step2" ),
		field => $select,
	));
	
	for( @plugins )
	{
		my $plugin = $session->plugin( $_ );
		next if $plugin->broken;
		my $opt = $session->make_element( "option", value => $_  );
		$opt->setAttribute( "selected", "selected" ) if $self->{processor}->{plugin} && $_ eq $self->{processor}->{plugin}->get_id;
		$opt->appendChild( $plugin->render_name );
		$select->appendChild( $opt );
	}

	$form->appendChild( $session->render_toolbox( undef, $table ) );

	$form->appendChild( $session->render_action_buttons( 
		_class => "ep_form_button_bar",
		test => $self->phrase( "action:test:title" ), 
		import => $self->phrase( "action:import:title" ) ) );

	return $page;

}

1;
