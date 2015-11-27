######################################################################
#
# EPrints::Latex
#
######################################################################
#
#
######################################################################


=pod

=head1 NAME

B<EPrints::Latex> - Module for handling rendering latex equations in 
metadata as images.

=head1 DESCRIPTION

Some repositories may want to spot latex style equations in titles and
abstracts and render these as images instead. This module provides
that functionality.

=over 4

=cut

######################################################################

package EPrints::Latex;

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
			my $url;

			if( $session->config( "use_mimetex" ) ) 
			{
				my $param = $buffer;

				# strip $ from beginning and end.
				$param =~ s/^\$(.*)\$$/$1/;

				# Mimetex can't handle whitespace. Change it to ~'s.
				$param =~ s/\\?\s/~/g;     

				$url = $session->config( 
        				"http_cgiurl" )."/mimetex.cgi?".$param;
			}
			else
			{
				my $param = $buffer;
	
				# URL Encode non a-z 0-9 chars.
				$param =~ s/[^a-z0-9]/sprintf('%%%02X',ord($&))/ieg;
	
				# strip $ from beginning and end.
				$param =~ s/^\$(.*)\$$/$1/; 
	
				$url = $session->config( 
					"http_cgiurl" )."/latex2png?latex=".$param;
			}

			my $img = $session->make_element( 
				"img",
				align=>"absbottom",
				alt=>$buffer,
				src=>$url,
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
directory is "latexcache" in the htdocs directory of the repository.

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

	my $repository =  $session->get_repository;

	my $cachedir = $repository->get_conf( "htdocs_path" )."/latexcache";

	unless( -d $cachedir )
	{
		EPrints::Platform::mkdir( $cachedir);
	}

	# Make sure latex .aux & .log files go in this dir.

	$ofile = $cachedir."/".$ofile;

	if( -e $ofile ) 
	{
		return $ofile;
	}

	my $prev_dir = getcwd;
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

	$repository->exec( "latex", SOURCE=>"$fbase.tex" );
	$repository->exec( "dvips", SOURCE=>"$fbase.dvi", TARGET=>"$fbase.ps" );
	$repository->exec( 
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

