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

1;
