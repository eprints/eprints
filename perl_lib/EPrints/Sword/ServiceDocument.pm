######################################################################
#
# EPrints::Sword::ServiceDocument
#
######################################################################
#
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  This file is part of GNU EPrints 3.
#  
#  Copyright (c) 2000-2008 University of Southampton, UK. SO17 1BJ.
#  
#  EPrints 3 is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  EPrints 3 is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with EPrints 3; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
######################################################################

package EPrints::Sword::ServiceDocument;

use EPrints;
use EPrints::Sword::Utils;

use strict;

sub handler
{
        my $request = shift;

        my $session = new EPrints::Session;
        if(! defined $session )
        {
                print STDERR "\n[SWORD-SERVDOC] [INTERNAL-ERROR] Could not create session object.";
                $request->status( 500 );
                return Apache2::Const::DONE;
        }

	# Authenticating user and behalf user
	my $response = EPrints::Sword::Utils::authenticate( $session, $request );
	my $error = $response->{error};

	if( defined $error )
        {       
                if( defined $error->{x_error_code} )
                {
			$request->headers_out->{'X-Error-Code'} = $error->{x_error_code};
                }

		if( $error->{no_auth} )
		{
			$request->headers_out->{'WWW-Authenticate'} = 'Basic realm="SWORD"';
		}

		$request->status( $error->{status_code} );
		$session->terminate;
		return Apache2::Const::DONE;
        }

	my $owner = $response->{owner};
	my $depositor = $response->{depositor};		# can be undef if no X-On-Behalf-Of in the request

	my $service_conf = $session->get_repository->get_conf( "sword","service_conf" );

	# Load some default values if those were not set in the sword.pl configuration file
	if(!defined $service_conf || !defined $service_conf->{title})
	{
		$service_conf = {};
		$service_conf->{title} = $session->phrase( "archive_name" );
	}

	# SERVICE and WORKSPACE DEFINITION

	my $service = $session->make_element( "service", 
			xmlns => "http://www.w3.org/2007/app",
			"xmlns:atom" => "http://www.w3.org/2005/Atom",
			"xmlns:sword" => "http://purl.org/net/sword/",
			"xmlns:dcterms" => "http://purl.org/dc/terms/" );


	my $workspace = $session->make_element( "workspace" );

	my $atom_title = $session->make_element( "atom:title" );

	$atom_title->appendChild( $session->make_text( $service_conf->{title} ) );

	$workspace->appendChild( $atom_title );


	# COLLECTION DEFINITION
	my $collections = EPrints::Sword::Utils::get_collections( $session );

	# Note: if no collections are defined, we send an empty ServiceDocument

	my $deposit_url = EPrints::Sword::Utils::get_deposit_url( $session );

	foreach my $collec (keys %$collections)
	{
		my $conf = $collections->{$collec};

		my $href = defined $conf->{href} ? $conf->{href} : $deposit_url.$collec;

		my $collection = $session->make_element( "collection" , "href" => $href );

		my $ctitle = $session->make_element( "atom:title" );
		$ctitle->appendChild( $session->make_text( $conf->{title} ) );
		$collection->appendChild( $ctitle );

		foreach(@{$conf->{mime_types}})
		{
			my $accept = $session->make_element( "accept" );
			$accept->appendChild( $session->make_text( "$_" ) );
			$collection->appendChild( $accept );
		}

		my $supported_packages = $conf->{packages};
		foreach( keys %$supported_packages )
		{
			my $package = $session->make_element( "sword:acceptPackaging" );
			my $qvalue = $supported_packages->{$_}->{qvalue};
			if(defined $qvalue)
			{
				$package->setAttribute( "q", $qvalue );
			}
			$package->appendChild( $session->make_text( "$_" ) );
			$collection->appendChild( $package );
		}

		# COLLECTION POLICY
		my $cpolicy = $session->make_element( "sword:collectionPolicy" );
		$cpolicy->appendChild($session->make_text( $conf->{sword_policy}  ) );
		$collection->appendChild( $cpolicy );

		# COLLECTION TREATMENT
		my $treatment = $conf->{treatment};
		if( defined $depositor )
		{
			$treatment.= $session->phrase( "Sword/ServiceDocument:note_behalf", username=>$depositor->get_value( "username" ));
		}

		my $coll_treat = $session->make_element( "sword:treatment" );
		$coll_treat->appendChild($session->make_text( $treatment ) );
		$collection->appendChild( $coll_treat );

		# COLLECTION MEDIATED
		my $coll_mediated = $session->make_element( "sword:mediation" );
		$coll_mediated->appendChild( $session->make_text($conf->{mediation} ));
		$collection->appendChild( $coll_mediated );

		# DCTERMS ABSTRACT
		my $coll_abstract = $session->make_element( "dcterms:abstract" );
		$coll_abstract->appendChild( $session->make_text( $conf->{dcterms_abstract} ) );
		$collection->appendChild( $coll_abstract  );
		
		$workspace->appendChild( $collection );
	}

	$service->appendChild( $workspace );

	# SWORD LEVEL
	my $sword_level = $session->make_element( "sword:version" );
	$sword_level->appendChild( $session->make_text( "1.3" ) );
	$service->appendChild( $sword_level );

	# SWORD VERBOSE	(Unsupported)
	my $sword_verbose = $session->make_element( "sword:verbose" );
	$sword_verbose->appendChild( $session->make_text( "true" ) );
	$service->appendChild( $sword_verbose );

	# SWORD NOOP (Unsupported)
	my $sword_noop = $session->make_element( "sword:noOp" );
	$sword_noop->appendChild( $session->make_text( "true" ) );
	$service->appendChild( $sword_noop );

	my $content = '<?xml version="1.0" encoding="UTF-8"?>'.$service->toString;

	my $xmlsize = length $content;
	$request->content_type('application/atomsvc+xml');

	$request->headers_out->{'Content-Length'} = $xmlsize;

	print $content;

	$session->terminate;
	return Apache2::Const::DONE;
}

1;


