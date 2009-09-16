
package EPrints::Plugin::Screen::EPrint::View::Other;

use EPrints::Plugin::Screen::EPrint::View;

@ISA = ( 'EPrints::Plugin::Screen::EPrint::View' );

use strict;


sub who_filter { return 2; }

sub render_status
{
	my( $self ) = @_;

	my $status_fragment = $self->{session}->make_doc_fragment;

	return $status_fragment;
}

sub about_to_render 
{
	my( $self ) = @_;
}

1;

