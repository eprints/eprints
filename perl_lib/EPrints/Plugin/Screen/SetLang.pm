package EPrints::Plugin::Screen::SetLang;

use EPrints::Plugin::Screen;
@ISA = qw( EPrints::Plugin::Screen );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	return $self;
}

sub redirect_to_me_url
{
	return undef;
}

sub wishes_to_export
{
	my( $self ) = @_;

	my $referer = EPrints::Apache::AnApache::header_in(
		$self->{session}->get_request,
		'Referer' );

	$self->{processor}->{referer} = $referer;

	return EPrints::Utils::is_set( $referer );
}

sub export
{
	my( $self ) = @_;

	my $session = $self->{session};

	$self->set_cookie();

	return $self->{session}->redirect( $self->{processor}->{referer} );
}

sub set_cookie
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $langid = $session->param( "lang" );
	$langid = "" if !defined $langid;

	my $cookie = $session->{query}->cookie(
		-name    => "eprints_lang",
		-path    => "/",
		-expires => 0,
		-value   => $langid,
		-expires => ($langid ? "+10y" : "+0s"), # really long time
		-domain  => $session->config("cookie_domain") );
	$session->{request}->err_headers_out->add('Set-Cookie' => $cookie);
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	$self->set_cookie();

	# Don't where else to send the user
	$session->redirect( $session->config( "home_page" ) );
	exit( 0 );
}

sub EPrints::Script::Compiled::run_languages
{
	my( $self, $state ) = @_;

	my $session = $state->{session};

	my $xml = $session->xml;
	my $f = $xml->create_document_fragment;

	my $languages = $session->config( "languages" );

	if( @$languages == 1 )
	{
		return [ $f, "XHTML" ];
	}

	my $imagesurl = $session->config( "rel_path" )."/images/flags";
	my $scripturl = $session->current_url( path => "cgi", "set_lang" );

	my $div = $xml->create_element( "div", id => "ep_tm_languages" );
	$f->appendChild( $div );

	foreach my $langid (@$languages)
	{
		next if $langid eq $session->get_lang->get_id;
		my $clangid = $session->get_lang()->get_id;
		$session->change_lang( $langid );
		my $title = $session->phrase( "languages_typename_$langid" );
		$session->change_lang( $clangid );
		my $link = $xml->create_element( "a",
			href => "$scripturl?lang=$langid",
			title => $title,
		);
		my $img = $xml->create_element( "img",
			src => "$imagesurl/$langid.png",
			align => "top",
			border => 0,
			alt => $title,
		);
		$link->appendChild( $img );
		$div->appendChild( $link );
	}

	my $title = $session->phrase( "cgi/set_lang:clear_cookie" );
	my $link = $xml->create_element( "a",
		href => $scripturl,
		title => $title,
	);
	my $img = $xml->create_element( "img",
		src => "$imagesurl/aero.png",
		align => "top",
		border => 0,
		alt => $title,
	);
	$link->appendChild( $img );
	$div->appendChild( $link );

	return [ $div, "XHTML" ];
}

1;
