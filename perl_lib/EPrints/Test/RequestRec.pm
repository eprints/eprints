package EPrints::Test::RequestRec;

# fake mod_perl query package

sub new
{
	my( $class, %opts ) = @_;

	return bless \%opts, $class;
}

sub uri
{
	my( $self ) = @_;

	return $self->{uri};
}

1;
