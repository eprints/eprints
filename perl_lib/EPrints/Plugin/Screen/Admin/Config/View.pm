package EPrints::Plugin::Screen::Admin::Config::View;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	return $class->SUPER::new(%params);
}

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{configfile} = $self->{handle}->param( "configfile" );
	$self->{processor}->{configfilepath} = $self->{handle}->get_repository->get_conf( "config_path" )."/".$self->{processor}->{configfile};

	if( $self->{processor}->{configfile} =~ m/\/\./ )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", $self->{handle}->html_phrase(
			"Plugin/Screen/Admin/Config/Edit:bad_filename",
			filename=>$self->{handle}->make_text( $self->{processor}->{configfile} ) ) );
		return;
	}
	if( !-e $self->{processor}->{configfilepath} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", $self->{handle}->html_phrase(
			"Plugin/Screen/Admin/Config/Edit:no_such_file",
			filename=>$self->{handle}->make_text( $self->{processor}->{configfilepath} ) ) );
		return;
	}

	$self->SUPER::properties_from;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0; # needs to be subclassed!
}

sub render_title
{
	my( $self ) = @_;

	my $f = $self->{handle}->make_doc_fragment;
	$f->appendChild( $self->html_phrase( "page_title", file=>$self->{handle}->make_text( $self->{processor}->{configfile} ) ) );
	return $f;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url."&eprintid=".$self->{processor}->{eprintid};
}

sub render
{
	my( $self ) = @_;

	# we trust the filename by this point
	
	my $path = $self->{handle}->get_repository->get_conf( "config_path" );

	my $page = $self->{handle}->make_doc_fragment;

	my $edit_screen_id = "Screen::".$self->{processor}->{screenid};
	$edit_screen_id =~ s/::View::/::Edit::/;
	my $edit_screen = $self->{handle}->plugin( $edit_screen_id, processor => $self->{processor} );

	$self->{processor}->{screenid}=~m/::View::(.*)$/;
	my $doc_link = $self->{handle}->render_link("http://eprints.org/d/?keyword=${1}ConfigFile&filename=".$self->{processor}->{configfile});
	$page->appendChild( $self->{handle}->html_phrase( "Plugin/Screen/Admin/Config/View:documentation", link=>$doc_link ));

	if( $edit_screen->can_be_viewed )
	{
		my $form = $edit_screen->render_form;
		$page->appendChild( $form );
		my $edit_config_button = $edit_screen->render_action_button( 
		{
			screen => $edit_screen,
			screen_id => $edit_screen_id,
		} );
		my $buttons = $self->{handle}->make_element( "div" );
		$buttons->appendChild( $edit_config_button );
		$form->appendChild( $buttons );
	}

	my $pre = $self->{handle}->make_element( "pre", class=>"ep_config_viewfile" );
	open( CONFIGFILE, $self->{processor}->{configfilepath} );
	while( my $line = <CONFIGFILE> ) { $pre->appendChild( $self->{handle}->make_text( $line) ); }
	close CONFIGFILE;
	$page->appendChild( $pre );

	return $page;
}


sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{handle}->make_doc_fragment;
	$chunk->appendChild( $self->{handle}->render_hidden_field( "configfile", $self->{processor}->{configfile} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}

sub register_furniture
{
	my( $self ) = @_;

	$self->SUPER::register_furniture;

	my $link = $self->{handle}->render_link( "?screen=Admin::Config" );

	$self->{processor}->before_messages( $self->{handle}->html_phrase( 
		"Plugin/Screen/Admin/Config:back_to_config",
		link=>$link ) );
}


1;
