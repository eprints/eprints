######################################################################
#
# EPrints::Sword::ServiceDocument
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

######################################################################
#
# PURPOSE:
#
#	This is an handler called by Apache/mod_perl to provide the 
#	Service Document for SWORD.
#
# METHODS:
#
# handler( $request )
# 	Parameters: 	$request -> the RequestRec object sent by mod_perl.
#
# 	Returns:	Apache2::Const::DONE
# 			
#
#####################################################################

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

	# $response->{status_code} defined means there was an authentication error
        if( defined $response->{status_code} )	
        {       
                if( defined $response->{x_error_code} )
                {
			$request->headers_out->{'X-Error-Code'} = $response->{x_error_code};
                }

		if( $response->{status_code} == 401 )
		{
			$request->headers_out->{'WWW-Authenticate'} = 'Basic realm="SWORD"';
		}

		$request->status( $response->{status_code} );

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
	my $service = $session->make_element( "service", "xmlns" => "http://purl.org/atom/app#", "xmlns:atom" => "http://www.w3.org/2005/Atom", "xmlns:sword" => "http://purl.org/net/sword/", "xmlns:dcterms" => "http://purl.org/dc/terms/" );

	my $workspace = $session->make_element( "workspace" );

	my $atom_title = $session->make_element( "atom:title" );

	$atom_title->appendChild( $session->make_text( $service_conf->{title} ) );

	$workspace->appendChild( $atom_title );


	# COLLECTION DEFINITION
	my $collections = EPrints::Sword::Utils::get_collections( $session );

	# Note: if no collection is defined, we send an empty ServiceDocument

	my $deposit_url = EPrints::Sword::Utils::get_deposit_url( $session );

	foreach my $collec (keys %$collections)
	{
		my %conf = %{$$collections{$collec}};

		my $href = defined $conf{href} ? $conf{href} : $deposit_url.$collec;

		my $collection = $session->make_element( "collection" , "href" => $href );

		my $atom_title2 = $session->make_element( "atom:title" );
		$atom_title2->appendChild( $session->make_text( $conf{title} ) );
		$collection->appendChild( $atom_title2 );

		# ACCEPT
		foreach(@{$conf{accept_mime}})
		{
			my $accept = $session->make_element( "accept" );
			$accept->appendChild( $session->make_text( $_ ) );
			$collection->appendChild( $accept );
		}

		# COLLECTION POLICY
		my $coll_policy = $session->make_element( "sword:collectionPolicy" );
		$coll_policy->appendChild($session->make_text( $conf{sword_policy}  ) );
		$collection->appendChild( $coll_policy );

		# COLLECTION TREATMENT
		my $treatment = $conf{treatment};
		if( defined $depositor )
		{
			$treatment.= $session->phrase( "Sword/ServiceDocument:note_behalf", username=>$depositor->get_value( "username" ));
		}

		my $coll_treat = $session->make_element( "sword:treatment" );
		$coll_treat->appendChild($session->make_text( $treatment ) );
		$collection->appendChild( $coll_treat );

		# COLLECTION MEDIATED
		my $coll_mediated = $session->make_element( "sword:mediation" );
		$coll_mediated->appendChild( $session->make_text($conf{mediation} ));
		$collection->appendChild( $coll_mediated );


		# COLLECTION SUPPORTED NAMESPACE
		foreach(@{$conf{format_ns}})
		{
			my $coll_ns = $session->make_element( "sword:formatNamespace" );
			$coll_ns->appendChild( $session->make_text( $_ ) );
			$collection->appendChild( $coll_ns );
		}


		# DCTERMS ABSTRACT
		my $coll_abstract = $session->make_element( "dcterms:abstract" );
		$coll_abstract->appendChild( $session->make_text( $conf{dcterms_abstract} ) );
		$collection->appendChild( $coll_abstract  );

		$workspace->appendChild( $collection );

	}

	
	$service->appendChild( $workspace );


	# SWORD LEVEL
	my $sword_level = $session->make_element( "sword:level" );
	$sword_level->appendChild( $session->make_text( "1" ) );
	$service->appendChild( $sword_level );

	# SWORD VERBOSE	(Unsupported)
	my $sword_verbose = $session->make_element( "sword:verbose" );
	$sword_verbose->appendChild( $session->make_text( "false" ) );
	$service->appendChild( $sword_verbose );

	# SWORD NOOP (Unsupported)
	my $sword_noop = $session->make_element( "sword:noOp" );
	$sword_noop->appendChild( $session->make_text( "false" ) );
	$service->appendChild( $sword_noop );

	my $content = '<?xml version="1.0" encoding=\'utf-8\'?>'.$service->toString;

	my $xmlsize = length $content;
	$request->content_type('application/atomsvc+xml');
	$request->headers_out->{'Content-Length'} = $xmlsize;

	# sending data...
	print $content;

	$session->terminate;
	return Apache2::Const::DONE;
}

1;


