######################################################################
#
# EPrints Logging Utility
#
#  Handy stuff for using log files.
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

package EPrints::Log;


######################################################################
#
# GLOBAL DEBUG FLAG! Set this to 1 if debug information should be
# written to logs.
#
######################################################################

my $debug = 1;



######################################################################
#
# log_entry( $name, $msg )
#
#  Write a log message. Log messages are always written during the
#  normal course of operation. Accordingly, log messages should be
#  concise; for finer-grained messages to use during debugging, use
#  debug(). $name should be something useful (like the module name.)
#
######################################################################

sub log_entry
{
	my( $name, $msg ) = @_;
	
	print STDERR "$name: $msg\n";

#	my $log_filename = "$EPrintSite::SiteInfo::log_path/$name.log";
#
#	if( -e $log_filename )
#	{
#		open LOGFILE, ">>$log_filename";
#	}
#	else
#	{
#		open LOGFILE, ">$log_filename";
#	}
#
#	print LOGFILE "$name: $msg\n" if( defined $log_filename );
#
#	close LOGFILE;
}


######################################################################
#
# debug( $name, $msg )
#
#  Write a debug message out to a log, if debugging is switched on.
#
######################################################################

sub debug
{
	my( $name, $msg ) = @_;

	if( $debug )
	{
#		if( $name eq "submit" )
#		{
#			print "$name - $msg\n";
#		}
#		else
#		{
		print STDERR "$name: $msg\n";
#		}

#		my $log_filename = "$EPrintSite::SiteInfo::log_path/$name.log";
#
#print STDERR "<P>Log file is $log_filename</P>\n";
#
#		if( -e $log_filename )
#		{
#			open LOGFILE, ">>$log_filename";
#		}
#		else
#		{
#			open LOGFILE, ">$log_filename";
#		}
#
#		print LOGFILE "$name: $msg\n" if( defined $log_filename );
#
#		close LOGFILE;
	}
}


1;
