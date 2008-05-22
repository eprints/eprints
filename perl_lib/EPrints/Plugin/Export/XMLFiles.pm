package EPrints::Plugin::Export::XMLFiles;

use Unicode::String qw( utf8 );

use EPrints::Plugin::Export::XML;

@ISA = ( "EPrints::Plugin::Export::XML" );

use strict;

# The utf8() method is called to ensure that
# any broken characters are removed. There should
# not be any broken characters, but better to be
# sure.



sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "EP3 XML with Files Embeded";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];

	# this module outputs the files of an eprint with
	# no regard to the security settings so should be 
	# not made public without a very good reason.
	$self->{visible} = "staff";

	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";

	return $self;
}

sub xml_dataobj
{
	my( $plugin, $dataobj ) = @_;

	return $dataobj->to_xml( embed=>1 );
}

1;
