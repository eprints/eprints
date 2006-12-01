
package EPrints::Plugin::Screen::Import;

use EPrints::Plugin::Screen;

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

	my $filename = $session->param( "importfile" );
	my $fh = $session->{query}->upload( "importfile" );

	my $list = $plugin->input_list( dataset=>$ds, fh=>$fh, filename=>$filename );

	if( defined $list )
	{
		$list->map(
			sub {
				my( $session, $dataset, $eprint ) = @_;
				$eprint->set_value( "userid", $self->{processor}->{user}->get_id );
				$eprint->commit;
		} );
		# TODO add_message not working?
		# $self->{processor}->add_message( "message", $session->make_text( "Imported " . $list->count . " items" ) );
	}

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
