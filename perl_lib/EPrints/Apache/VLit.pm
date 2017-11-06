######################################################################
#
# EPrints::Apache::VLit
#
######################################################################
#
#
######################################################################


=pod

=head1 NAME

B<EPrints::Apache::VLit> - VLit Transclusion Module

=head1 DESCRIPTION

This module is consulted when any document file is served. It allows
subsets of the whole to be served.

This is an experimental feature. It may be turned off in the 
configuration if you object to it for some reason.

=over 4

=cut

package EPrints::Apache::VLit;

use Digest::MD5;
use FileHandle;

use EPrints::Apache::AnApache; # exports apache constants

use strict;

my $TMPDIR = "/tmp/partial";



######################################################################
#
# EPrints::Apache::VLit::handler( $r )
#
######################################################################

sub handler
{
	my( $r ) = @_;

	my $filename = $r->filename;

	if ( ! -r $filename ) 
	{
		return NOT_FOUND;
	}

	my %args = ();
	my @a = split( "&", $r->args );
	foreach my $arg ( @a )
	{
		my( $k, $v ) = split( '=', $arg, 2 );
		$args{$k}=$v;
	}

	my $version = $args{xuversion};
	my $locspec = $args{locspec};

	if( !defined $version && !defined $args{mode} )
	{
		# We don't need to handle it, just do this 
		# the normal way.
		return DECLINED;
	}

	if( !defined $locspec )
	{
		$locspec = "charrange:";
	}

	# undo eprints rewrite!
	my $uri = $r->uri;	
	$uri =~ s#/([0-9]+)/([0-9][0-9])/([0-9][0-9])/([0-9][0-9])/#/$1$2$3$4/#;
	my $repository = EPrints->new->current_repository;
	my $baseurl = $repository->get_conf( "http_url" ).$uri;
	
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

	&$fn( $filename, $lsparam, $locspec, $r, $baseurl, \%args );

	return OK;
}




######################################################################
#
# EPrints::Apache::VLit::send_http_error( $code, $message )
#
######################################################################

