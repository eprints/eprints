
package EPrints::Plugin::Screen::Error;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub render
{
	my( $self ) = @_;

	my $chunk = $self->{handle}->make_doc_fragment;

	return $chunk;
}

# ignore the form. We're screwed at this point, and are just reporting.
sub from
{
	my( $self ) = @_;

	return;
}

1;

