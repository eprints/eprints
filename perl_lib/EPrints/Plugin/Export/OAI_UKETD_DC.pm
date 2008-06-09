package EPrints::Plugin::Export::OAI_UKETD_DC;

######################################################################
# Copyright (C) British Library Board, St. Pancras, UK
#
# Author: Steve Carr, British Library
# Email: stephen.carr@bl.uk
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
######################################################################

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "UK ETD DC OAI Schema";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";
	
	$self->{xmlns} = "http://naca.central.cranfield.ac.uk/ethos-oai/2.0/";
	$self->{schemaLocation} = "http://naca.central.cranfield.ac.uk/ethos-oai/2.0/uketd_dc.xsd";

	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $xml = $plugin->xml_dataobj( $dataobj );

	return EPrints::XML::to_string( $xml );
}




#######################################################################
#
# Steve Carr - eprints revision (standard revision in order to offer
# something other than basic dublin core - which isn't going to be enough
# to encode the complex data that we are dealing with for e-theses)
# This subroutine takes an eprint object and renders the XML DOM
# to export as the uketd_dc default format in OAI.
#
######################################################################

sub xml_dataobj
{
	my( $plugin, $eprint ) = @_;

	# we have a variety of namespaces since we're doing qualified dublin core, so we need an
	# array of references to three element arrays in our data structure
	my @etdData = &eprint_to_uketd_dc( $eprint, $plugin->{session} );
	
	my $namespace = $plugin->{xmlns};
	my $schema = $plugin->{schemaLocation};

        # the eprint may well be null since it may not be a thesis but an article
        my $uketd_dc = $plugin->{session}->make_element(
		"uketd_dc:uketddc",
		"xmlns:dc" => "http://purl.org/dc/elements/1.1/",
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		# TO DO check out that these are properly acceptable when validated
		# TO DO put in final location for our xsd and namespace - it'll probably be somewhere on ethos.ac.uk or bl.uk
		"xsi:schemaLocation" => $namespace." ".$schema,
		"xmlns:uketd_dc" => $namespace,
		"xmlns:dcterms" => "http://purl.org/dc/terms/",
		"xmlns:uketdterms" => "http://naca.central.cranfield.ac.uk/ethos-oai/terms/");
	# turn the list of pairs into XML blocks (indented by 8) and add them
	# them to the ETD element.
	foreach( @etdData )
	{
		if(scalar $_ < 4){
			$uketd_dc->appendChild( $plugin->{session}->render_data_element( 8, $_->[2].":".$_->[0], $_->[1] ) );
		}else{
		# there's an attribute to add
			$uketd_dc->appendChild( $plugin->{session}->render_data_element( 8, $_->[2].":".$_->[0], $_->[1], "xsi:type"=> $_->[3]  ) );
			
		}
	}
	return $uketd_dc;
	
}

##############################################################################
#
# Steve Carr
# subroutine to create a suitable array of array refs to the two item arrays
# as per routine directly above for dublin core (dc). The only difference is that
# qualified dublin core will have additional namespaces and more elements from
# the eprint can be utilised. So we return a longer, three element array per
# array ref. This may need rethinking when we get to attributes (e.g. xsi:type="URI")
#
#
##############################################################################

