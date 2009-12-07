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

sub pool
{
	my( $self ) = @_;

	return $self->{pool} ||= EPrints::Test::Pool->new();
}

package EPrints::Test::Pool;

sub new
{
	my( $class, %opts ) = @_;

	$opts{cleanup} = [];

	return bless \%opts, $class;
}

sub cleanup_register
{
	my( $self, $f, $ctx ) = @_;

	unshift @{$self->{cleanup}}, [$f, $ctx];
}

1;
