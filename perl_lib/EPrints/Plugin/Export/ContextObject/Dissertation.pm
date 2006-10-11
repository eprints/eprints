package EPrints::Plugin::Export::ContextObject::Dissertation;

use Unicode::String qw( utf8 );

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

# The utf8() method is called to ensure that
# any broken characters are removed. There should
# not be any broken characters, but better to be
# sure.

our %MAPPING = qw(
	title	title
	pages	tpages
	date_effective	date
	institution	inst
	thesis_type	degree
);
our %TYPE_MAPPING = qw(
	article	article
	conference_item	conference
	misc	unknown
);

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "OpenURL Dissertation";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";

	return $self;
}





sub output_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $itemtype = $dataobj->get_dataset->confid;

	my $xml = $plugin->xml_dataobj( $dataobj, %opts );

	return EPrints::XML::to_string( $xml );
}

sub xml_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $session = $plugin->{ "session" };
	my $repository = $session->get_repository;

	my $jnl = $session->make_element(
		"dis:dissertation",
		"xmlns:dis" => "info:ofi/fmt:xml:xsd:dissertation",
		"xmlns:xsi" => "http://www.w3.org/2001/XML",
		"xsi:schemaLocation" => "info:ofi/fmt:xml:xsd:dissertation http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:dissertation",
	);

	if( $dataobj->is_set( "creators" ) )
	{
		my $auths = $session->make_element( "dis:authors" );
		$jnl->appendChild( $auths );

		foreach my $author ( @{$dataobj->get_value( "creators", 1 )} )
		{
			my $auth = $session->make_element( "dis:author" );
			$auths->appendChild( $auth );
			
			$auth->appendChild(
				$session->make_element( "dis:aulast" )
			)->appendChild(
				$session->make_text( $author->{ "family" } )
			);

			$auth->appendChild(
				$session->make_element( "dis:aufirst" )
			)->appendChild(
				$session->make_text( $author->{ "given" } )
			);
		}
	}
	
	while( my( $from, $to ) = each %MAPPING )
	{
		next unless $dataobj->is_set( $from );
		my $node = $session->make_element( "dis:$to" );
		$jnl->appendChild( $node );
		$node->appendChild( $session->make_text( $dataobj->get_value( $from )));
	}

	return $jnl;
}

1;
