=head1 NAME

EPrints::Sword::AtomHandler

=cut

package EPrints::Sword::AtomHandler;

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

	# then what?
	#
	# get the eprint ID from the URI
	# can the user view that eprint?
	# if so, send the xml, probably using Utils:create_xml

	my $uri = $request->uri();

	my $epid;
	if( $uri =~ /\/atom\/(\d+)\.atom$/ )
	{
		$epid = $1;
	}
	
	unless( defined $epid )
	{
		$request->status( 400 );
		return Apache2::Const::OK;
	}

	my $eprint = EPrints::DataObj::EPrint->new( $session, $epid );

	unless( defined $eprint )
	{
		$request->status( 400 );
		return Apache2::Const::OK;
	}

	# now should check the current user has auth to view this eprint
	my $user_to_test = defined $depositor ? $depositor : $owner;

	unless( $eprint->has_owner( $user_to_test ) )
	{
		$request->status( 401 );
		return Apache2::Const::OK;
	}

	my $real_owner = EPrints::DataObj::User->new( $session, $eprint->get_value( "userid" ) );
	my $real_depositor = EPrints::DataObj::User->new( $session, $eprint->get_value( "sword_depositor" ) );

        my $xml = EPrints::Sword::Utils::create_xml( $session,
			eprint => $eprint,
			sword_treatment => "",
			owner => $real_owner,
			depositor => $real_depositor );

	$request->headers_out->{'Location'} = EPrints::Sword::Utils::get_atom_url( $session, $eprint );
        $request->headers_out->{'Content-Length'} = length $xml;
        $request->content_type('application/atom+xml');
        $request->status( 201 );        # Created
        $request->print( $xml );
        $session->terminate;
        return Apache2::Const::OK;
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

