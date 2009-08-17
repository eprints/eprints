package EPrints::Plugin::InputForm::Surround::None;

use strict;

our @ISA = qw/ EPrints::Plugin /;


sub render
{
	my( $self, $component ) = @_;

	my $surround = $self->{handle}->make_element( "div", class => "ep_sr_none" );
	foreach my $field_id ( $component->get_fields_handled )
	{
		$surround->appendChild( $self->{handle}->make_element( "a", name=>$field_id ) );
	}
	
	$surround->appendChild( $component->render_content( $self ) );

	return $surround;
}


1;
