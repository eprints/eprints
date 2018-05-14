=head1 NAME

EPrints::Plugin::InputForm::Surround::Light

=cut

package EPrints::Plugin::InputForm::Surround::Light;

use strict;

our @ISA = qw/ EPrints::Plugin /;


sub render
{
	my( $self, $component ) = @_;
	
	my $content_class="";

	my $surround = $self->{session}->make_element( "div", class => "ep_sr_component", id => $component->{prefix} );
	$surround->appendChild( $self->{session}->make_element( "a", name=>$component->{prefix} ) );
	foreach my $field_id ( $component->get_fields_handled )
	{
		$surround->appendChild( $self->{session}->make_element( "a", name=>$field_id ) );
	}
	
	my $content = $self->{session}->make_element( "div", id => $component->{prefix}."_content", class=>"$content_class ep_sr_content" );
	my $content_inner = $self->{session}->make_element( "div", id => $component->{prefix}."_content_inner" );

	$content->appendChild( $content_inner );
	$content_inner->appendChild( $component->render_content( $self ) );
	
	
	$surround->appendChild( $content );

	return $surround;
}


1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

