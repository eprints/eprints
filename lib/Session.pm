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
#  26/11/99 - Created by Robert Tansley
#
######################################################################

package EPrints::Session;

use Apache;

use EPrints::Database;
use EPrints::HTMLRender;

use EPrintSite::SiteRoutines;

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
	
	# Get the Apache request object
	#$self->{request} = Apache::request( "POST" );

	# Create an HTML renderer object
	$self->{render} = EPrints::HTMLRender->new( $self, $offline );

	# Create a database connection
	$self->{database} = EPrints::Database->new();
	
	if( !defined $self->{database} )
	{
		# Database connection failure - noooo!
		$self->failure( "Failed to connect to database" );
	}

#$self->{starttime} = gmtime( time );

#EPrints::Log->debug( "Session", "Started session at $self->{starttime}" );
	
	EPrintSite::SiteRoutines->session_init( $self, $offline );


	my @params = $self->{render}->{query}->param();
	
	foreach (@params)
	{
		my @vals = $self->{render}->{query}->param($_);
		EPrints::Log->debug( "Session", "Param <$_> Values:<".@vals.">" );
	}
	

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
	
	my $error_text = "<STRONG>$problem</STRONG>";

	$self->{render}->render_error( $error_text,
	                                 $EPrints::SiteInfo::frontpage,
	                                 $EPrints::SiteInfo::sitename );
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
	
#EPrints::Log->debug( "Session", "Closing session started at $self->{starttime}" );
	EPrintSite::SiteRoutines->session_close( $self );

	$self->{database}->disconnect();

}


1;
