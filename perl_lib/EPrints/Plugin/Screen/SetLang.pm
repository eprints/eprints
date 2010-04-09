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

	return 1;
}

sub export
{
	my( $self ) = @_;

	my $session = $self->{session};

	$self->set_cookie();

	my $referrer = $session->param( "referrer" );
	$referrer = $session->config( "home_page" ) if !EPrints::Utils::is_set( $referrer );

	return $self->{session}->redirect( $referrer );
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

sub render_action_link
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $xml = $session->xml;
	my $f = $xml->create_document_fragment;

	my $languages = $session->config( "languages" );

	if( @$languages == 1 )
	{
		return $f;
	}

	my $imagesurl = $session->config( "rel_path" )."/images/flags";
	my $scripturl = URI->new( $session->current_url( path => "cgi", "set_lang" ), 'http' );
	my $curl = "";
	if( $session->get_online )
	{
		$curl = $session->current_url( host => 1, query => 1 );
	}

	my $div = $xml->create_element( "div", id => "ep_tm_languages" );
	$f->appendChild( $div );

	foreach my $langid (@$languages)
	{
		next if $langid eq $session->get_lang->get_id;
		$scripturl->query_form(
			lang => $langid,
			referrer => $curl
		);
		my $clangid = $session->get_lang()->get_id;
		$session->change_lang( $langid );
		my $title = $session->phrase( "languages_typename_$langid" );
		$session->change_lang( $clangid );
		my $link = $xml->create_element( "a",
			href => "$scripturl",
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

	$scripturl->query_form( referrer => $curl );

	my $title = $session->phrase( "cgi/set_lang:clear_cookie" );
	my $link = $xml->create_element( "a",
		href => "$scripturl",
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

	return $div;
}

1;
