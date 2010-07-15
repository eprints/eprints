package EPrints::Plugin::Search::Internal;

@ISA = qw( EPrints::Search EPrints::Plugin::Search );

sub new
{
	my( $class, %params ) = @_;

	# needs a bit of hackery to wrap EPrints::Search
	my $self = defined $params{dataset} ?
		$class->SUPER::new( %params ) :
		$class->EPrints::Plugin::Search::new( %params )
	;

	$self->{id} = $class;
	$self->{id} =~ s/^EPrints::Plugin:://;
	$self->{qs} = 0; # internal search is default
	$self->{search} = [qw( simple/* advanced/* )];
	$self->{session} = $self->{repository} = $self->{session} || $self->{repository};

	return $self;
}

sub from_form
{
	my( $self ) = @_;

	return map { $_->from_form() } $self->get_non_filter_searchfields;
}

sub from_string
{
	my( $self, $exp ) = @_;

	$self->SUPER::from_string( $exp );

	return 1;
}

sub render_simple_fields
{
	my( $self ) = @_;

	return ($self->get_non_filter_searchfields)[0]->render;
}

1;
