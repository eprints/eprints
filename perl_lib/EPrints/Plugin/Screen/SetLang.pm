=head1 NAME

EPrints::Plugin::Screen::SetLang

=cut

package EPrints::Plugin::Screen::SetLang;

use EPrints::Plugin::Screen;
@ISA = qw( EPrints::Plugin::Screen );

use strict;

sub from
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

	my $referrer = $session->param( "referrer" );
        $referrer = EPrints::Apache::AnApache::header_in( $session->get_request, 'Referer' ) unless( EPrints::Utils::is_set( $referrer ) );
	$referrer = $session->config( "home_page" ) unless( EPrints::Utils::is_set( $referrer ) );

	$self->{processor}->{redirect} = $referrer;
}

sub render_action_link
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $xml = $repo->xml;
	my $f = $xml->create_document_fragment;

	my $languages = $repo->config( "languages" );
	return $f if @$languages == 1;

	$f->appendChild( my $ul = $xml->create_element( "ul",
			class => "ep_tm_languages",
		) );

	my $uri = $repo->get_url( path => "cgi", "set_lang" );
	$uri->query_form( referrer => $repo->get_url( host => 1, query => 1 ) )
		if $repo->get_online;

	foreach my $langid (@$languages)
	{
		my $u = $uri->clone;
		$u->query_form(
				$uri->query_form,
				lang => $langid,
			);
		{
			local $repo->{lang};
			$repo->change_lang( $langid );
			$ul->appendChild( $xml->create_data_element( "li", [
					[ "a", $repo->html_phrase( "languages_typename_".$langid ), href => $u ]
				]) );
		}
	}

	$ul->appendChild( $xml->create_data_element( "li", [
			[ "a", $repo->html_phrase( "cgi/set_lang:clear_cookie" ), href => $uri ]
		]) );

	return $f;
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

