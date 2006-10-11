
package EPrints::Plugin::Screen::Search::User;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;


sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;

	return $session->make_doc_fragment;
}

1;
