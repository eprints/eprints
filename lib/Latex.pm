
package EPrints::Latex;

use EPrints::Session;

use Digest::MD5;
use strict;


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
			$param =~ s/^\$(.*)\$$/$1/; # strip $ from begining and end.
			my $perlurl = $session->get_archive()->get_conf( "perl_url" );
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
	$html->appendChild( $session->make_text( $buffer ) );

	return $html;
}

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
	chdir( $cachedir );

	$ofile = $cachedir."/".$ofile;

	if( -e $ofile ) 
	{
		return $ofile;
	}
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
	$archive->exec( "convert_crop_white", SOURCE=>"$fbase.ps", TARGET=>$ofile );
	unlink( "$fbase.aux", "$fbase.dvi", "$fbase.tex", "$fbase.ps", "$fbase.log" );

	return $ofile;
}


1;
