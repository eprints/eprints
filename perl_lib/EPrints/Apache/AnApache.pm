######################################################################
#
# EPrints::Apache::AnApache
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

B<EPrints::Apache::AnApache> - Load appropriate Apache Module

=head1 DESCRIPTION

Handy way of loading Apache or Apache2 depending on value in SystemSettings.

Plus functions to paper over the cracks between the two interfaces.

=over 4

=cut

package EPrints::Apache::AnApache;

BEGIN
{
	use Exporter;
	our (@ISA, @EXPORT );
	@ISA	 = qw(Exporter);
	@EXPORT  = qw(OK AUTH_REQUIRED FORBIDDEN DECLINED SERVER_ERROR NOT_FOUND DONE);
}

use strict;

######################################################################
=pod

=item EPrints::Apache::AnApache::upload_doc_file( $session, $document, $paramid );

Collect a file named $paramid uploaded via HTTP and add it to the 
specified $document.

=item EPrints::Apache::AnApache::upload_doc_archive( $session, $document, $paramid, $archive_format );

Collect an archive file (.ZIP, .tar.gz, etc.) uploaded via HTTP and 
unpack it then add it to the specified document.

=item EPrints::Apache::AnApache::send_http_header( $request )

Send the HTTP header, if needed.

$request is the current Apache request. 

=item EPrints::Apache::AnApache::header_out( $request, $header, $value )

Set a value in the HTTP headers of the response. $request is the
apache request object, $header is the name of the header and 
$value is the value to give that header.

=item $value = EPrints::Apache::AnApache::header_in( $request, $header )

Return the specified HTTP header from the current request.

=item $request = EPrints::Apache::AnApache::get_request

Return the current Apache request object.

=cut
######################################################################

