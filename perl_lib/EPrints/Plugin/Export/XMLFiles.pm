package EPrints::Plugin::Export::XMLFiles;

use EPrints::Plugin::Export::XML;

@ISA = ( "EPrints::Plugin::Export::XML" );

use strict;

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

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	return $self->SUPER::output_dataobj( $dataobj, %opts, embed => 1 );
}

1;
