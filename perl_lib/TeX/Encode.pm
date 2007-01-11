package TeX::Encode;

use 5.008;
use strict;
use warnings;

use AutoLoader qw(AUTOLOAD);

use Encode::Encoding;
use Pod::LaTeX;
use HTML::Entities;
use Carp;

our @ISA = qw(Encode::Encoding);

our $VERSION = '0.6';

use constant ENCODE_CHRS => '<>&"';

__PACKAGE__->Define(qw(LaTeX BibTeX latex bibtex));

use vars qw( %LATEX_Escapes %LATEX_Escapes_inv %LATEX_Math_mode $LATEX_Math_mode_re );

# Missing entities in HTML::Entities?
@HTML::Entities::entity2char{qw(sol verbar)} = qw(\textfractionsolidus{} |);

# Use the mapping from Pod::LaTeX, but we use HTML::Entities
# to get the Unicode character
while( my ($entity,$tex) = each %Pod::LaTeX::HTML_Escapes ) {
	# HTML::Entities changed entity2char somewhere between 1.27 and 1.35: in 1.35
	# there are semi-colons on all the keys in the $] > 5.007 group (#260)
	# Regardless, using the public method is probably better karma
	my $c = decode_entities( sprintf( "&%s;", $entity ));
	
	# 1.27 used UTF-8 in the source, which requires decoding
	utf8::decode($c) if $HTML::Entities::VERSION < 1.35;
	
	$LATEX_Escapes{$c} = $tex;
	if( $tex =~ s/^\$\\(.+)\$/$1/ ) {
		$LATEX_Math_mode{$tex} = $c;
#		warn "MM: ", quotemeta($tex), " => ", $c, "\n";
	} elsif( $tex =~ s/^\\// ) {
		$LATEX_Escapes_inv{quotemeta($tex)} = $c;
#		warn quotemeta($tex), " => ", $c, "\n";
	}
}

### Additional Supported Characters ###

{
	# Greek letters
	my $i = 0;
	for(qw( alpha beta gamma delta epsilon zeta eta theta iota kappa lamda mu nu xi omicron pi rho final_sigma sigma tau upsilon phi chi psi omega )) {
		$LATEX_Escapes{$LATEX_Escapes_inv{$_} = chr(0x3b1+$i)} = "\\$_";
		$LATEX_Escapes{$LATEX_Escapes_inv{"\u$_"} = chr(0x391+$i)} = "\\\u$_";
		$i++;
	}
	# Spelling mistake in LaTeX/charmap?
	$LATEX_Escapes{
		$LATEX_Escapes_inv{'lambda'} = $LATEX_Escapes_inv{'lamda'}
	} = "\\lambda";	
	$LATEX_Escapes{
		$LATEX_Escapes_inv{'Lambda'} = $LATEX_Escapes_inv{'Lamda'}
	} = "\\Lambda";
}

# Math-mode sequences
%LATEX_Math_mode = (
	%LATEX_Math_mode,
	'AA' => chr(0xc5), # &aring; Angstrom
	'sin' => 'sin', # sin (should be romanised), other trigonometric functions???
	'to' => chr(0x2192), # -->
	'leftarrow' => chr(0x2190), # <--
	'rightarrow' => chr(0x2192), # -->
	'approx' => chr(0x2248), # &asymp; Approximately equal to
	'lesssim' => chr(0x2272), # May not exist!
	'gtrsim' => chr(0x2273), # May not exist!
	'simeq' => chr(0x2243),
	'leq' => chr(0x2264),
	'pm' => chr(0xb1), # &plusmn; Plus-minus
	'times' => chr(0xd7), # &times; Times
	'odot' => chr(0x2299), # odot
	'int' => chr(0x222b), # integral
	# Sets, http://www.unicode.org/charts/PDF/Unicode-4.1/U41-2100.pdf
	'N' => chr(0x2115),
	'R' => chr(0x211d),
	'Z' => chr(0x2124),
);
foreach my $re (sort { length($b) <=> length($a) } keys %LATEX_Math_mode) {
	$LATEX_Math_mode_re .= quotemeta($re).'|';
}
chop($LATEX_Math_mode_re);
# TODO
# e.g. \acute{e} => \'e
# Math-mode accents: hat, acute, bar, dot, breve, check, grave, vec, ddot, tilde

# encode($string [,$check])
sub encode
{
	use utf8;
	my ($self,$str,$check) = @_;
	$str =~ s/([^\x00-\x80])/$LATEX_Escapes{$1}/sg;
	return $str;
}
# decode($octets [,$check])
sub decode
{
	my ($self,$str,$check) = @_;
	# Convert standard macros to chars
	while( my ($re,$char) = each %LATEX_Escapes_inv ) {
		$str =~ s/\\$re/$char/sg;
	}
	# Additionally convert mathmode macros to unicode
	$str =~ s/\$([^\$]+?)\$/&_mathmode($1)/seg;
	
	# $str = encode_entities($str,'<>&"');
	# Convert some LaTeX macros into HTML equivalents
	return _htmlise(\$str);
}
# Math-mode symbols
sub _mathmode
{
	my $str = shift;
	$str =~ s/\\($LATEX_Math_mode_re)/$LATEX_Math_mode{$1}/sog;
	$str;
}

