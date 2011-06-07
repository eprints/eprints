######################################################################
#
# EPrints::Citation::XSL
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::Citation::XSL> - loading and rendering of citation styles

=cut

package EPrints::Citation::XSL;

use EPrints::Citation;
@ISA = qw( EPrints::Citation );

eval "use XML::LibXSLT 1.70";
use strict;

sub load_source
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $file = $self->{filename};

	my $doc = $repo->parse_xml( $file, 1 );
	return if !$doc;

	my $type = $doc->getDocumentElement->getAttribute( "ept:type" );
	$type = "default" unless EPrints::Utils::is_set( $type );

	my $stylesheet = XML::LibXSLT->new->parse_stylesheet( $doc );

	$self->{type} = $type;
	$self->{stylesheet} = $stylesheet;
	$self->{mtime} = EPrints::Utils::mtime( $file );

	$repo->xml->dispose( $doc );

	return 1;
}

=item $frag = $citation->render( $dataobj, %opts )

Renders a L<EPrints::DataObj> using this citation style.

=cut

sub render
{
	my( $self, $dataobj, %opts ) = @_;

	EPrints->abort( "Requires dataobj" )
		if !defined $dataobj;

	$self->freshen;

#	my $xml = $dataobj->to_xml;
#	my $doc = $xml->ownerDocument;
#	$doc->setDocumentElement( $xml );

	my $doc = XML::LibXML::Document->new( '1.0', 'utf-8' );
	$doc->setDocumentElement( $doc->createElement( 'root' ) );

	local $self->{messages} = [];

	my $xslt = EPrints::XSLT->new(
		repository => $self->{repository},
		stylesheet => $self->{stylesheet},
		dataobj => $dataobj,
		dataobjs => {},
		opts => \%opts,
		error_cb => sub { $self->error( @_ ) },
	);

	my $r = $xslt->transform( $doc );

	for( @{$self->{messages}} )
	{
		return $self->{repository}->xml->create_text_node( "$self->{filename}: $_->{type} - $_->{message}" );
	}

	return $self->{repository}->xml->contents_of( $r );
}

sub error
{
	my( $self, $type, $message ) = @_;

	push @{$self->{messages}}, {
		type => $type,
		message => $message,
	};
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

