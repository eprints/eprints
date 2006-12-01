
package EPrints::Plugin::Screen::Import;

use EPrints::Plugin::Screen;

use Fcntl qw(:DEFAULT :seek);

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ dryrun import /];

	# TODO uncomment when ready for primetime
	#$self->{appears} = [
	#	{
	#		place => "item_tools",
	#		action => "import",
	#		position => 200,
	#	}
	#];

	return $self;
}

sub allow_import
{
	my ( $self ) = @_;

	return $self->allow( "create_eprint" );
}

sub action_import
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $ds = $session->get_repository->get_dataset( "inbox" );

	my $pluginid = $session->param( "pluginid" );
	my $plugin = $session->plugin( $pluginid, dataset=>$ds ); #, parseonly=>1 );
	if( !defined $plugin || $plugin->broken )
	{
		$self->{processor}->add_message( "error", $session->html_phrase( "general:bad_param" ) );
		return;
	}

	my $req_plugin_type = "list/eprint";
	unless( $plugin->can_produce( $req_plugin_type ) )
	{
		$self->{processor}->add_message( "error", $session->html_phrase( "general:bad_param" ) );
		return;
	}


	my $fh = $session->{query}->upload( "importfile" );


	seek( $fh, 0, SEEK_SET );

	my( $buffer );

	my $tmp_file = "/tmp/eprints.import.$$";
	open( TMP, ">$tmp_file" ) || die "Could not write to $tmp_file";
	while( read( $fh, $buffer, 1024 ) )
	{
		print TMP $buffer;
	}
	close TMP;

	my $import_script = $EPrints::SystemSettings::conf->{base_path}."/bin/import";
	my $ds_id = "inbox";
	my $cmd = $import_script." --scripted ".$session->get_repository->get_id." ".$ds_id." ".$plugin->get_subtype." --user ".$self->{processor}->{user}->get_id." ".$tmp_file;

#	print STDERR "$cmd\n";

	my $pid = open( OUTPUT, "EPRINTS_NO_CHECK_USER=1 $cmd 2>&1|" );
	my @imp_out = <OUTPUT>;
	close OUTPUT;

	if( -e $tmp_file )
	{
		unlink( $tmp_file );
	}

	my @misc = ();
	my $ok = 0;
	my @ids;
	foreach my $line ( @imp_out )
	{
		if( $line !~ s/^EPRINTS_IMPORT: // )
		{
			push @misc,$line;
			next;
		}
		chomp $line;
		if( $line =~ m/ITEM_IMPORTED (\d+)/ )
		{
			push @ids, $1;
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

	if( $ok && $list->count > 0)
	{
		if( scalar @misc > 0 )
		{
			my $pre = $session->make_element( "pre" );
			$pre->appendChild( $session->make_text( join( "",$misc[0..99]) ) );
			$self->{processor}->add_message( "warning", $pre );
		}
		$self->{processor}->add_message( "message", $session->make_text( "Imported: ".$list->count ));
		$self->{processor}->{screenid} = "Items";
	}
	else
	{
		my $pre = $session->make_element( "pre" );
		$pre->appendChild( $session->make_text( join( "",$misc[0..99]) ) );
		$self->{processor}->add_message( "error", $pre );
	}

	# not used yet.
}

sub allow_dryrun
{
	my ( $self ) = @_;

	return $self->allow( "create_eprint" );
} 

sub action_dryrun
{
}

sub render
{
	my ( $self ) = @_;

	my $session = $self->{session};
	my $ds = $session->get_repository->get_dataset( "inbox" );

	my $page = $session->make_doc_fragment;

	# TODO: preamble/instructions

	my $form =  $session->render_form( "post" );
	$page->appendChild( $form );

	# TODO: cut and paste?
	#my $textarea = $session->make_element( "textarea", 
	#	name => "data",
	#	"accept-charset" => "utf-8",
	#	wrap => "virtual",
	#);
	#$form->appendChild( $textarea );
	#$form->appendChild( $session->make_element( "br" ) );

	$form->appendChild( $session->render_upload_field( "importfile" ) );
	$form->appendChild( $session->make_element( "br" ) );

	$form->appendChild( $session->render_hidden_field( "screen", $self->{processor}->{screenid} ) );

	my @plugins = $session->plugin_list( 
				type=>"Import",
				can_produce=>"dataobj/".$ds->confid );

	my $select = $session->make_element( "select", name => "pluginid" );
	$form->appendChild( $select );

	for( @plugins )
	{
		my $plugin = $session->plugin( $_ );
		next if $plugin->broken;
		my $opt = $session->make_element( "option", value => $_ );
		$opt->appendChild( $plugin->render_name );
		$select->appendChild( $opt );
	}

	$form->appendChild( $session->render_action_buttons( import => $session->phrase( "action/import" ) ) );

	return $page;

}
