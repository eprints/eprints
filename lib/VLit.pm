######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################
#
# This package is still experiemental!
#
######################################################################

package EPrints::VLit;

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

	my $version = $q->param( "xuversion" );
	my $locspec = $q->param( "locspec" );

	if( !defined $version && !defined $q->param( "mode" ) )
	{
		# We don't need to handle it, just do this 
		# the normal way.
		return DECLINED;
	}

	my $session = EPrints::Session->new();

	if( !defined $locspec )
	{
		$locspec = "charrange:";
	}

	my $LSMAP = {
"area" => \&ls_area,
"charrange" => \&ls_charrange
};

	unless( $locspec =~ m/^([a-z]+):(.*)$/ )
	{
		send_http_error( 400, "Bad locspec \"$locspec\"" );
		return;
	}

	my( $lstype, $lsparam ) = ( $1, $2 );

	my $fn = $LSMAP->{$lstype};

	if( !defined $fn )
	{
		send_http_error( 501, "Unsupported locspec" );
		return;
	}

	&$fn( $filename, $lsparam, $locspec, $session );

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
	if( defined $type )
	{
		$r->content_type( $type );
	}
	$r->status_line( "200 YAY" );
	$r->send_http_header;
}

####################

sub ls_charrange
{
	my( $filename, $param, $locspec, $session ) = @_;

	my $r = Apache->request;
	
#	if( $r->content_type !~ m#^text/# )
#	{
#		send_http_error( 400, "Can't return a charrange of mimetype: ".$r->content_type );
#		return;
#	}
		
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
			send_http_error( 400, "Malformed charrange param: $param" );
			return;
		}
		( $offset, $length ) = ( $1, $2 );
	}

	my $q = new CGI;
	my $mode = $q->param( "mode" );


	my $readoffset = $offset;
	my $readlength = $length;
	my $constart = -1;
	my $conend = -1;
	if( $mode eq "context" )
	{
		my $contextsize = $session->get_archive()->get_conf( "vlit" )->{context_size};
		$readoffset-=$contextsize;
		$readlength+=$contextsize+$contextsize;
		$constart = $contextsize;
		if( $readoffset<0 )
		{
			$constart += $readoffset;
			$readlength += $readoffset;
			$readoffset=0;
		}
		$conend = $readlength-$contextsize;
	}
	
	my $fh = new FileHandle( $filename, "r" );
	binmode( $fh );
	my $data = "";
	$fh->seek( $readoffset, 0 );
	$fh->read( $data, $readlength );
	$fh->close();

	my $baseurl = "http://".$r->hostname.$r->uri;

	if( $mode eq "human" || $mode eq "context" || $mode eq 'spanSelect' || $mode eq 'endSelect' || $mode eq 'link' )
	{
		my $html = "";
		my $o;
		$html.='<span class="vlit-charrange">';
		for $o (0..$readlength-1)
		{
			if( $o == $constart)
			{
				$html.='<span class="vlit-highlight">';
			}
			my $c=substr($data,$o,1);
			$c = '&amp;' if( $c eq "&" );
			$c = '&gt;' if( $c eq ">" );
			$c = '&lt;' if( $c eq "<" );
			$c = '<br />' if( $c eq "\n" );
			if( $mode eq 'spanSelect' )
			{ 
				my $url = $baseurl.'?locspec=charrange:'.($offset+$o)."/".($length-$o).'&mode=endSelect';
				$c ='<a href="'.$url.'">'.$c.'</a>';
			}
			if( $mode eq 'endSelect' )
			{ 
				my $url = $baseurl.'?locspec=charrange:'.($offset)."/".($o+1).'&mode=link';
				$c ='<a href="'.$url.'">'.$c.'</a>';
			}
			$html.=$c;
			if( $o == $conend-1 )
			{
				$html.='</span>';
			}
		}
		$html.='</span>';
		my $front = '';
		unless( $param eq "" )
		{
			my $url = $baseurl;
			if( $mode eq "human" )
			{
				$url .= "?locspec=charrange:$param&mode=context";
			}
			$front = '<big><sup><a href="'.$url.'">trans</a></sup></big> ';
		}
		my $copyurl = $session->get_archive()->get_conf( "vlit" )->{copyright_url};
		$front .= '<big><sup><a href="'.$copyurl.'">&copy;</a></sup></big>';
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
		my $title = "Character Range from $offset, length $length";
		if( $mode eq 'link' )
		{
			my $url = $baseurl.'?locspec=charrange:'.($offset)."/".($length);
			my $urlh = $url.'&mode=human';
			$msg=<<END;
<p><b>$title</b></p>
<p>Raw char quote: <a href="$url">$url</a></p>
<p>Human readable (HTML): <a href="$urlh">$urlh</a></p>
<hr noshade="noshade">
END
		}
		$r->print( <<END );
<html>
<head>
  <title>$title</title>
  <link rel="stylesheet" type="text/css" href="/eprints.css" title="screen stylesheet" media="screen" />
</head>
<body class="vlit">
$msg
 <p>$front $html</p>
</body>
</html>
END
	}
	elsif( $mode eq "xml-entity" )
	{
		my $page = new XML::DOM::Document();
		$page->setXMLDecl(
			$page->createXMLDecl( "1.0", "UTF-8", "yes" ) );
		my $transclusion = $page->createElement( "transclusion" );
		$transclusion->setAttribute(
			"xlmns", 
			"http://xanadu.net/transclusion/xu/1.0" );
		$transclusion->setAttribute( "href", $baseurl );
		$transclusion->setAttribute( "offset", $offset );
		$transclusion->setAttribute( "length", $length );
		$transclusion->appendChild( $page->createTextNode( $data ) );
		$page->appendChild( $transclusion );	

		send_http_header( "text/xml" );
		$r->print( $page->toString );
	}
	else
	{
		send_http_header();
		$r->print( $data );
	}
}

sub ls_area
{
	my( $file, $param, $resspec, $session ) = @_;
	
	unless( $param=~m/^(\d+),(\d+)\/(\d+),(\d+)$/ )
	{
		send_http_error( 400, "Malformed area param: $param" );
		return;
	}
	
	my $cache = cache_file( $resspec, $param );
	
	unless( -e $cache )
	{
		my( $x, $y, $w, $h ) = ( $1, $2, $3, $4 );

		my $cmd = "convert -crop ".$w."x".$h."+$x+$y '$file' 'gif:$cache'";
		`$cmd`;

		if( !-e $cache )
		{
			send_http_error( 500, "Error making image" );
			return;
		}
	}

	send_http_header( "image/gif" );
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
