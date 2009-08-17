######################################################################
#
# EPrints::OpenArchives
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::OpenArchives> - Methods for open archives support in EPrints.

=head1 DESCRIPTION

This module contains methods used by the EPrints OAI interface. 
See http://www.openarchives.org/ for more information.

=head1 METHODS 

=over 4

=cut

package EPrints::OpenArchives;

use EPrints;

use strict;



######################################################################
=pod

=item $xml = EPrints::OpenArchives::make_header( $handle, $eprint, $oai2 )

Return a DOM tree containing the generic <header> part of a OAI response
describing an EPrint. 

Return the OAI2 version if $oai2 is true.

=cut
######################################################################

sub make_header
{
	my ( $handle, $eprint, $oai2 ) = @_;

	my $header = $handle->make_element( "header" );
	my $oai_id;
	if( $oai2 )
	{
		$oai_id = $handle->get_repository->get_conf( 
			"oai", 
			"v2", 
			"archive_id" );
	}
	else
	{
		$oai_id = $handle->get_repository->get_conf( 
			"oai", 
			"archive_id" );
	}
	
	$header->appendChild( $handle->render_data_element(
		6,
		"identifier",
		EPrints::OpenArchives::to_oai_identifier(
			$oai_id,
			$eprint->get_id ) ) );

	my $datestamp = $eprint->get_value( "lastmod" );
	unless( EPrints::Utils::is_set( $datestamp ) )
	{
		# is this a good default?
		$datestamp = '0001-01-01T00:00:00Z';
	}
	else
	{
		my( $date, $time ) = split( " ", $datestamp );
		$time = "00:00:00" unless defined $time; # Work-around for bad imports
		$datestamp = $date."T".$time."Z";
	}
	$header->appendChild( $handle->render_data_element(
		6,
		"datestamp",
		$datestamp ) );

	if( EPrints::Utils::is_set( $oai2 ) )
	{
		if( $eprint->get_dataset()->id() eq "deletion" )
		{
			$header->setAttribute( "status" , "deleted" );
			return $header;
		}

		my $viewconf = $handle->get_repository->get_conf( "oai","sets" );
        	foreach my $info ( @{$viewconf} )
        	{
			my @values = $eprint->get_values( $info->{fields} );
			my $afield = EPrints::Utils::field_from_config_string( 
					$eprint->get_dataset(), 
					( split( "/" , $info->{fields} ) )[0] );

			foreach my $v ( @values )
			{
				if( $v eq "" && !$info->{allow_null} ) { next;  }

				my @l;
				if( $afield->is_type( "subject" ) )
				{
					my $subj = new EPrints::DataObj::Subject( $handle, $v );
					next unless( defined $subj );
	
					my @paths = $subj->get_paths( 
						$handle, 
						$afield->get_property( "top" ) );

					foreach my $path ( @paths )
					{
						my @ids;
						foreach( @{$path} ) 
						{
							push @ids, $_->get_id();
						}
						push @l, encode_setspec( @ids );
					}
				}
				else
				{
					@l = ( encode_setspec( $v ) );
				}

				foreach( @l )
				{
					$header->appendChild( $handle->render_data_element(
						6,
						"setSpec",
						encode_setspec( $info->{id}.'=' ).$_ ) );
				}
			}
		}
	}

	return $header;
}


######################################################################
=pod

=item $xml = EPrints::OpenArchives::make_record( $handle, $eprint, $fn, $oai2 )

Return XML DOM describing the entire OAI <record> for a single eprint.

If $oai2 is true return the XML suitable for OAI v2.0

$fn is a pointer to a function which takes ( $eprint, $handle ) and
returns an XML DOM tree describing the metadata in the desired format.

=cut
######################################################################

sub make_record
{
	my( $handle, $eprint, $plugin, $oai2 ) = @_;

	my $record = $handle->make_element( "record" );

	my $header = make_header( $handle, $eprint, $oai2 );
	$record->appendChild( $handle->make_indent( 4 ) );
	$record->appendChild( $header );

	if( $eprint->get_dataset()->id() eq "deletion" )
	{
		unless( EPrints::Utils::is_set( $oai2 ) )
		{
			$record->setAttribute( "status" , "deleted" );
		}
		return $record;
	}

	my $md = $plugin->xml_dataobj( $eprint );
	if( defined $md )
	{
		my $metadata = $handle->make_element( "metadata" );
		$metadata->appendChild( $handle->make_indent( 6 ) );
		$metadata->appendChild( $md );
		$record->appendChild( $handle->make_indent( 4 ) );
		$record->appendChild( $metadata );
	}

	return $record;
}


######################################################################
=pod

=item $oai_id EPrints::OpenArchives::to_oai_identifier( $archive_id, $eprintid )

Give the full OAI identifier of an eprint, given the local eprint id.

$archive_id is the ID used for OAI, which may be different from that
used by EPrints.

=cut
######################################################################

sub to_oai_identifier
{
	my( $archive_id , $eprintid ) = @_;
	
	return( "oai:$archive_id:$eprintid" );
}


######################################################################
=pod

=item $eprintid = EPrints::OpenArchives::from_oai_identifier( $handle, $oai_identifier )

Return the local eprint id of an oai eprint identifier.

Return undef if this does not match a possible eprint.

This does not check the eprint actually exists, just that the OAI
identifier is suitable.

=cut
######################################################################

sub from_oai_identifier
{
        my( $handle , $oai_identifier ) = @_;
        my $arcid = $handle->get_repository->get_conf( "oai", "archive_id" );
        my $arcid2 = $handle->get_repository->get_conf( "oai", "v2", "archive_id" );
        if( $oai_identifier =~ /^oai:($arcid|$arcid2):(\d+)$/ )
        {
                return( $2 );
        }
        else
        {
                return( undef );
        }
}



######################################################################
=pod

=item $encoded = EPrints::OpenArchives::encode_setspec( @bits )

This encodes a list of values in such a way that it is a legal 
OAI setspec, even if it contains non-ascii characters etc.

=cut
######################################################################

sub encode_setspec
{
	my( @bits ) = @_;
	foreach( @bits ) { $_ = text2bytestring( $_ ); }
	return join(":",@bits);
}


######################################################################
=pod

=item @decoded = EPrints::OpenArchives::decode_setspec( $encoded )

This decodes a list of parameters encoded by encode_setspec

=cut
######################################################################

sub decode_setspec
{
	my( $encoded ) = @_;
	my @bits = split( ":", $encoded );
	foreach( @bits ) { $_ = bytestring2text( $_ ); }
	return @bits;
}


######################################################################
=pod

=item $encoded = EPrints::OpenArchives::text2bytestring( $string )

Converts a string into hex. eg. "A" becomes "41".

=cut
######################################################################

sub text2bytestring
{
	my( $string ) = @_;
	my $encstring = "";
	for(my $i=0; $i<length($string); $i++)
	{
		$encstring.=sprintf("%02X", ord(substr($string, $i, 1)));
	}
	return $encstring;
}


######################################################################
=pod

=item $decoded = EPrints::OpenArchives::bytestring2text( $encstring )

Does the reverse of text2bytestring.

=cut
######################################################################

sub bytestring2text
{
	my( $encstring ) = @_;

	my $string = "";
	for(my $i=0; $i<length($encstring); $i+=2)
	{
		$string.=pack("H*",substr($encstring,$i,2));
	}
	return $string;
}


1;


######################################################################
=pod

=back

=cut

