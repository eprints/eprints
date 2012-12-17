######################################################################
#
# EPrints::MetaField::File;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::File> - File in the file system.

=head1 DESCRIPTION

This is an abstract field which represents a directory in the 
filesystem. It is mostly used by the import and export systems.

For example: Documents have files.

=over 4

=cut

package EPrints::MetaField::File;

use base EPrints::MetaField::Subobject;

use strict;

sub get_sql_type
{
	my( $self, $session ) = @_;

	return undef;
}

# This type of field is virtual.
sub is_virtual
{
	my( $self ) = @_;

	return 1;
}

sub get_property_defaults
{
	my( $self ) = @_;

	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{show_in_fieldlist} = 0;
	$defaults{datasetid} = "file";

	return %defaults;
}

sub render_input_field 
{
	my( $self, $session, $value, $dataset, $staff, $hidden_fields, $obj, $prefix ) = @_;

	my $xml = $session->xml;
	my $xhtml = $xml->create_document_fragment();
	my $basename = $self->basename($prefix);

	my $div = $xml->create_element("div", class => "ep_block");
	$xhtml->appendChild($div);

	for($self->property( "multiple" ) ? @$value : $value)
	{
		next if !defined $_;
		my $inner_div = $xml->create_element( "div" );
		$div->appendChild($inner_div);
		$inner_div->appendChild($self->render_value( $session, $_ ));
		$inner_div->appendChild($session->xhtml->input_field("_internal_".$basename."_delete_".$_->id,
					$session->phrase("lib/submissionform:delete"),
					type=>"submit",
					class=>"ep_form_internal_button"));
	}

	$div->appendChild($session->xhtml->input_field($basename, undef, type => "file"));
	$div->appendChild($session->xhtml->input_field("_internal_".$basename."_upload",
				$session->phrase("lib/submissionform:action_upload"),
				type=>"submit",
				class=>"ep_form_internal_button"));

#	$xhtml->appendChild($self->render_value($session, $value));

	return $xhtml;
}

sub has_internal_action 
{
	my ($self, $basename) = @_;

	my $ibutton = $self->{repository}->get_internal_button;

	return $ibutton =~ /^${basename}_/;
}

sub form_value_actual 
{
	my ($self, $session, $object, $basename) = @_;

	my $filename = $session->param($basename);
	my $fh = $session->query->upload($basename);

	if( $session->get_internal_button =~ /^${basename}_delete_(.+)$/ )
	{
		my $fileobj = $session->dataset( "file" )->dataobj( $1 );
		if( $fileobj->value( "datasetid" ) eq $object->{dataset}->base_id && $fileobj->value( "objectid" ) eq $object->id )
		{
			$fileobj->delete;
		}
	}

	if(!defined $fh) 
	{
		return $self->property("multiple") ? [] : undef;
	}

	my $fileobj = $object->create_subdataobj( $self->name, {
		_content => $fh,
		filename => $filename,
		filesize => -s $fh,
	});

	return $self->property("multiple") ? [$fileobj] : $fileobj;
}

sub render_xml_schema
{
	my( $self, $session ) = @_;

	my $element = $session->make_element( "xs:element", name => $self->get_name );

	if( $self->get_property( "multiple" ) )
	{
		my $complexType = $session->make_element( "xs:complexType" );
		$element->appendChild( $complexType );
		my $sequence = $session->make_element( "xs:sequence" );
		$complexType->appendChild( $sequence );
		my $item = $session->make_element( "xs:element", name => "file", maxOccurs => "unbounded", type => $self->get_xml_schema_type() );
		$sequence->appendChild( $item );
	}
	else
	{
		$element->setAttribute( type => $self->get_xml_schema_type() );
	}

	return $element;
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	my $type = $session->make_element( "xs:complexType", name => $self->get_xml_schema_type );

	my $all = $session->make_element( "xs:all", minOccurs => "0" );
	$type->appendChild( $all );
	foreach my $part ( qw/ filename filesize url / )
	{
		my $element = $session->make_element( "xs:element", name => $part, type => "xs:string" );
		$all->appendChild( $element );
	}
	{
		my $element = $session->make_element( "xs:element", name => "data" );
		$all->appendChild( $element );
		my $complexType = $session->make_element( "xs:complexType" );
		$element->appendChild( $complexType );
		my $simpleContent = $session->make_element( "xs:simpleContent" );
		$complexType->appendChild( $simpleContent );
		my $extension = $session->make_element( "xs:extension", base => "xs:base64Binary" );
		$simpleContent->appendChild( $extension );
		my $attribute = $session->make_element( "xs:attribute", name => "href", type => "xs:anyURI" );
		$extension->appendChild( $attribute );
	}

	return $type;
}

######################################################################
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