sub send_http_error
{
	my( $code, $message ) = @_;

	my $r = EPrints::Apache::AnApache::get_request();
	$r->content_type( 'text/html' );
	EPrints::Apache::AnApache::send_status_line( $r, $code, $message ); 
	$r->send_http_header;
	my $title = "Error $code in Apache::VLit request";
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
#
# EPrints::Apache::VLit::send_http_header( $type )
#
######################################################################

sub send_http_header
{
	my( $type ) = @_;

	my $r = EPrints::Apache::AnApache::get_request();
	if( defined $type )
	{
		$r->content_type( $type );
	}
	EPrints::Apache::AnApache::send_status_line( $r, 200, "YAY"); 
	EPrints::Apache::AnApache::send_http_header( $r );
}



######################################################################
#
# EPrints::Apache::VLit::ls_charrange( $filename, $param, $locspec, $r, $baseurl, $args )
#
######################################################################

sub ls_charrange
{
	my( $filename, $param, $locspec, $r, $baseurl, $args ) = @_;

	my $repository = EPrints->new->current_repository( $r );
	
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

	my $mode = $args->{mode};

	my $readoffset = $offset;
	my $readlength = $length;
	my $constart = -1;
	my $conend = -1;
	if( $mode eq "context" )
	{
		my $contextsize = 512;
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

	if( $mode eq "context2" )
	{
		# has a char range but loads whole document
		$readoffset = 0;
		$readlength = -s $filename;
		$constart = $offset;
		$conend = $offset+$length;
	}
	
	my $fh = new FileHandle( $filename, "r" );
	binmode( $fh );
	my $data = "";
	$fh->seek( $readoffset, 0 );
	$fh->read( $data, $readlength );
	$fh->close();

	if( $mode eq "human" || $mode eq "context" || $mode eq "context2" || $mode eq 'spanSelect' || $mode eq 'endSelect' || $mode eq 'link' || $mode eq 'spanSelect2' || $mode eq 'endSelect2' )
	{
		my $html = "";
		my $BIGINC = 100;
		my $inc = $BIGINC;
		if( $mode eq  'spanSelect2'  ||  $mode eq 'endSelect2' || $mode eq 'context' || $mode eq "context2" )
		{
			$inc = 1;
		}
		$html.='<span class="vlit-charrange">';
		my $toggle = 0;
		for( my $o=0; $o<$readlength; $o+=$inc )
		{
			my $class = "vlit-spanlink".($toggle+1);
			$toggle = !$toggle; 
			if( $o == $constart)
			{
				$html.='<span class="vlit-highlight">';
			}
			if( $o == $constart-512)
			{
				$html.='<a name="c" />';
			}
			my $c=substr($data,$o,$inc);
			# $c is either a string or a single char
			$c =~ s/&/&amp;/g;
			$c =~ s/</&lt;/g;
			$c =~ s/>/&gt;/g;
			$c =~ s/\n/<br \/>/g;
			if( $mode eq 'spanSelect' )
			{ 
				my $url = $baseurl.'?locspec=charrange:'.($offset+$o)."/".($length-$o).'&mode=spanSelect2';
				$c ='<a class="'.$class.'" href="'.$url.'">'.$c.'</a>';
			}
			if( $mode eq 'spanSelect2' && $o < $BIGINC )
			{ 
				my $url = $baseurl.'?locspec=charrange:'.($offset+$o)."/".($length-$o).'&mode=endSelect';
				$c ='<a class="'.$class.'" href="'.$url.'">'.$c.'</a>';
			}
			if( $mode eq 'endSelect' )
			{ 
				my $url = $baseurl.'?locspec=charrange:'.($offset)."/".($o+$inc).'&mode=endSelect2#end';
				$c ='<a class="'.$class.'" href="'.$url.'">'.$c.'</a>';
			}
			if( $mode eq 'endSelect2' && $o > $readlength-$BIGINC-1)
			{ 
				my $url = $baseurl.'?locspec=charrange:'.($offset)."/".($o+1).'&mode=link';
				$c ='<a class="'.$class.'" href="'.$url.'">'.$c.'</a>';
			}
			#if( $o > 0 && $mode eq "spanSelect" ) { $html.="|"; }
			$html.=$c;
			if( $o == $conend-1 )
			{
				$html.='</span>';
			}
		}
		$html.='</span>';
		my $copyurl = $repository->get_conf( "vlit" )->{copyright_url};
		my $front = '<a href="'.$copyurl.'">trans &copy;</a>';
		if( $param eq "" )
		{
			if( $mode eq "human" )
			{
				$front.= ' [<a href="'.$baseurl.'?mode=spanSelect">quote document</a>]';
			}
		}
		else
		{
			my $url = $baseurl;
			if( $mode eq "human" )
			{
				$front.= ' [<a href="'.$baseurl.'?xuversion=1.0&locspec=charrange:'.$param.'&mode=context">view context</a>]';
			}
			if( $mode eq "context" )
			{
				$front.= ' [<a href="'.$baseurl.'?xuversion=1.0&locspec=charrange:'.$param.'&mode=context2#c">context in full document</a>]';
			}
			if( $mode eq "context2" )
			{
				$front.= ' [<a href="'.$baseurl.'?xuversion=1.0&locspec=charrange:&mode=human">full document</a>]';
				$front.= ' [<a href="'.$baseurl.'?mode=spanSelect">quote document</a>]';
			}
		}
		$front.= ' [<a href="'.$baseurl.'?xuversion=1.0&locspec=charrange:'.$param.'">raw data</a>]';

		my $msg='';
		my $msg2='';
		if( $mode eq "endSelect2" )
		{ 
			$msg='<h1>select exact end point</h1>';
		}
		if( $mode eq "spanSelect2" )
		{ 
			$msg='<h1>select exact start point</h1>';
		}
		if( $mode eq "endSelect" )
		{ 
			$msg='<h1>select approximate end point</h1>';
		}
		if( $mode eq "spanSelect" )
		{ 
			$msg='<h1>select approximate start point</h1>';
		}
		$msg2=$msg; # only for span msgs
		
			
		
			
		send_http_header( "text/html" );
		my $title = "Transquotation from char $offset, length $length";
		if( $mode eq 'link' )
		{
			my $url = $baseurl.'?xuversion=1.0&locspec=charrange:'.($offset)."/".($length);
			my $urlh = $url.'&mode=human';
			my $urlx = $url.'&mode=xml-entity';
			$msg=<<END;
<div style="margin: 8px;">
<p><b>$title</b></p>
<p>Raw char quote: <a href="$url">$url</a></p>
<p>Human readable (HTML): <a href="$urlh">$urlh</a></p>
<p>XML: <a href="$urlx">$urlx</a></p>
END
			my $urlh2 = $urlh;
			$urlh2=~s/'/&squot;/g;
			$msg.=<<END;
<p>Cut and paste HTML for pop-up window:</p>
<div style="margin-left: 10px"><code>
&lt;a href="#" onclick="javascript:window.open( '$urlh2', 'transclude_window', 'width=666, height=444, scrollbars');"&gt;$title&lt;/a&gt;
</code></div>
</div>
END
		}
		my $cssurl = $repository->get_conf( "http_url" )."/style/vlit.css";
		$r->print( <<END );
<html>
<head>
  <title>$title</title>
  <link rel="stylesheet" type="text/css" href="$cssurl" title="screen stylesheet" media="screen" />
</head>
<body class="vlit">
$msg
<div class="vlit-controls">$front</div><div class="vlit-human">$html</div><a name="end" />
$msg2
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
#
# EPrints::Apache::VLit::ls_area( $file, $param, $resspec, $r, $baseurl, $args )
#
######################################################################

sub ls_area
{
	my( $file, $param, $resspec, $r, $baseurl , $args) = @_;

	my $page = 1;
	my $opts = {
		page => 1,
		hrange => { start=>0 },
		vrange => { start=>0 }
	};
	my $repository = EPrints->new->current_repository( $r );

	my $mode = $args->{mode};

	if( $mode eq "human" )
	{
		send_http_header( "text/html" );
		my $cssurl = $repository->get_conf( "http_url" )."/vlit.css";
		my $title = "title";
		my $html = "html";
		my $copyurl = $repository->get_conf( "vlit" )->{copyright_url};
		my $front = '<a href="'.$copyurl.'">trans &copy;</a>';
		my $fullurl = $baseurl.'?xuversion=1.0&locspec=area:&mode=human';
		my $imgurl = $baseurl.'?xuversion=1.0&locspec=area:'.$param;
		my $linkurl = $imgurl;
		if( $param ne '' )
		{
			$linkurl = $fullurl;
			$front.= ' [<a href="'.$fullurl.'">full document</a>]';
		}
		$front.= ' [<a href="'.$imgurl.'">raw data</a>]';
		$r->print( <<END );
<html>
<head>
  <title>$title</title>
  <link rel="stylesheet" type="text/css" href="$cssurl" title="screen stylesheet" media="screen" />
</head>
<body class="vlit">
<div class="vlit-controls">$front</div><div class="vlit-human"><a href='$linkurl'><img src='$imgurl' border="0" /></a></div><a name="end" />
</body>
</html>
END
		return;
	}

	my $s;
	if( $args->{scale} )
	{
		$s = $args->{scale};
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
		if( !-d $dir )
		{
			EPrints::Platform::mkdir( $dir );
			my $convert = $repository->get_conf( 'executables','convert' );
			my $cmd = "$convert '$file' 'tif:$dir/%d'";
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

	my $convert = $repository->get_conf( 'executables','convert' );
	$cmd = "$convert $scale $crop $scale2 '$dir/$pageindex' 'png:$cache'";
	`$cmd`;
	

	send_http_header( "image/png" );
	$cmd = "cat $cache";
	print `$cmd`;
}




######################################################################
#
# EPrints::Apache::VLit::cache_file( $resspec, $param )
#
######################################################################

sub cache_file
{
	my( $resspec, $param ) = @_;

	$param = "null" if( $param eq "" );

	$resspec =~ s/[^a-z0-9]/sprintf('_%02X',ord($&))/ieg;
	$param =~ s/[^a-z0-9]/sprintf('_%02X',ord($&))/ieg;

	EPrints::Platform::mkdir( $TMPDIR ) if( !-d $TMPDIR );

	my $dir = $TMPDIR."/".$resspec;
	
	EPrints::Platform::mkdir( $dir ) if( !-d $dir );

	return $dir."/".$param;
}


1;

######################################################################
=pod

=back

=cut


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

