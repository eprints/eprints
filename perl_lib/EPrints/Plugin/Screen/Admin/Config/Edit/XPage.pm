package EPrints::Plugin::Screen::Admin::Config::Edit::XPage;

use EPrints::Plugin::Screen::Admin::Config::Edit::XML;

@ISA = ( 'EPrints::Plugin::Screen::Admin::Config::Edit::XML' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
# See cfg.d/dynamic_template.pl
#		{
#			place => "key_tools",
#			position => 1250,
#			action => "edit",
#		},
	];

	$self->{actions} = [qw( edit )];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/edit/static" );
}

sub allow_edit
{
	my( $self ) = @_;

	$self->{processor}->{conffile} ||= $self->{session}->get_static_page_conf_file;

	return defined $self->{processor}->{conffile};
}
sub action_edit {} # dummy action for key_tools

sub render_action_link
{
	my( $self ) = @_;

	my $conffile = $self->{processor}->{conffile};

	my $uri = URI->new( $self->{session}->config( "http_cgiurl" ) );
	$uri->query_form(
		screen => substr($self->{id},8),
		configfile => $conffile,
	);

	my $link = $self->{session}->render_link( $uri );
	$link->appendChild( $self->{session}->html_phrase( "lib/session:edit_page" ) );

	return $link;
}

1;
