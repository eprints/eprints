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

require 'sys/syscall.ph';

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
	my( $msg ) = @_;

	if( $debug )
	{
		my @call = caller(1);
#		if( $name eq "submit" )
#		{
#			print "$name - $msg\n";
#		}
#		else
#		{
		print STDERR ">$call[3]($call[2]):\n$msg\n";
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

######################################################################
#
# $text = render_struct( $ref, $depth )
#
#  Renders a reference into a human readable tree.
#
######################################################################


sub render_struct
{
	my ( $ref , $depth ) = @_;

	$depth = 0 if ( !defined $depth );
	my $text = "";

	if ( !defined $ref ) 
	{
		$text = "  "x$depth;
		$text.= "[undef]\n";
		return $text;
	} 

	$type = ref( $ref );

	if( $type eq "HASH" )
	{
		my %bits = %{$ref};
		$text.= "  "x$depth;
		$text.= "HASH\n";
		foreach( keys %bits ) 
		{
			$text.= "  "x$depth;
			$text.= " $_=>\n";
			$text.= render_struct( $bits{$_} , $depth+1 );
		}
	} 
	elsif( $type eq "ARRAY" )
	{
		my @bits = @{$ref};
		$text.= "  "x$depth;
		$text.= "ARRAY (".(scalar @bits).")\n";
		foreach( @bits ) 
		{
			$text.= render_struct( $_ , $depth+1 );
		}
	}
	else
	{
		$text.= "  "x$depth;
		$text.= "\"$ref\"\n";
	}
			
	return $text;
}

sub microtime
{
	my $TIMEVAL_T = "LL";

	$t = pack($TIMEVAL_T, ());

	syscall( &SYS_gettimeofday, $t, 0) != -1
		or die "gettimeofday: $!";

	@t = unpack($TIMEVAL_T, $t);
	$t[1] /= 1_000_000;

	return $t[0]+$t[1];
}
		
1;
