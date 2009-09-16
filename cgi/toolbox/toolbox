######################################################################
#
#  EPrints Toolbox
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

use EPrints;
use EPrints::Toolbox;
use strict;

my $session = new EPrints::Session;
exit( 0 ) unless( defined $session );

my $cmd = $session->param( "verb" );
my $username = $session->param( "username" );
my $password = $session->param( "password" );

my %opts = ();

if( !$session->valid_login( $username, $password ) )
{
	toolbox_fail( $session, "Invalid username/password" );
}

$session->{current_user} = EPrints::DataObj::User::user_with_username( $session, $username );

if( !$session->{current_user}->allow( "toolbox" ) )
{
	toolbox_fail( $session, "User '$username' not authorised to use toolbox functions" );
}

$opts{data_fn} = sub {
	my( %opts ) = @_;

	my $data = $session->param( "data" );
	if( EPrints::Utils::is_set( $data ) )
	{
		return $data;
	}

	my $fn = $opts{session}->param( "datafile" );
	$data = join( "", <$fn> );
	return $data;
};


$opts{format} = $session->param( "format" );
$opts{filename} = $session->param( "filename" );
$opts{field} = $session->param( "field" );

my $eprintid = $session->param( "eprint" );
if( EPrints::Utils::is_set( $eprintid ) )
{
	$opts{eprint} = EPrints::DataObj::EPrint->new( $session, $eprintid );
	if( !defined $opts{eprint} )
	{
		toolbox_fail( $session, "Could not find eprint $eprintid" );
	}
}

my $docid = $session->param( "document" );
if( EPrints::Utils::is_set( $docid ) )
{
	$opts{document} = EPrints::DataObj::Document->new( $session, $docid );
	if( !defined $opts{document} )
	{
		toolbox_fail( $session, "Could not find document $docid" );
	}
}

$opts{session} = $session;

my $fn_name = "EPrints::Toolbox::tool_".$cmd;

my( $rc, $output ) = eval "$fn_name( \%opts )";
if( $@ )
{
	toolbox_fail( $session, "Command '$cmd' failed.", [$@] );
}
if( $rc ) 
{
	toolbox_fail( $session, "Command Failed", $output );
}

$session->send_http_header( content_type=>"text/plain" );
print $output;

$session->terminate();
exit;

sub toolbox_fail
{
	my( $session, $msg, $problems ) = @_;

	my $error = $session->make_element( "eprints_toolbox_error" );
	my $message = $session->make_element( "message" );
	$error->appendChild( $message );
	$message->appendChild( $session->make_text( $msg ) );
	if( defined $problems )
	{
		foreach my $problem ( @{$problems} )
		{
			my $problem_dom = $session->make_element( "problem" );
			$error->appendChild( $problem_dom );
			$problem_dom->appendChild( $session->make_text( $problem ) );
		}
	}
	EPrints::XML::tidy( $error );
	$session->send_http_header( content_type=>"text/xml" );

	print EPrints::XML::to_string( $error );
	$session->terminate;
	exit;
}

