######################################################################
#
# EPrints::Citation
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::Citation> - loading and rendering of citation styles

=head1 DESCRIPTION

=head1 SYNOPSIS

	my $citation = $repo->dataset( "eprint" )->citation( "default" );

	$ok = $citation->freshen();

	$citation->render( $eprint, %opts );

=head1 METHODS

=item $citation = EPrints::Citation->new( $filename, %opts )

Returns a new EPrints::Citation object read from $filename.

Options:
	dataset - dataset this citation belongs to

=cut

package EPrints::Citation;

use strict;

sub new
{
	my( $class, $filename, %self ) = @_;

	$self{filename} = $filename;
	$self{repository} ||= $self{dataset}->repository;

	my $self = bless \%self, $class;

	Scalar::Util::weaken($self{repository})
		if defined &Scalar::Util::weaken;

	return undef if !$self->freshen();

	return $self;
}

=item $ok = $citation->freshen()

Attempts to reload the citation source file.

Returns undef if the file could not be loaded.

=cut

sub freshen
{
	my( $self ) = @_;

	my $file = $self->{filename};
	my $mtime = EPrints::Utils::mtime( $file );
	my $old_mtime = $self->{mtime};

	if( defined $old_mtime && $old_mtime == $mtime )
	{
		return;
	}

	return $self->load_source();
}

=item $ok = $citation->load_source()

Reads the source file.

=cut

sub load_source
{
	return undef;
}

=item $frag = $citation->render( $dataobj, %opts )

Renders a L<EPrints::DataObj> using this citation style.

=cut

sub render
{
	my( $self, $dataobj, %opts ) = @_;
}

=item $type = $citation->type()

Returns the type of this citation. Only supported value is "table_row".

=cut

sub type
{
	shift->{type};
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

