######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::Xanadu;

use CGI;
use Apache;
use Apache::Constants;

use strict;

sub handler
{
	my( $r ) = @_;

	my $filename = $r->filename;

	if ( ! -r $filename ) {
		return NOT_FOUND;
	}

	my $q = new CGI;

	my $locspec = $q->param( "locSpec" );

	if( !defined $locspec && !defined $q->param( "mode" ) )
	{
		# We don't need to handle it, just do this 
		# the normal way.
		return DECLINED;
	}

	if( !defined $locspec )
	{
		$locspec = "byterange:";
	}

	my $LSMAP = {
"area" => \&ls_area,
"byterange" => \&ls_byterange
};

	unless( $locspec =~ m/^([a-z]+):(.*)$/ )
	{
		send_http_error( 404, "Bad LocSpec" );
		return;
	}

	my( $lstype, $lsparam ) = ( $1, $2 );

	my $fn = $LSMAP->{$lstype};

	if( !defined $fn )
	{
		send_http_error( 404, "Unsupported LocSpec" );
		return;
	}

	&$fn( $filename, $lsparam, $locspec );

	return OK;
}



sub send_http_error
{
	my( $code, $message ) = @_;

	my $r = Apache->request;
	$r->content_type( 'text/html' );
	$r->status_line( "$code $message" );
	$r->send_http_header;
	my $title = "Error $code in VLit request";
	$r->print( <<END );
<html>
<head><title>$title</title></head>
<body>
  <h1>$title</h1>
  <p>$message</p>
</body>
END
}

sub send_http_header
{
	my( $type ) = @_;

	my $r = Apache->request;
	$r->content_type( $type );
	$r->status_line( "200 YAY" );
	$r->send_http_header;
}

####################

sub ls_byterange
{
	my( $filename, $param, $locspec ) = @_;

	my $r = Apache->request;

	my( $offset, $length );
	if( $param eq "" )
	{
		$offset = 0;
		$length = -s $filename;
	}
	else
	{	
		unless( $param=~m/^(\d+)\/(\d+)$/ )
		{
			send_http_error( 404, "Malformed byterange param: $param" );
			return;
		}
		( $offset, $length ) = ( $1, $2 );
	}
	
	my $fh = new FileHandle( $filename, "r" );
	binmode( $fh );
	my $data = "";
	$fh->seek( $offset, 0 );
	$fh->read( $data, $length );
	$fh->close();

	my $q = new CGI;
	my $mode = $q->param( "mode" );

	my $baseurl = "http://".$r->hostname.$r->uri;

	if( $mode eq "human" || $mode eq 'spanSelect' || $mode eq 'endSelect' || $mode eq 'link' )
	{
		my $html = "";
		my $o;
		for $o (0..$length-1)
		{
			my $c=substr($data,$o,1);
			$c = '&amp;' if( $c eq "&" );
			$c = '&gt;' if( $c eq ">" );
			$c = '&lt;' if( $c eq "<" );
			$c = '<br />' if( $c eq "\n" );
			if( $mode eq 'spanSelect' )
			{ 
				my $url = $baseurl.'?locSpec=byterange:'.($offset+$o)."/".($length-$o).'&mode=endSelect';
				$c ='<a href="'.$url.'">'.$c.'</a>';
			}
			if( $mode eq 'endSelect' )
			{ 
				my $url = $baseurl.'?locSpec=byterange:'.($offset)."/".($o+1).'&mode=link';
				$c ='<a href="'.$url.'">'.$c.'</a>';
			}
			$html.=$c;
		}
		my $front = '';
		unless( $param eq "" )
		{
			$front = '<big><sup><a href="'.$baseurl.'">trans</a></sup></big> ';
		}
		$front .= '<big><sup><a href="http://xanadu.com">&copy;</a></sup></big>';
		my $msg='';
		if( $mode eq "endSelect" )
		{ 
			$msg='<h1>select end point:</h1>';
		}
		if( $mode eq "spanSelect" )
		{ 
			$msg='<h1>select start point:</h1>';
		}
		
			
		send_http_header( "text/html" );
		my $title = "Byterange from: resspec (from $offset, length $length)";
		if( $mode eq 'link' )
		{
			my $url = $baseurl.'?locSpec=byterange:'.($offset)."/".($length);
			my $urlh = $url.'&mode=human';
			$msg=<<END;
<p><b>$title</b></p>
<p>Raw byte quote: <a href="$url">$url</a></p>
<p>Human readable (HTML): <a href="$urlh">$urlh</a></p>
<hr noshade="noshade">
END
		}
		$r->print( <<END );
<html>
<head><title>$title</title></head>
<body>
$msg
 <p>$front $html</p>
</body>
</html>
END
	}
	else
	{
		send_http_header( "text/plain" );
		$r->print( $data );
	}
}

sub ls_area
{
	my( $file, $param, $resspec, $session ) = @_;
	
	unless( $param=~m/^(\d+),(\d+)\/(\d+),(\d+)$/ )
	{
		send_http_error( $session, 404, "Malformed area param: $param" );
		return;
	}
	
	my $cache = cache_file( $resspec, $param );
	
	unless( -e $cache )
	{
		my( $x, $y, $w, $h ) = ( $1, $2, $3, $4 );

		my $cmd = "convert -crop ".$w."x".$h."+$x+$y '$file' 'gif:$cache'";
print STDERR "$cmd\n";
		`$cmd`;

		if( !-e $cache )
		{
			send_http_error( $session, 500, "Error making image" );
			return;
		}
	}

	send_header( $session, "image/gif" );
	print `cat $cache`;
}


sub cache_file
{
	my( $resspec, $param ) = @_;

	my $TMPDIR = "/tmp/partial";

	$resspec =~ s/[^a-z0-9]/sprintf('_%02X',ord($&))/ieg;
	$param =~ s/[^a-z0-9]/sprintf('_%02X',ord($&))/ieg;

	my $dir = $TMPDIR."/".$resspec;
	
	mkdir( $dir ) if( !-d $dir );

	return $dir."/".$param;
}


1;
