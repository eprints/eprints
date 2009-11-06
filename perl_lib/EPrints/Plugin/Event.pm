package EPrints::Plugin::Event;

@ISA = qw( EPrints::Plugin );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Base event plugin: This should have been subclassed";
	$self->{visible} = "all";
	$self->{advertise} = 1;

	return $self;
}

1;
