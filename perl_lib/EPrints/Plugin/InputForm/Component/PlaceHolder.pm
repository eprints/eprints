=head1 NAME

EPrints::Plugin::InputForm::Component::PlaceHolder

=cut

package EPrints::Plugin::InputForm::Component::PlaceHolder;

use EPrints::Plugin::InputForm::Component;

@ISA = ( "EPrints::Plugin::InputForm::Component" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "PlaceHolder";
	$self->{visible} = "all";

	return $self;
}

sub render_content
{
	my( $self ) = @_;

	return $self->html_phrase( "content", placeholding => $self->{session}->make_text( $self->{placeholding} ) );
}

sub render_help
{
	my( $self, $surround ) = @_;
	
	return $self->html_phrase( "help", placeholding => $self->{session}->make_text( $self->{placeholding} ) );
}

sub render_title
{
	my( $self, $surround ) = @_;

	return $self->html_phrase( "title", placeholding => $self->{session}->make_text( $self->{placeholding} ) );
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