sub eprint_to_uketd_dc
{
	my( $eprint, $session ) = @_;

	my @etddata = ();
	# we still want much the same dc data so include under the dc namespace
	# by putting the namespace last this won't break the simple dc rendering routine
	# above. Skip all records that aren't theses because uketd_dc is nonsensical for
	# non-thesis items.
	
	if($eprint->get_value( "type") eq "thesis" || $eprint->get_value( "type" ) eq "Thesis"){
		
		push @etddata, [ "title", $eprint->get_value( "title" ), "dc" ]; 
		
		# grab the creators without the ID parts so if the site admin
		# sets or unsets creators to having and ID part it will make
		# no difference to this bit.
	
		my $creators = $eprint->get_value( "creators_name" );
		if( defined $creators )
		{
			foreach my $creator ( @{$creators} )
			{
				push @etddata, [ "creator", EPrints::Utils::make_name_string( $creator ), "dc" ];
			}
		}
	
		my $subjectid;
		foreach $subjectid ( @{$eprint->get_value( "subjects" )} )
		{
			my $subject = EPrints::DataObj::Subject->new( $session, $subjectid );
			# avoid problems with bad subjects
			next unless( defined $subject ); 
			push @etddata, [ "subject", EPrints::Utils::tree_to_utf8( $subject->render_description() ), "dc" ];
		}
	
		# Steve Carr : we're using qdc, namespace dcterms, version of description - 'abstract'
		push @etddata, [ "abstract", $eprint->get_value( "abstract" ), "dcterms" ]; 
		
		# Steve Carr : theses aren't technically 'published' so we can't assume a publisher here as in original code
		if(defined $eprint->get_value( "publisher" )){
			push @etddata, [ "commercial", $eprint->get_value( "publisher" ), "uketdterms" ]; 
		}
	
		my $editors = $eprint->get_value( "editors_name" );
		if( defined $editors )
		{
			foreach my $editor ( @{$editors} )
			{
				push @etddata, [ "contributor", EPrints::Utils::make_name_string( $editor ), "dc" ];
			}
		}
#	 cjg commented out. need to make work for new date layout
##		## Date for discovery. For a month/day we don't have, assume 01.
##		my $date = $eprint->get_value( "date_issue" );
#		if( defined $date )
#		{
#	        	$date =~ s/(-0+)+$//;
#			push @etddata, [ "issued", $date, "dcterms" ];
#		}
	
	
		my $ds = $eprint->get_dataset();
		push @etddata, [ "type", $session->get_type_name( "eprint", $eprint->get_value( "type" ) ), "dc" ];
		
		# The URL of the abstract page is the dcterms isreferencedby
		push @etddata, [ "isReferencedBy", $eprint->get_url(), "dcterms" ];
	
	
		my @documents = $eprint->get_all_documents();
		my $mimetypes = $session->get_repository->get_conf( "oai", "mime_types" );
		foreach( @documents )
		{
			my $format = $mimetypes->{$_->get_value("format")};
			$format = $_->get_value("format") unless defined $format;
			#$format = "application/octet-stream" unless defined $format;
			
			push @etddata, [ "identifier", $_->get_url(), "dc", "dcterms:URI" ];
			push @etddata, [ "format", $format, "dc", "dcterms" ];
			# information about extent and checksums could be added here, if they are available
			# the default eprint doesn't have a place for this but both could be generated dynamically
		}
	
		# Steve Carr : we're using isreferencedby for the official url splash page
		if( $eprint->exists_and_set( "official_url" ) )
		{
			push @etddata, [ "isReferencedBy", $eprint->get_value( "official_url" ), "dcterms", "dcterms:URI"];
		}
			
		if( $eprint->exists_and_set( "thesis_name" )){
			push @etddata, [ "qualificationname", $eprint->get_value( "thesis_name" ), "uketdterms"];
		}
		if( $eprint->exists_and_set( "thesis_type")){
			push @etddata, [ "qualificationlevel", $eprint->get_value( "thesis_type" ), "uketdterms"];
		}
		if( $eprint->exists_and_set( "institution" )){
			push @etddata, [ "institution", $eprint->get_value( "institution" ), "uketdterms"];
		}
		if( $eprint->exists_and_set( "department" )){
			push @etddata, [ "department", $eprint->get_value( "department" ), "uketdterms"];
		}
		if( $eprint->exists_and_set( "advisor" )){
			push @etddata, [ "advisor", $eprint->get_value( "advisor" ), "uketdterms"];
		}
		if( $eprint->exists_and_set( "language" )){
			push @etddata, [ "language", $eprint->get_value( "language" ), "dc"];
		}
		if( $eprint->exists_and_set( "sponsors" )){
			push @etddata, [ "sponsor", $eprint->get_value( "sponsors" ), "uketdterms"];
		}
		if( $eprint->exists_and_set( "alt_title" )){
			push @etddata, [ "alternative", $eprint->get_value("alt_title" ), "dcterms"];
		}
		if( $eprint->exists_and_set( "checksum" )){
			push @etddata, [ "checksum", $eprint->get_value("checksum"), "uketdterms" ];
		}
		if( $eprint->exists_and_set( "date_embargo" )){
			push @etddata, ["date_embargo", $eprint->get_value("date_embargo"), "uketdterms"];
		}
		if( $eprint->exists_and_set( "embargo_reason" )){
			push @etddata, ["embargo_reason", $eprint->get_value("embargo_reason"), "uketdterms"];
		}
		if( $eprint->exists_and_set( "rights" )){
			push @etddata, ["rights", $eprint->get_value("rights"), "dc"];
		}
		if( $eprint->exists_and_set( "citations" )){
			push @etddata, ["hasVersion", $eprint->get_value("citations"), "dcterms"];
		}
		if( $eprint->exists_and_set( "referencetext" )){
			push @etddata, ["references", $eprint->get_value("referencetext"), "dcterms"];
		}
		
		
	
		# dc.source TO DO
		# dc.coverage TO DO
		
	}
	
	return @etddata;
}
	
1;

