package EPrints::Plugin::Export::Bibliography;

@ISA = qw( EPrints::Plugin::Export );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Bibliography";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "";
	$self->{advertise} = 0;

	return $self;
}

sub convert_dataobj
{
	my( $self, $eprint ) = @_;

	my @refs;

	my $doc = $self->{session}->dataset( "document" )->search(
		filters => [
			{ meta_fields => [qw( content )], value => "bibliography" },
			{ meta_fields => [qw( format )], value => "text/xml" },
			{ meta_fields => [qw( eprintid )], value => $eprint->id },
		])->item( 0 );

	if( defined $doc )
	{
		my $buffer = "";
		$doc->stored_file( $doc->get_main )->get_file( sub { $buffer .= $_[0] } );
		my $xml = eval { $self->{session}->xml->parse_string( $buffer ) };
		if( defined $xml )
		{
			for($xml->documentElement->childNodes)
			{
				next if $_->nodeName ne "eprint";
				my $epdata = EPrints::DataObj::EPrint->xml_to_epdata(
					$self->{session},
					$_ );
				my $ep = EPrints::DataObj::EPrint->new_from_data(
					$self->{session},
					$epdata );
				push @refs, $ep;
			}
			$self->{session}->xml->dispose( $xml );
		}
	}
	elsif( $eprint->exists_and_set( "referencetext" ) )
	{
		my $bibl = $eprint->value( "referencetext" );
		for(split /\s*\n\s*\n+/, $bibl)
		{
			push @refs, $_;
		}
	}

	return \@refs;
}

1;
