package EPrints::Plugin::Export::ListUserEmails;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "List of Email Addresses";
	$self->{accept} = [ 'dataobj/user', 'list/user' ];
	$self->{visible} = "staff";
	$self->{suffix} = "text";
	$self->{mimetype} = "text/plain";

	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $email = $dataobj->get_value( "email" );
	if( !defined $email ) 
	{
		return "";
	}

	return "$email\n";
}


1;
