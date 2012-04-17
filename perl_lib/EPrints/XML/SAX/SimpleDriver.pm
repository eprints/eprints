=head1 NAME

EPrints::XML::SAX::SimpleDriver

=head1 SYNOPSIS

	my $driver = EPrints::XML::SAX::SimpleDriver->new(
			Handler => $handler,
		);
	
	$driver->start_element( "http://purl.org/dc/elements", "dc:identifier",
			"xml:lang" => "en"
		);
	$driver->characters( "http://www.eprints.org/" );
	$driver->end_element( "http://purl.org/dc/elements", "dc:identifier" );

=cut

package EPrints::XML::SAX::SimpleDriver;

use base XML::SAX::Base;

use strict;

sub start_document
{
	my( $self, $data ) = @_;

	$self->{NSHelper} = XML::NamespaceSupport->new({ xmlns => 1, fatal_errors => 0 });
	$self->{NSHelper}->push_context;

	$self->SUPER::start_document( $data );
}

sub xml_decl
{
	my( $self, $version, $encoding, $standalone ) = @_;

	$self->SUPER::xml_decl( {
			Version => $version,
			Encoding => $encoding,
			Standalone => $standalone,
		} );
}

sub start_prefix_mapping
{
    my( $self, $ns, $prefix ) = @_;

    $self->{NSHelper}->declare_prefix($prefix, $ns);

	$self->SUPER::start_prefix_mapping( {
			Prefix => $prefix,
			NamespaceURI => $ns,
		} );
}

sub data_element
{
	my( $self, $ns, $qname, $children, @attr ) = @_;

	$self->start_element( $ns, $qname, @attr );

	if( ref($children) eq "ARRAY" )
	{
		$self->data_element( @$_ ) for @$children;
	}
	elsif( defined $children )
	{
		$self->characters( $children );
	}

	$self->end_element( $ns, $qname );
}

sub start_element
{
	my( $self, $ns, $qname, @attr ) = @_;

	no warnings;

	$self->{NSHelper}->push_context;

	my( $localName, $prefix ) = reverse split ':', $qname, 2;
	$prefix = '' if !defined $prefix;

	if( !defined $self->{NSHelper}->getURI( $prefix ) )
	{
		$self->start_prefix_mapping( $ns, $prefix );
	}

	my %attr;
	while(my( $name, $value ) = splice(@attr,0,2))
	{
		my( $_localName, $_prefix ) = reverse split ':', $name, 2;
		my $_ns;
		if( $_prefix )
		{
			if( $_prefix eq "xmlns" && $_localName ne $prefix )
			{
				$self->start_prefix_mapping( $value, $_localName );
			}
			$_ns = $self->{NSHelper}->getURI( $_prefix );
		}
		else
		{
			$_prefix = $prefix;
			$_ns = $ns;
		}
		$attr{"{$_ns}$_localName"} = {
				NamespaceURI => $_ns,
				Prefix => $_prefix,
				LocalName => $_localName,
				Name => $_prefix ? "$_prefix:$_localName" : $_localName,
				Value => $value,
			};
	}

	$self->SUPER::start_element( {
			NamespaceURI => $ns,
			Prefix => $prefix,
			LocalName => $localName,
			Name => $qname,
			Attributes => \%attr,
		});
}

sub characters { $_[0]->SUPER::characters( { Data => $_[1] } ) }
sub comment { $_[0]->SUPER::comment( { Data => $_[1] } ) }

sub end_element
{
	my( $self, $ns, $qname ) = @_;

	$self->{NSHelper}->pop_context;

	my( $localName, $prefix ) = reverse split ':', $qname, 2;
	$prefix = '' if !defined $prefix;

	$self->SUPER::end_element( {
			NamespaceURI => $ns,
			Prefix => $prefix,
			LocalName => $localName,
			Name => $prefix ? "$prefix:$localName" : $localName,
		});
}

sub end_document { shift->SUPER::end_document( {} ) }

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

