package EPrints::Plugin::Event;

@ISA = qw( EPrints::Plugin );

use strict;

sub new
{
	my( $class, %params ) = @_;

	$params{visible} = exists $params{visible} ? $params{visible} : "all";
	$params{advertise} = exists $params{advertise} ? $params{advertise} : 1;

	return $class->SUPER::new(%params);
}

1;
