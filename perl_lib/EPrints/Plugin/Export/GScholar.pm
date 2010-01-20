package EPrints::Plugin::Export::GScholar;

use EPrints::Plugin::Export;
@ISA = ( "EPrints::Plugin::Export" );

use GScholar;

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Google Scholar Update";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "staff";
	$self->{advertise} = "no";
	$self->{suffix} = ".txt";
	$self->{mime_type} = "text/plain";

	return $self;
}

sub output_dataobj
{
	my( $self, $eprint ) = @_;

	if( !$eprint->get_dataset->has_field( "gscholar" ) )
	{
		EPrints::abort("Missing gscholar field");
	}
	my $field = $eprint->get_dataset->get_field( "gscholar" );

	my $cite_data = GScholar::get_cites( $self->{session}, $eprint );
	if( EPrints::Utils::is_set( $cite_data ) )
	{
		$cite_data->{datestamp} = EPrints::Time::get_iso_timestamp();
		$eprint->set_value( "gscholar", $cite_data );
		$eprint->commit;
	}
	return $eprint->get_id . "\n";
}

1;
