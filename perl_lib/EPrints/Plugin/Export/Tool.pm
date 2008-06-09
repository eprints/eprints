package EPrints::Plugin::Export::Tool;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Abstract Tool";
	$self->{visible} = "";
	
	return $self;
}

sub is_tool { return 1; }

sub icon { return "tool-icon.png"; }

1;
