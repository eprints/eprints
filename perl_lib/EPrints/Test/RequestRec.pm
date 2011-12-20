=head1 NAME

EPrints::Test::RequestRec

=cut

package EPrints::Test::RequestRec;

# fake mod_perl query package

sub new
{
	my( $class, %opts ) = @_;

	return bless \%opts, $class;
}

sub is_initial_req { 1 }

sub uri
{
	my( $self ) = @_;

	return $self->{uri};
}

sub args
{
	my( $self ) = @_;

	return $self->{args};
}

sub pool
{
	my( $self ) = @_;

	return $self->{pool} ||= EPrints::Test::Pool->new();
}

sub filename
{
	my( $self ) = @_;

	$self->{filename} = $_[1] if @_ == 2;

	return $self->{filename};
}

sub dir_config
{
	my( $self, $key ) = @_;

	return $self->{dir_config}->{$key};
}

sub headers_in
{
	my( $self ) = @_;

	return $self->{headers_in} ||= {};
}

sub headers_out
{
	my( $self ) = @_;

	return $self->{headers_out} ||= {};
}

sub custom_response
{
	my( $self, $code, $url ) = @_;
}

sub handler
{
	my( $self, $handler ) = @_;
}

sub set_handlers
{
	my( $self, $handlers ) = @_;
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

