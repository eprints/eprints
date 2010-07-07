package EPrints::XML::SAX::PrettyPrint;

use strict;

our $AUTOLOAD;

sub new
{
	my( $class, %self ) = @_;

	$self{depth} = 0;

	return bless \%self, $class;
}

sub AUTOLOAD
{
	$AUTOLOAD =~ s/^.*:://;
	return if $AUTOLOAD =~ /^[A-Z]/;
	shift->{Handler}->$AUTOLOAD( @_ );
}

sub start_element
{
	my( $self, $data ) = @_;

	$self->{Handler}->characters({
		Data => "\n" . (" " x ($self->{depth} * 2))
	});

	$self->{depth}++;

	$self->{Handler}->start_element( $data );
}

sub characters
{
	my( $self, $data ) = @_;

	$self->{leaf} = 1;

	$self->{Handler}->characters( $data );
}

sub end_element
{
	my( $self, $data ) = @_;

	$self->{depth}--;

	if( !$self->{leaf} )
	{
		$self->{Handler}->characters({
			Data => "\n" . (" " x ($self->{depth} * 2))
		});
	}
	$self->{leaf} = 0;

	$self->{Handler}->end_element( $data );
}

sub end_document
{
	my( $self, $data ) = @_;

	$self->{Handler}->characters({
		Data => "\n"
	});

	$self->{Handler}->end_document( $data );
}

1;
