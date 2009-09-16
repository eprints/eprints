
#remove !
package EPrints::Plugin::Screen::EPrint::Error;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub render
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	return $chunk;
}

# ignore the form. We're screwed at this point, and are just reporting.
sub from
{
	my( $self ) = @_;

	return;
}

1;

