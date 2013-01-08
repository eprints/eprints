=for Pod2Wiki

=head1 NAME

B<EPrints::Cookie> - Cookie utility methods

=head1 DESCRIPTION

This module contains utility methods for generating and getting cookies.

=head1 METHODS

=over 4

=cut 

package EPrints::Cookie;

use strict;

=item $value = cookie( $repo, $name )

Return the value of the cookie named $name.

=cut

sub cookie
{
	my( $repo, $name ) = @_;

	return EPrints::Apache::AnApache::cookie( $repo->{request}, $name );
}

=item set_cookie( $repo, $name, $value [, %opts ] )

Set a cookie for the current session for HTTP.

=cut

sub set_cookie
{
	my( $repo, $name, $value, %opts ) = @_;

	my $cookie = $repo->{query}->cookie(
		-name    => $name,
		-path    => ($repo->config( "http_root" ) || '/'),
		-value   => $value,
		-domain  => $repo->config( "host" ),
		-expires => $repo->config( "user_cookie_timeout" ),
		%opts,
	);

	$repo->{request}->err_headers_out->add(
		'Set-Cookie' => $cookie
	);
}

=item set_secure_cookie( $repo, $name, $value [, %opts ] )

Set a cookie for the current session for HTTPS.

=cut

sub set_secure_cookie
{
	my( $repo, $name, $value, %opts ) = @_;

	my $cookie = $repo->{query}->cookie(
		-name    => $name,
		-path    => ($repo->config( "https_root" ) || '/'),
		-value   => $value,
		-domain  => $repo->config( "securehost" ),
		-secure  => 1,
		-expires => $repo->config( "user_cookie_timeout" ),
		%opts,
	);			

	$repo->{request}->err_headers_out->add(
		'Set-Cookie' => $cookie
	);
}

=back

=cut

1; # For use/require success

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2012 University of Southampton.

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