# Superscript/subscript
# sqrt
# Overline for /bar
# LaTeX
sub _htmlise
{
	my $str = shift;
	my $out = '';
	while(length($$str) > 0) {
		if( $$str =~ s/^\^// ) {
			$out .= '<sup>' . _atom($str) . '</sup>';
		} elsif( $$str =~ s/^_// ) {
			$out .= '<sub>' . _atom($str) . '</sub>';
		} elsif( $$str =~ s/^\\sqrt/\\bar/ ) {
			$out .= chr(0x221a);
		} elsif( $$str =~ s/^\\frac// ) {
			$out .= "<sup style='text-decoration: underline'>" . _atom($str) . '</sup>';
			$$str =~ s/^\s*//;
			$out .= "<sub>" . _atom($str) . '</sub>';
		} elsif( $$str =~ s/^\\(?:bar|overline)// ) {
			$out .= "<span style='text-decoration: overline'>" . _atom($str) . "</span>";
		} elsif( $$str =~ s/^LaTeX// ) {
			$out .= "L<sup>A<\/sup>T<small>E<\/small>X";
		} elsif( $$str =~ s/^([^\^_\\\{]+)// ) {
			$out .= encode_entities($1,ENCODE_CHRS);
		} else {
			$out .= _atom($str);
		}
	}
	return $out;
}

sub _atom
{
	my $str = shift;
	if( $$str =~ s/^\{\\(cal|rm)(?:[^\w])/\{/ ) {
		return "<span style='" . ($1 eq 'cal' ? 'font-style: italic' : 'font-family: serif') . "'>" . _atom($str) . "</span>";
	} elsif( $$str =~ s/^\\\\// ) { # Newline
		return "<br />";
	} elsif( $$str =~ s/^\\(.)// ) { # Escaped character
		return $1;
	} elsif( $$str =~ s/^\{([^\}]+)\}// ) {
		my $sstr = $1;
		return _htmlise(\$sstr);
	} elsif( $$str =~ s/^\{// ) {
		# Find the closing tag
		my $i = 1;
		pos($$str) = 0;
		while( $i > 0 && pos($$str) < (length($$str)-1) ) {
			if( $$str =~ /^[^\}]*\{/cg ) {
				$i++;
			} elsif( $$str =~ /^[^\{]*\}/cg ) {
				$i--;
			} else {
				last;
			}
		}
		my $sstr = substr($$str,0,pos($$str));
		$$str = substr($$str,pos($$str));
		return _htmlise(\$sstr);
	} elsif( $$str =~ s/^(.)// ) {
		return encode_entities($1,ENCODE_CHRS);
	}
	return '';
}

sub perlio_ok { 0 }

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

TeX::Encode - Encode/decode Perl utf-8 strings into TeX

=head1 SYNOPSIS

  use TeX::Encode;
  use Encode;

  $tex = encode('latex', "This will encode an e-acute (".chr(0xe9).") as \'e");
  $str = decode('latex', $tex); # Will decode the \'e too!

=head1 DESCRIPTION

This module provides encoding to LaTeX escapes from utf8 using mapping tables in L<Pod::LaTeX> and L<HTML::Entities>. This covers only a subset of the Unicode character table (undef warnings will occur for non-mapped chars). This module is intentionally vague about what it will handle, see Caveats below.

Mileage will vary when decoding (converting TeX to utf8), as TeX is in essence a programming language, and this module does not implement TeX.

I use this module to encode author names in BibTeX and to do a rough job at presenting LaTeX abstracts in HTML. Using decode rather than seeing $\sqrt{\Omega^2\zeta_n}$ you get something that looks like the formula.

The next logical step for this module is to integrate some level of TeX grammar to improve the decoding, in particular to handle fractions and font changes (which should probably be dropped).

=head1 CAVEATS

Proper Encode checking is not implemented.

LaTeX comments (% ...) are ignored because chopping a lot of text may not be what you actually want.

=head2 encode()

Converts non-ASCII Unicode characters to their equivalent TeX symbols (unTeXable characters will result in undef warnings).

=head2 decode()

Attempts to convert TeX symbols (e.g. \ae) to Unicode characters. As an experimental feature this also handles Math-mode TeX by inserting HTML into the resulting string (so you end up with an HTML approximation of the maths - NOT MathML).

=head1 SEE ALSO

L<Pod::LaTeX>

=head1 AUTHOR

Timothy D Brody, E<lt>tdb01r@ecs.soton.ac.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-2006 by Timothy D Brody

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
