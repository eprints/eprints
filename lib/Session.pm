######################################################################
#
# EPrint Session
#
#  Holds information about a particular EPrint session.
#
#
#  Fields are:
#    database        - EPrints::Database object
#    renderer        - EPrints::HTMLRender object
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

package EPrints::Session;

use EPrints::Database;
use EPrints::HTMLRender;
use EPrints::Language;
use EPrints::ConfigLoader;

use EPrintSite::SiteRoutines;
use EPrintSite::SiteInfo;

use strict;

######################################################################
#
# new( $offline )
#
#  Start a new EPrints session, opening a database connection,
#  creating a CGI query object and any other necessary session state
#  things.
#
#  Command line scripts should pass in true for $offline.
#  Apache-invoked scripts can omit it or pass in 0.
#
######################################################################

sub new
{
	my( $class, $offline ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{query} = ( $offline ? new CGI( {} ) : new CGI );

	# This should be set at installation.	
	$self->{basepath} = "/opt/eprints";

	if( $offline )
	{
		die "fucked";
	}
	else
	{
		# Errors in english - no configuration yet.
		# These are pretty fatal - nothing will work if
		# this bit dosn't.

		$self->{site} = EPrints::ConfigLoader::get_config_by_url(
					$self->{query}->url() );
		if( !defined $self->{site} )
		{
			die "Can't load config for URL: $self->{query}->url()";
		}
	}

	# Create a database connection
	$self->{lang} = EPrints::Language::fetch( $self->{site} );

	# Load the config files
	$self->{metainfo} = EPrints::MetaInfo->new( $self->{site} );
	
	# Create an HTML renderer object
	$self->{render} = EPrints::HTMLRender->new( $self, $offline, $self->{query} );

	# Create a database connection
	$self->{database} = EPrints::Database->new( $self );
	
	if( !defined $self->{database} )
	{
		# Database connection failure - noooo!
		$self->failure( $self->{lang}->phrase( "H:fail_db_connect" ) );
	}

#$self->{starttime} = gmtime( time );

#EPrints::Log::debug( "Session", "Started session at $self->{starttime}" );
	
	EPrintSite::SiteRoutines::session_init( $self, $offline );

#
#	my @params = $self->{render}->{query}->param();
#	
#	foreach (@params)
#	{
#		my @vals = $self->{render}->{query}->param($_);
#		EPrints::Log::debug( "Session", "Param <$_> Values:<".@vals.">" );
#	}
	

	return( $self );
}


######################################################################
#
# failure()
#
#  Print an error messages describing why an operation has failed.
#
######################################################################

sub failure
{
	my( $self, $problem ) = @_;
	
	$self->{render}->render_error( $problem,
	                               $EPrintSite::SiteInfo::frontpage,
	                               $EPrintSite::SiteInfo::sitename );
}


######################################################################
#
# terminate()
#
#  Perform any cleaning up necessary
#
######################################################################

sub terminate
{
	my( $self ) = @_;
	
#EPrints::Log::debug( "Session", "Closing session started at $self->{starttime}" );
	EPrintSite::SiteRoutines::session_close( $self );

	$self->{database}->disconnect();

}


######################################################################
#
# mail_administrator( $subject, $message )
#
#  Sends a mail to the site administrator with the given subject and
#  message body.
#
######################################################################

sub mail_administrator
{
	my( $self, $subject, $message ) = @_;

	# cjg logphrase here will NOT do it no longer exists.
	
	my $message_body = EPrints::Language::logphrase( "msg_at" ,
	                                             { time=>gmtime( time ) } );
	$message_body .= "\n\n$message\n";

	EPrints::Mailer::send_mail(
		EPrints::Language::logphrase( "site_admin" ),
		$EPrintSite::SiteInfo::admin,
		$subject,
		$message_body );
}



1;
