package EPrints::Plugin::Screen::EPrint::Box;

our @ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	# Register sub-classes but not this actual class.
	if( $class ne "EPrints::Plugin::Screen::EPrint::Box" )
	{
		$self->{appears} = [
			{
				place => "summary_right",
				position => 1000,
			},
		];
	}

	return $self;
}

sub render_collapsed { return 0; }

sub can_be_viewed { return 1; }

sub render
{
	my( $self ) = @_;

	return $self->{handle}->make_text( "Please add a 'render' method to this box!" );
}

1;

