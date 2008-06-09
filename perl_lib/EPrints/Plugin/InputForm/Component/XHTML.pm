package EPrints::Plugin::InputForm::Component::XHTML;

use EPrints::Plugin::InputForm::Component;

@ISA = ( "EPrints::Plugin::InputForm::Component" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "XHTML";
	$self->{visible} = "all";
	$self->{surround} = "Light" unless defined $self->{surround};
	return $self;
}

=pod

=item $bool = $component->parse_config( $dom )

Parses the supplied DOM object and populates $component->{config}

=cut

sub parse_config
{
	my( $self, $dom ) = @_;

	$self->{config}->{dom} = $dom;
}

=pod

=item $content = $component->render_content()

Returns the DOM for the content of this component.

=cut


sub render_content
{
	my( $self ) = @_;

	return $self->{config}->{dom};
}

1;





