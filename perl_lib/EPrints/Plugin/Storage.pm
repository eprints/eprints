package EPrints::Plugin::Storage;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Storage::DISABLE = 1;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Storage abstraction layer: this plugin should have been subclassed";

	return $self;
}

sub matches 
{
	my( $self, $test, $param ) = @_;

	if( $test eq "is_available" )
	{
		return( $self->is_available() );
	}

	# didn't understand this match 
	return $self->SUPER::matches( $test, $param );
}

sub is_available
{
	my( $self ) = @_;

	return 1;
}

sub store
{
	my( $self, $dataobj, $uri, $fh ) = @_;
}

sub retrieve
{
	my( $self, $dataobj, $uri ) = @_;
}

sub delete
{
	my( $self, $dataobj, $uri ) = @_;
}

sub get_size
{
	my( $self, $dataobj, $uri ) = @_;
}

1;
