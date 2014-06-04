######################################################################
#
# EPrints::MetaField::Recaptcha;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Recaptcha> - a Captcha

=head1 DESCRIPTION

This field renders a Captcha (a test that only humans can easily pass). It uses the "reCaptcha" service (http://recaptcha.net/). A single database text column is used to store the captcha error code.

Two configuration options are required to define the reCaptcha keys:

	$c->{recaptcha}->{private_key} = "PRIVATE_KEY";
	$c->{recaptcha}->{public_key} = "PUBLIC_KEY";

You can get these keys by registering at http://recaptcha.net/.

=over 4

=cut

package EPrints::MetaField::Recaptcha;

use EPrints::MetaField::Id;
@ISA = qw( EPrints::MetaField::Id );

use strict;

sub is_virtual { 1 }


sub validate
{
	my( $self, $session, $value, $object ) = @_;

	my @probs;

	if( $value )
	{
		push @probs, $session->html_phrase( "validate:recaptcha_mismatch" );
	}

	return @probs;
}

######################################################################
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

