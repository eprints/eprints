package EPrints::Plugin::Export::ContextObject::DublinCore;

use EPrints::Plugin::Export::OAI_DC;

use EPrints::Plugin::Export::ContextObject;

@ISA = ( "EPrints::Plugin::Export::ContextObject" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "OpenURL DublinCore";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "";

	return $self;
}

sub xml_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $dc = $plugin->{session}->plugin( "Export::OAI_DC" );

	return $dc->xml_dataobj( $dataobj, %opts );
}

sub kev_dataobj
{
	my( $plugin, $dataobj, $ctx ) = @_;

	my $dc = $plugin->{session}->plugin( "Export::DC" );

	my $data = $dc->convert_dataobj( $dataobj );

	@$data = map { @$_ } @$data;

	$ctx->dublinCore(@$data);
}

1;
