package EPrints::Plugin::Screen::EPrint::Staff::Actions;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint::Actions' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 300,
		}
	];

	return $self;
}

sub who_filter { return 8; }

1;
