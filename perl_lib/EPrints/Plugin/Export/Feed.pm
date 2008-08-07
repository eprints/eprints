package EPrints::Plugin::Export::Feed;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Abstract Feed";
	$self->{icon} = "feed-icon-14x14.png";
	$self->{visible} = "";
	
	return $self;
}

sub is_feed { return 1; }

1;