my $av =  $EPrints::SystemSettings::conf->{apache};
if( defined $av && $av eq "2" )
{
	# Apache 2

	# Detect API version, either 1 or 2 
	$EPrints::Apache::AnApache::ModPerlAPI = 0;

	eval "require Apache2::Util"; 
	unless( $@ ) { $EPrints::Apache::AnApache::ModPerlAPI = 2; }

	if( !$EPrints::Apache::AnApache::ModPerlAPI ) 
	{ 
		eval "require Apache2"; 
		unless( $@ ) { $EPrints::Apache::AnApache::ModPerlAPI = 1; } 
	}

	# no API version, is mod_perl 2 even installed?
	if( !$EPrints::Apache::AnApache::ModPerlAPI )
	{
		# can't find either old OR new mod_perl API

		# not logging functions available to eprints runtime yet
		print STDERR "\n------------------------------------------------------------\n";
		print STDERR "Failed to load mod_perl for Apache 2\n";
		eval "require Apache"; if( !$@ ) {
			print STDERR "However mod_perl for Apache 1.3 is available. Is the 'apache'\nparameter in perl_lib/EPrints/SystemSettings.pm correct?\n";
		}
		print STDERR "------------------------------------------------------------\n";

		die;
	};

	my @modules = ( 
		'ModPerl::Registry' 
	);
	if( $EPrints::Apache::AnApache::ModPerlAPI == 1 )
	{
		push @modules,
			'Apache::SubProcess',
			'Apache::Const',
			'Apache::Connection',
			'Apache::RequestRec';
	}
	if( $EPrints::Apache::AnApache::ModPerlAPI == 2 )
	{
		push @modules,
			'Apache2::SubProcess',
			'Apache2::Const',
			'Apache2::Connection';
	}
	foreach my $module ( @modules )
	{
		eval "use $module"; 
		next unless( $@ );
		die "Error loading module $module:\n$@";
	}

	eval '

		sub send_http_header
		{
			my( $request ) = @_;
	
			# do nothing!
		}

		sub header_out
		{
			my( $request, $header, $value ) = @_;
			
			$request->headers_out->{$header} = $value;
		}

		sub header_in
		{
			my( $request, $header ) = @_;	
	
			return $request->headers_in->{$header};
		}

		sub get_request
		{
			if( $EPrints::Apache::AnApache::ModPerlAPI == 1 )
			{
				return Apache->request;
			}
			if( $EPrints::Apache::AnApache::ModPerlAPI == 2 )
			{
				return Apache2::RequestUtil->request();
			}
			die "Unknown ModPerlAPI version: $EPrints::Apache::AnApache::ModPerlAPI";
		}
	';
	if( $@ ) { die $@; }
}
else
{
	# Apache 1.3
	eval "require Apache"; if( $@ ) {
		# not logging functions available yet
		print STDERR "\n------------------------------------------------------------\n";
		print STDERR "Failed to load mod_perl for Apache 1.3\n";
		my $modperl2 = 0;
		eval "require Apache2"; unless( $@ ) { $modperl2 = 1; }
		eval "require Apache2::Utils"; unless( $@ ) { $modperl2 = 1; }
 		if( $modperl2 )
		{
			print STDERR "However mod_perl for Apache 2 is available. Is the 'apache'\nparameter in perl_lib/EPrints/SystemSettings.pm correct?\n";
		}
		print STDERR "------------------------------------------------------------\n";

		die;
	};
	eval "require Apache::Registry"; if( $@ ) { die $@; }
	eval "require Apache::Constants; "; if( $@ ) { die $@; }
	eval '

		sub OK { &Apache::Constants::OK; }
		sub AUTH_REQUIRED { &Apache::Constants::AUTH_REQUIRED; }
		sub FORBIDDEN { &Apache::Constants::FORBIDDEN; }
		sub DECLINED { &Apache::Constants::DECLINED; }
		sub SERVER_ERROR { &Apache::Constants::SERVER_ERROR; }
		sub NOT_FOUND { &Apache::Constants::NOT_FOUND; }
		sub DONE { &Apache::Constants::DONE; }

		sub send_http_header
		{
			my( $request ) = @_;
	
			$request->send_http_header;
		}


		sub header_out
		{
			my( $request, $header, $value ) = @_;

			$request->header_out( $header => $value );
		}

		sub header_in
		{
			my( $request, $header ) = @_;	
	
			return $request->header_in( $header );
		}
		
		sub get_request
		{
			return Apache->request;
		}
	';
	if( $@ ) { die $@; }
}

######################################################################
=pod

=item $value = EPrints::Apache::AnApache::cookie( $request, $cookieid )

Return the value of the named cookie, or undef if it is not set.

This avoids using L<CGI>, so does not consume the POST data.

=cut
######################################################################

sub cookie
{
	my( $request, $cookieid ) = @_;

	my $cookies = EPrints::Apache::AnApache::header_in( $request, 'Cookie' );

	return unless defined $cookies;

	foreach my $cookie ( split( /;\s*/, $cookies ) )
	{
		my( $k, $v ) = split( '=', $cookie );
		if( $k eq $cookieid )
		{
			return $v;
		}
	}

	return undef;
}


sub upload_doc_file
{
	my( $session, $document, $paramid ) = @_;

	my $cgi = $session->get_query;

	my $filesize = $session->get_request->headers_in->{'Content-Length'};

	return $document->upload( 
		$cgi->upload( $paramid ), 
		$cgi->param( $paramid ),
		0, # preserve_path
		$filesize );	
}

sub upload_doc_archive
{
	my( $session, $document, $paramid, $archive_format ) = @_;

	my $cgi = $session->get_query;

	return $document->upload_archive( 
		$cgi->upload( $paramid ), 
		$cgi->param( $paramid ), 
		$archive_format );	
}

######################################################################
=pod

=item EPrints::Apache::AnApache::send_status_line( $request, $code, $message )

Send a HTTP status to the client with $code and $message.

=cut
######################################################################

sub send_status_line
{	
	my( $request, $code, $message ) = @_;
	
	if( defined $message )
	{
		$request->status_line( "$code $message" );
	}
	$request->status( $code );
}

1;
