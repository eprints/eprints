=head1 NAME

EPrints::Plugin::Screen::Admin::Config::View

=cut

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

	return 0; # needs to be subclassed!
}

sub render_title
{
	my( $self ) = @_;

	my $f = $self->{session}->make_doc_fragment;
	$f->appendChild( $self->html_phrase( "page_title", file=>$self->{session}->make_text( $self->{processor}->{configfile} ) ) );
	return $f;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url."&configfile=".$self->{processor}->{configfile};
}

sub render
{
	my( $self ) = @_;

	# we trust the filename by this point
	
	my $path = $self->{session}->get_repository->get_conf( "config_path" );

	my $page = $self->{session}->make_doc_fragment;

	my $edit_screen_id = "Screen::".$self->{processor}->{screenid};
	$edit_screen_id =~ s/::View::/::Edit::/;
	my $edit_screen = $self->{session}->plugin( $edit_screen_id, processor => $self->{processor} );

	$self->{processor}->{screenid}=~m/::View::(.*)$/;
	my $doc_link = $self->{session}->render_link("http://eprints.org/d/?keyword=${1}ConfigFile&filename=".$self->{processor}->{configfile});
	$page->appendChild( $self->{session}->html_phrase( "Plugin/Screen/Admin/Config/View:documentation", link=>$doc_link ));

	if( $edit_screen->can_be_viewed )
	{
		my $edit_config_button = $edit_screen->render_action_button( {
			screen => $edit_screen,
			screen_id => $edit_screen_id,
			hidden => {
				configfile => $self->{processor}->{configfile},
			}
		} );
		my $buttons = $self->{session}->make_element( "div" );
		$buttons->appendChild( $edit_config_button );
		$page->appendChild( $edit_config_button );
	}
	else
	{
		# As the priv is hard-coded in the Edit modules no other way to do this
		my $priv = $self->{processor}->{screenid};
		$priv =~ s/^.+:://;
		$priv = "+config/edit/\L$priv";
		my $content = $self->{session}->html_phrase( "Plugin/Screen/Admin/Config/View:enable_editing",
				privilege => $self->{session}->make_text( $priv ),
			);
		$page->appendChild( $self->{session}->render_message( "warning", $content ) );
	}

	my $pre = $self->{session}->make_element( "pre", class=>"ep_config_viewfile" );
	open( CONFIGFILE, $self->{processor}->{configfilepath} );
	while( my $line = <CONFIGFILE> ) { $pre->appendChild( $self->{session}->make_text( $line) ); }
	close CONFIGFILE;
	$page->appendChild( $pre );

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

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

