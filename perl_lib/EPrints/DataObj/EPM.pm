######################################################################
#
# EPrints::DataObj::EPM
#
######################################################################
#
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::DataObj::EPrint> - Class representing an actual EPrint

=head1 DESCRIPTION

This class represents a single eprint record and the metadata 
associated with it. This is associated with one of more 
EPrint::Document objects.

EPrints::DataObj::EPrint is a subclass of EPrints::DataObj with the following
metadata fields (plus those defined in ArchiveMetadataFieldsConfig):

=head1 SYSTEM METADATA

=over 4

=item eprintid (int)

The unique numerical ID of this eprint. 

=item rev_number (int)

The number of the current revision of this record.

=item userid (itemref)

The id of the user who deposited this eprint (if any). Scripted importing
could cause this not to be set.

=item dir (text)

The directory, relative to the documents directory for this repository, which
this eprints data is stored in. Eg. disk0/00/00/03/34 for record 334.

=item datestamp (time)

The date this record first appeared live in the repository.

=item lastmod (time)

The date this record was last modified.

=item status_changes (time)

The date/time this record was moved between inbox, buffer, archive, etc.

=item type (namedset)

The type of this record, one of the types of the "eprint" dataset.

=item succeeds (itemref)

The ID of the eprint (if any) which this succeeds.  This field should have
been an int and may be changed in a later upgrade.

=item commentary (itemref)

The ID of the eprint (if any) which this eprint is a commentary on.  This 
field should have been an int and may be changed in a later upgrade.

=item replacedby (itemref)

The ID of the eprint (if any) which has replaced this eprint. This is only set
on records in the "deletion" dataset.  This field should have
been an int and may be changed in a later upgrade.

=back

=head1 METHODS

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From EPrints::DataObj
#
######################################################################

package EPrints::DataObj::EPM;

@ISA = ( 'EPrints::DataObj' );

use strict;

######################################################################
=pod

=item $metadata = EPrints::DataObj::EPM->get_system_field_info

Return an array describing the system metadata of the EPrint dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return ( 
	
	{ name=>"eprintid", type=>"counter", required=>1, import=>0, can_clone=>0,
		sql_counter=>"eprintid" },

	{ name=>"documents", type=>"subobject", datasetid=>'document',
		multiple=>1 },

	{ name=>"files", type=>"subobject", datasetid=>"file",
		multiple=>1 },

	{ name=>"title", type=>"text" },
	{ name=>"link", type=>"text" },
	{ name=>"date", type=>"text" },
	{ name=>"package_name", type=>"text" },
	{ name=>"description", type=>"text" },
	{ name=>"version", type=>"text" },
	
	{ name=>"relation", type=>"compound", multiple=>1,
		fields => [
			{
				sub_name => "type",
				type => "text",
			},
			{
				sub_name => "uri",
				type => "text",
			},
		],
	},

	);
}

sub get_dataset_id
{
	return "epm";
}

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

