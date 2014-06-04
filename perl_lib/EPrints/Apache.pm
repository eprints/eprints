=pod

=head1 NAME

B<EPrints::Apache> - Utility methods for talking to mod_perl

=head1 DESCRIPTION

This module provides a number of utility methods for interacting with the
request object.

=head1 METHODS

=over 4

=cut

package EPrints::Apache;

use EPrints::Const qw( :http );

use Exporter;
@ISA	 = qw(Exporter);
@EXPORT  = qw(OK AUTH_REQUIRED FORBIDDEN DECLINED SERVER_ERROR NOT_FOUND DONE);

use ModPerl::Registry;
use Apache2::Util;
use Apache2::SubProcess;
use Apache2::Connection;
use Apache2::RequestUtil;
use Apache2::MPM;
use Apache2::Directive;

# Backwards compatibility - use HTTP_ constants instead of :common constants
use constant {
	AUTH_REQUIRED => EPrints::Const::HTTP_UNAUTHORIZED,
	FORBIDDEN => EPrints::Const::HTTP_FORBIDDEN,
	SERVER_ERROR => EPrints::Const::HTTP_INTERNAL_SERVER_ERROR,
};

use strict;

=item EPrints::Apache::header_out( $request, $header, $value )

Set a value in the HTTP headers of the response. $request is the
apache request object, $header is the name of the header and 
$value is the value to give that header.

=cut

sub header_out
{
	my( $request, $header, $value ) = @_;
	
	$request->headers_out->{$header} = $value;
}

=item $value = EPrints::Apache::header_in( $request, $header )

Return the specified HTTP header from the current request.

=cut

sub header_in
{
	my( $request, $header ) = @_;	

	return $request->headers_in->{$header};
}

=item $request = EPrints::Apache::get_request

Return the current Apache request object.

=cut

sub get_request
{
	return EPrints->new->request;
}

######################################################################
=pod

=item $value = EPrints::Apache::cookie( $request, $cookieid )

Return the value of the named cookie, or undef if it is not set.

This avoids using L<CGI>, so does not consume the POST data.

=cut
######################################################################

sub cookie
{
	my( $request, $cookieid ) = @_;

	my $cookies = EPrints::Apache::header_in( $request, 'Cookie' );

	return unless defined $cookies;

	foreach my $cookie ( split( /;\s*/, $cookies ) )
	{
		my( $k, $v ) = URI::Escape::uri_unescape(split( '=', $cookie, 2 ));
		if( $k eq $cookieid )
		{
			return $v;
		}
	}

	return undef;
}

=item EPrints::Apache::upload_doc_file( $session, $document, $paramid );

Collect a file named $paramid uploaded via HTTP and add it to the 
specified $document.

=cut

sub upload_doc_file
{
	my( $session, $document, $paramid ) = @_;

	my $cgi = $session->get_query;

	my $filename = Encode::decode_utf8( $cgi->param( $paramid ) );

	return $document->upload( 
		$cgi->upload( $paramid ), 
		$filename,
		0, # preserve_path
		-s $cgi->upload( $paramid )
	);	
}

=item EPrints::Apache::upload_doc_archive( $session, $document, $paramid, $archive_format );

Collect an archive file (.ZIP, .tar.gz, etc.) uploaded via HTTP and 
unpack it then add it to the specified document.

=cut

sub upload_doc_archive
{
	my( $session, $document, $paramid, $archive_format ) = @_;

	my $cgi = $session->get_query;

	my $filename = Encode::decode_utf8( $cgi->param( $paramid ) );

	return $document->upload_archive( 
		$cgi->upload( $paramid ), 
		$filename,
		$archive_format );	
}

######################################################################
=pod

=item EPrints::Apache::send_status_line( $request, $code, $message )

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

=item $rc = EPrints::Apache::ranges( $r, $maxlength, $chunks )

Populates the byte-ranges in $chunks requested by the client.

$maxlength is the length, in bytes, of the resource.

Returns the appropriate byte-range result code or OK if no "Range" header is set.

=cut

