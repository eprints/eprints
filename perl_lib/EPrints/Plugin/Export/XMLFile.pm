package EPrints::Plugin::Export::XMLFile;

# This virtual super-class supports Unicode output

our @ISA = qw( EPrints::Plugin::Export );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{mimetype} = "text/xml; charset=utf-8";
	$self->{suffix} = ".xml";

	return $self;
}

sub initialise_fh
{
	my( $plugin, $fh ) = @_;

	binmode($fh, ":utf8");
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	my $xml = $self->xml_dataobj( $dataobj, %opts );
	my $r = EPrints::XML::to_string( $xml );
	EPrints::XML::dispose( $xml );

	return $r;
}

1;
