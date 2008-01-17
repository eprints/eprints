package EPrints::Plugin::Screen::Admin::Config::Edit;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [ "save_config", "revert_config" ];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{configfile} = $self->{session}->param( "configfile" );
	$self->{processor}->{configfilepath} = $self->{session}->get_repository->get_conf( "config_path" )."/".$self->{processor}->{configfile};

	if( $self->{processor}->{configfile} =~ m/\/\./ )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", $self->{session}->html_phrase(
			"Plugin/Screen/Admin/Config/Edit:bad_filename",
			filename=>$self->{session}->make_text( $self->{processor}->{configfile} ) ) );
		return;
	}
	if( !-e $self->{processor}->{configfilepath} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", $self->{session}->html_phrase(
			"Plugin/Screen/Admin/Config/Edit:no_such_file",
			filename=>$self->{session}->make_text( $self->{processor}->{configfilepath} ) ) );
		return;
	}

	$self->SUPER::properties_from;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0; # needs to be subclassed
}
sub allow_save_config
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}
sub allow_revert_config
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

# return an array of DOM explanations of issues with this file
# empty array if it's OK
# this does not test in context, just validates XML etc.
sub validate_config_file
{
	my( $self, $data ) = @_;

	return( );
}

sub save_broken
{
	my( $self, $data ) = @_;

	my $fn = $self->{processor}->{configfilepath}.".broken";
	unless( open( DATA, ">$fn" ) )
	{
		$self->{processor}->add_message( 
			"error", 
			$self->html_phrase( "could_not_write", 
				error_msg=>$self->{session}->make_text($!), 
				filename=>$self->{session}->make_text( $fn )));
		return;
	}
	print DATA $data;
	close DATA;
}


sub action_revert_config
{
	my( $self ) = @_;

	my $fn = $self->{processor}->{configfilepath}.".broken";

	return if( !-e $fn );

	unlink( $fn );

	$self->{processor}->add_message( 
		"message", 
		$self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:reverted" )
	);
		
}

sub action_save_config
{
	my( $self ) = @_;

	my $data = $self->{session}->param( "data" );
	
	# de-dos da data
	$data =~ s/\r\n/\n/g;	

	if( !defined $data )
	{
		$self->{processor}->add_message( 
			"error", 
			$self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:no_data" )
		);
		return;
	}

	# first check our file in RAM 
	my @file_problems = $self->validate_config_file( $data );
	if( scalar @file_problems )
	{
		# -- if it fails: report an error and save it to a .broken file then abort
		$self->{processor}->add_message( 
			"error", 
			$self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:did_not_install" )
		);
		foreach my $problem ( @file_problems )
		{
			$self->{processor}->add_message( "warning", $problem );
		}
		$self->save_broken( $data );
		return;
	}

	my $fn = $self->{processor}->{configfilepath};

	# copy the current (probably good) file to .backup

	rename( $fn, "$fn.backup" );	

	# install the new file
	unless( open( DATA, ">$fn" ) )
	{
		$self->{processor}->add_message( 
			"error", 
			$self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:could_not_write", 
				error_msg=>$self->{session}->make_text($!), 
				filename=>$self->{session}->make_text( $self->{processor}->{configfilepath} ) ) );
		return;
	}
	print DATA $data;
	close DATA;

	# then test using epadmin

	my( $result, $msg ) = $self->{session}->get_repository->test_config;

	if( $result != 0 )
	{
		# -- if it fails: move the old file back, report an error and save new file to a .broken file then abort
		rename( $fn, "$fn.broken" );
		rename( "$fn.backup", $fn );

		$self->{processor}->add_message( 
			"error", 
			$self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:did_not_install" )
		);
		my $pre = $self->{session}->make_element( "pre" );
		$pre->appendChild( $self->{session}->make_text( $msg ) );
		$self->{processor}->add_message( "warning", $pre );
		return;
	}


	unlink( "$fn.broken" ) if( -e "$fn.broken" );
	unlink( "$fn.backup" ) if( -e "$fn.backup" );

	$self->{processor}->add_message( 
		"message", 
		$self->{session}->html_phrase( 
			"Plugin/Screen/Admin/Config/Edit:file_saved",
			filename=>$self->{session}->make_text( $self->{processor}->{configfilepath} ) ) );
}

sub render_title
{
	my( $self ) = @_;

	my $f = $self->{session}->make_doc_fragment;
	$f->appendChild( $self->html_phrase( "page_title", file=>$self->{session}->make_text( $self->{processor}->{configfile} ) ) );
	return $f;
}

sub render
{
	my( $self ) = @_;

	# we trust the filename by this point
	
	my $path = $self->{session}->get_repository->get_conf( "config_path" );

	my $page = $self->{session}->make_doc_fragment;

	$page->appendChild( $self->html_phrase( "intro" ));

	my $form = $self->render_form;
	$page->appendChild( $form );

	my $fn = $self->{processor}->{configfilepath};
	my $broken = 0;
	if( -e "$fn.broken" )
	{
		$broken = 1;
		$fn = "$fn.broken";
		$self->{processor}->add_message( 
			"warning", 
			$self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:broken" ) );
	}

	my $textarea = $self->{session}->make_element( "textarea", rows=>25, cols=>80, name=>"data" );
	open( CONFIGFILE, $fn );
	while( my $line = <CONFIGFILE> ) { $textarea->appendChild( $self->{session}->make_text( $line) ); }
	close CONFIGFILE;
	$form->appendChild( $textarea );

	my %buttons;

       	push @{$buttons{_order}}, "save_config";
       	$buttons{save_config} = $self->{session}->phrase( "Plugin/Screen/Admin/Config/Edit:save_config_button" );

	if( $broken )
	{
        	push @{$buttons{_order}}, "revert_config";
        	$buttons{revert_config} = $self->{session}->phrase( "Plugin/Screen/Admin/Config/Edit:revert_config_button" );
	}

	$form->appendChild( $self->{session}->render_action_buttons( %buttons ) );

	return $page;
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;
	$chunk->appendChild( $self->{session}->render_hidden_field( "configfile", $self->{processor}->{configfile} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url."&configfile=".$self->{processor}->{configfile};
}

sub register_furniture
{
	my( $self ) = @_;

	$self->SUPER::register_furniture;

	my $link = $self->{session}->render_link( "?screen=Admin::Config" );

	$self->{processor}->before_messages( $self->{session}->html_phrase( 
		"Plugin/Screen/Admin/Config:back_to_config",
		link=>$link ) );
}

1;
