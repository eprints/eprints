package EPrints::Plugin::Export::HTMLFile;

# This virtual super-class supports Unicode output

our @ISA = qw( EPrints::Plugin::Export );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{mimetype} = "text/html; charset=utf-8";
	$self->{suffix} = ".html";

	return $self;
}

sub initialise_fh
{
	my( $plugin, $fh ) = @_;

	binmode($fh, ":utf8");
}

1;
