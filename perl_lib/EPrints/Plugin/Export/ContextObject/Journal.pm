=head1 NAME

EPrints::Plugin::Export::ContextObject::Journal

=cut

package EPrints::Plugin::Export::ContextObject::Journal;

use EPrints::Plugin::Export::ContextObject;

@ISA = ( "EPrints::Plugin::Export::ContextObject" );

use strict;

# map eprint type to genre

our %MAPPING = qw(
	title	atitle
	volume	volume
	number	issue
	series	series
	publication	title
	pagerange	pages
	date	date
	issn	issn
	isbn	isbn
);
our %TYPE_MAPPING = qw(
	article	article
	conference_item	conference
	misc	unknown
);

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "OpenURL Journal";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "";

	return $self;
}

sub convert_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $data = $plugin->SUPER::convert_dataobj( $dataobj, %opts );

	my $dataset = $dataobj->get_dataset;

	if( $dataset->has_field( "type" ) and $dataobj->is_set( "type" ) )
	{
		my $genre = $TYPE_MAPPING{$dataobj->get_value( "type" )};

		if( defined $genre )
		{
			push @$data, [ genre => $genre ];
		}
	}

	return $data;
}

sub xml_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	return $plugin->xml_entity_dataobj( $dataobj, %opts,
		mapping => \%MAPPING,
		prefix => "jnl",
		namespace => "info:ofi/fmt:xml:xsd:journal",
		schemaLocation => "info:ofi/fmt:xml:xsd:journal http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:journal",
	);
}

sub kev_dataobj
{
	my( $plugin, $dataobj, $ctx ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj, mapping => \%MAPPING );

	# Can only include the first author in KEV
	my $first_author;
	for(my $i = 0; $i < @$data; ++$i)
	{
		if( $data->[$i]->[0] eq "author" )
		{
			my $e = splice @$data, $i, 1;
			--$i;
			$first_author ||= $e->[1];
		}
	}
	$first_author ||= {};
	# Sorry, this is a very compact way of expanding out the sub-arrays
	@$data = (%$first_author, map { @$_ } @$data);

	$ctx->journal( @$data );
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

