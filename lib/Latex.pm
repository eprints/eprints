######################################################################
#
# EPrints::Latex
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

B<EPrints::Latex> - Module for handling rendering latex equations in 
metadata as images.

=head1 DESCRIPTION

Some archives may want to spot latex style equations in titles and
abstracts and render these as images instead. This module provides
that functionality.

=over 4

=cut

######################################################################

package EPrints::Latex;

use EPrints::Session;

use Digest::MD5;
use Cwd;
use strict;

######################################################################
=pod

=item $xhtml = EPrints::Latex::render_string( $session, $field, $value )

This function is intended to be passed by reference to the 
render_single_value property of a metadata field. It returns just
an XHTML DOM string unless it spots anything which looks like a 
latex style equation, if so the equation is replaced with and img
element, the URL of which is a CGI script which will render the equation
as an image. 

For example the equation 

 $x = \frac{-b_+_^-^\root{b^2^-4ac}}{2a}$ 

is the quadratic equation. If you're not a physics academic then that 
probably dosn't mean much to you, but that's how the physics community 
like to write their equations!

=cut
######################################################################

sub render_string
{
	my( $session , $field , $value ) = @_;
	
	my $i=0;
	my $mode = 0;
	my $html = $session->make_doc_fragment();
	my $buffer = '';

	my $inslash = 0;
	my $inmath = 0;
	my $inlatex = 0;
	my $oldinlatex = 0;

	$value .=' '; # easy way to force end of (simple) latex mode.

	while($i<length($value))
	{
		my $c= substr($value,$i,1);

		if( $inslash == 2 )
		{
			if( $c!~m/^[a-z]$/i)
			{
				$inslash = 0;
			}
		}

		if( $inslash == 0 )
		{
			if( $c eq "\\" )
			{
				$inslash = 1;
			}
			if( $c eq "{" )
			{
				++$mode;
			}
			if( ($inmath==0) && ($c eq '$') )
			{
				$inmath = 1;
			}
		}	 

		elsif( $inslash == 1 )
		{
			if( $c=~m/^[a-z]$/i)
			{
				$inslash = 2;
			}
			else
			{
				$inslash = 3;
			}
		}
		
		$oldinlatex = $inlatex;	
		$inlatex = ( $mode>0 || $inslash>0 || $inmath>0 );
	
		if( !$inlatex && $oldinlatex )
		{
			my $param = $buffer;
			$param =~ s/[^a-z0-9]/sprintf('%%%02X',ord($&))/ieg;

			# strip $ from begining and end.
			$param =~ s/^\$(.*)\$$/$1/; 

			my $perlurl = $session->get_archive()->get_conf( 
				"perl_url" );
			my $img = $session->make_element( 
				"img",
				align=>"absbottom",
				alt=>$buffer,
				src=>$perlurl."/latex2png?latex=".$param,
				border=>0 );
			$html->appendChild( $img );
			$buffer = '';	
		}

		if ($inlatex && !$oldinlatex )
		{
			$html->appendChild( $session->make_text( $buffer ) );
			$buffer = '';
		}
		if( !$inlatex && $c eq "\n" )
		{
			$html->appendChild( $session->make_text( $buffer ) );
			$html->appendChild( $session->make_element( "br" ) );
			$buffer = '';
		}
		else
		{
			$buffer.=$c;
		}
		
		if( $inslash == 0 )
		{
			if( $inmath==2 && ($c eq '$') )
			{
				$inmath = 0;
			}
			if( $inmath==1 )
			{
				$inmath = 2;
			}
			if( $c eq "}" )
			{
				--$mode;
			}
		}
		if( $inslash == 3 )
		{
			$inslash = 0;
		}
		++$i;
	}
	if( $mode )
	{
		$buffer.=" [brace not closed]";
	}
	if( $inmath )
	{
		$buffer.=" [math mode missing closing \$]";
	}
	$buffer =~ s/\s*$//;
	$html->appendChild( $session->make_text( $buffer ) );

	return $html;
}


######################################################################
=pod

=item $imgfile = EPrints::Latex::texstring_to_png( $session, $texstring )

Return the location of a PNG image file containing the latex fragment
$texstring. 

This uses a directory to generate and cache the images. So the system
only has to go to the effort of rendering any equation once. The 
directory is "latexcache" in the htdocs directory of the archive.

The filename of the cached png is the md5 of the latex equation as
a string of hex characters. 

The images always have a white background. 

This uses the rather obvious system of creating a latex file with
$texstring in, running latex on it, running dvips on the resulting 
dvi file to get a postscript file of a page with the equation in the
corner. Then uses GNU convert crop the postscript and turn it into
a PNG.

=cut
######################################################################

sub texstring_to_png
{
	my( $session, $texstring ) = @_;

	# create an MD5 of the TexString to use as a cache filename.
	my $ofile = Digest::MD5::md5_hex( $texstring ).".png";

	my $archive =  $session->get_archive();

	my $cachedir = $archive->get_conf( "htdocs_path" )."/latexcache";

	unless( -d $cachedir )
	{
		EPrints::Utils::mkdir( $cachedir);
	}

	# Make sure latex .aux & .log files go in this dir.

	$ofile = $cachedir."/".$ofile;

	if( -e $ofile ) 
	{
		return $ofile;
	}

	my $prev_dir = cwd;
	chdir( $cachedir );
	my $fbase = $cachedir."/".$$;

	open( TEX, ">$fbase.tex" );
	print TEX <<END;
\\scrollmode
\\documentclass{slides}
\\begin{document}
$texstring
\\end{document}
END
	close TEX;

	$archive->exec( "latex", SOURCE=>"$fbase.tex" );
	$archive->exec( "dvips", SOURCE=>"$fbase.dvi", TARGET=>"$fbase.ps" );
	$archive->exec( 
		"convert_crop_white", 
		SOURCE => "$fbase.ps", 
		TARGET => $ofile );
	unlink( 
		"$fbase.aux", 
		"$fbase.dvi", 
		"$fbase.tex", 
		"$fbase.ps", 
		"$fbase.log" );

	chdir( $prev_dir );
	return $ofile;
}


	
1;

######################################################################
=pod

=back

=cut

