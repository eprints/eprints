######################################################################
#
# EPrints::VLit
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

B<EPrints::VLit> - VLit Transclusion Module

=head1 DESCRIPTION

This module is consulted when any document file is served. It allows
subsets of the whole to be served.

This is an experimental feature. It may be turned off in the configuration
if you object to it for some reason.

=over 4

=cut

package EPrints::VLit;

use CGI;
use Apache;
use Apache::Constants;
use Digest::MD5;
use FileHandle;

use strict;
use EPrints::XML;

my $TMPDIR = "/tmp/partial";



######################################################################
=pod

=item EPrints::VLit::handler( $r )

undocumented

=cut
######################################################################

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




######################################################################
=pod

=item EPrints::VLit::send_http_error( $code, $message )

undocumented

=cut
######################################################################

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


######################################################################
=pod

=item EPrints::VLit::send_http_header( $type )

undocumented

=cut
######################################################################

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


######################################################################
=pod

=item EPrints::VLit::ls_charrange( $filename, $param, $locspec, $session )

undocumented

=cut
######################################################################

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

	my $baseurl = $session->get_archive->get_conf("base_url").$r->uri;

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
			if( $mode eq "context" )
			{
				$url .= "?mode=human&locspec=charrange:";
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
			my $url = $baseurl.'?xuversion=1.0&locspec=charrange:'.($offset)."/".($length);
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
		my $page = EPrints::XML::make_document();
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
		$r->print( EPrints::XML::to_string( $page ) );
	}
	else
	{
		send_http_header();
		$r->print( $data );
	}
}


######################################################################
=pod

=item EPrints::VLit::ls_area( $file, $param, $resspec, $session )

undocumented

=cut
######################################################################

sub ls_area
{
	my( $file, $param, $resspec, $session ) = @_;

	my $page = 1;
	my $opts = {
		page => 1,
		hrange => { start=>0 },
		vrange => { start=>0 }
	};

	my $s;
	if( $session->param( "scale" ) )
	{
		$s = $session->param( "scale" );
		$s = undef if( $s <= 0 || $s>1000 || $s==100 );
	}

	foreach( split( "/", $param ) )
	{
		my( $key, $value ) = split( "=", $_ );
		if( $key eq "page" )
		{
			unless( $value =~ m/^\d+$/ )
			{
				send_http_error( 400, "Bad page id in area locspec" );
				return;
			}
			$opts->{page} = $value;
		}
		if( $key eq "hrange" || $key eq "vrange" )
		{
			unless( $value =~ m/^(\d+)?,(\d+)?$/ )
			{
				send_http_error( 400, "Bad $key in area locspec" );
				return;
			}
			$opts->{$key}->{start} = $1 if( defined $1 );
			$opts->{$key}->{end} = $2 if( defined $2 );
		}
	}
	
	my $cache = cache_file( "area", $param."/".$s );

	my $dir = $TMPDIR."/area/".Digest::MD5::md5_hex( $file );


	unless( -e $cache )
	{
		my( $p, $x, $y, $w, $h ) = ( $1, $2, $3, $4, $5 );

		# pagearea/ exists cus of cache_file called above.
print STDERR "dir=$dir\n";	
		if( !-d $dir )
		{
print STDERR "mkdir=$dir\n";	
			mkdir( $dir );
			my $cmd = "/usr/bin/X11/convert '$file' 'tif:$dir/%d'";
print STDERR "c1=$cmd\n";
			`$cmd`;
		}
	}

	my $pageindex = $opts->{page} - 1;

	my $crop = "";

	# Don't crop if we is wanting the full page
	unless( $opts->{hrange}->{start} == 0 && !defined $opts->{hrange}->{end}
	 && $opts->{vrange}->{start} == 0 && !defined $opts->{vrange}->{end} )
	{
		$crop = "-crop ";
		if( defined $opts->{hrange}->{end} )
		{
			$crop .= ($opts->{hrange}->{end} - $opts->{hrange}->{start} + 1);
		}
		else
		{
			$crop .= '999999';
		}
		$crop .= "x";
		if( defined $opts->{vrange}->{end} )
		{
			$crop .= ($opts->{vrange}->{end} - $opts->{vrange}->{start} + 1);
		}
		else
		{
			$crop .= '999999';
		}
		$crop .= "+".$opts->{hrange}->{start};
		$crop .= "+".$opts->{vrange}->{start};
	}

	my $cmd;
	$cmd = "tiffinfo $dir/$pageindex";
	print STDERR $cmd."\n";
	my $scale = '';
	my @d = `$cmd`;
	foreach( @d )
	{
		$scale = '-scale 100%x200%' if m/Resolution: 204, 98 pixels\/inch/;
	}
	my $scale2 = "";
	if( defined $s )
	{
		$scale2 = '-scale '.$s.'%x'.$s.'%';
	}

	$cmd = "/usr/bin/X11/convert $scale $crop $scale2 '$dir/$pageindex' 'png:$cache'";
	print STDERR $cmd."\n";
	`$cmd`;
	

	send_http_header( "image/png" );
	$cmd = "cat $cache";
	print STDERR $cmd."\n";
	print `$cmd`;
}




######################################################################
=pod

=item EPrints::VLit::cache_file( $resspec, $param )

undocumented

=cut
######################################################################

sub cache_file
{
	my( $resspec, $param ) = @_;

	$param = "null" if( $param eq "" );

	$resspec =~ s/[^a-z0-9]/sprintf('_%02X',ord($&))/ieg;
	$param =~ s/[^a-z0-9]/sprintf('_%02X',ord($&))/ieg;

	mkdir( $TMPDIR ) if( !-d $TMPDIR );

	my $dir = $TMPDIR."/".$resspec;
	
	mkdir( $dir ) if( !-d $dir );

	return $dir."/".$param;
}


1;

######################################################################
=pod

=back

=cut