sub ranges
{
	my( $r, $maxlength, $chunks ) = @_;

	my $ranges = EPrints::Apache::header_in( $r, "Range" );
	return OK if !defined $ranges;

	$ranges =~ s/\s+//g;
	return HTTP_RANGE_NOT_SATISFIABLE if $ranges !~ s/^bytes=//;
	return HTTP_RANGE_NOT_SATISFIABLE if $ranges =~ /[^0-9,\-]/;

	my @ranges = map { [split /\-/, $_] } split(/,/, $ranges);
	return HTTP_RANGE_NOT_SATISFIABLE if !@ranges;

	# handle -500 and 9500-
	# check for broken ranges (in which case we give-up)
	for(@ranges)
	{
		return HTTP_RANGE_NOT_SATISFIABLE if @$_ > 2;
		return HTTP_RANGE_NOT_SATISFIABLE if !length($_->[0]) && !length($_->[1]);
		if( !defined $_->[1] || !length $_->[1] )
		{
			$_->[1] = $maxlength-1;
		}
		if( !length($_->[0]) )
		{
			$_->[0] = $maxlength-$_->[1];
			$_->[1] = $maxlength-1;
		}
		return HTTP_RANGE_NOT_SATISFIABLE if $_->[0] >= $maxlength;
		return HTTP_RANGE_NOT_SATISFIABLE if $_->[1] >= $maxlength;
		return HTTP_RANGE_NOT_SATISFIABLE if $_->[0] > $_->[1];
	}

	@ranges = sort { $a->[0] <=> $b->[0] } @ranges;

	for(my $i = 0; $i < $#ranges;)
	{
		my( $l, $r ) = @ranges[$i,$i+1];
		# left range is superset of right range
		if( $$l[1] >= $$r[1] )
		{
			splice(@ranges,$i+1,1);
		}
		# left range overlaps right range
		elsif( $$l[1] >= $$r[0] )
		{
			$$l[1] = $$r[1];
			splice(@ranges,$i+1,1);
		}
		else
		{
			++$i;
		}
	}

	@$chunks = @ranges;

	return HTTP_PARTIAL_CONTENT;
}


sub redir
{
	my( $r, $url ) = @_;

	EPrints::Apache::send_status_line( $r, 302, "Found" );
	EPrints::Apache::header_out( $r, "Location", $url );
	return DONE;
} 

sub redir_see_other
{
	my( $r, $url ) = @_;

	EPrints::Apache::send_status_line( $r, 303, "See Other" );
	EPrints::Apache::header_out( $r, "Location", $url );
	return DONE;
} 

sub content_negotiate_best_plugin
{
	my( $repository, %o ) = @_;

	EPrints::Utils::process_parameters( \%o, {
		accept_header => "*REQUIRED*",
		consider_summary_page => 1, 
		plugins => "*REQUIRED*",
	 } );

	my $pset = {};
	if( $o{consider_summary_page} )
	{
		$pset->{"text/html"} = { qs=>0.99, DEFAULT_SUMMARY_PAGE=>1 };
	}

	foreach my $plugin ( @{$o{plugins}} )
	{
		my( $type, %params ) = split( /\s*[;=]\s*/, $plugin->{mimetype} );
	
		next if( defined $pset->{$type} && $pset->{$type}->{qs} >= $plugin->{qs} );
		$pset->{$type} = $plugin;
	}
	my @pset_order = sort { $pset->{$b}->{qs} <=> $pset->{$a}->{qs} } keys %{$pset};

	my $accepts = { "*/*" => { q=>0.000001 }};
	CHOICE: foreach my $choice ( split( /\s*,\s*/, $o{accept_header} ) )
	{
		my( $mime, %params ) = split( /\s*[;=]\s*/, $choice );
		$params{q} = 1 unless defined $params{q};
		my $match = $pset->{$mime};
		$params{q} *= defined $match ? $match->{qs} : 0;
		$accepts->{$mime} = \%params;
	}
	my @acc_order = sort { $accepts->{$b}->{q} <=> $accepts->{$a}->{q} } keys %{$accepts};

	my $match;
	CHOICE: foreach my $choice ( @acc_order )
	{
		if( $pset->{$choice} ) 
		{
			$match = $pset->{$choice};
			last CHOICE;
		}

		if( $choice eq "*/*" )
		{
			$match = $pset->{$pset_order[0]};
			last CHOICE;
		}

		if( $choice =~ s/\*[^\/]+$// )
		{
			foreach my $type ( @pset_order )
			{
				if( $choice eq substr( $type, 0, length $type ) )
				{
					$match = $pset->{$type};
					last CHOICE;
				}
			}
		}
	}

	if( $match->{DEFAULT_SUMMARY_PAGE} )
	{
		return "DEFAULT_SUMMARY_PAGE";
	}

	return $match; 
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

