package TeX::Encode;

use 5.008;
use strict;

#use AutoLoader qw(AUTOLOAD);

use Encode::Encoding;
use Carp;

use TeX::Encode::charmap;
use TeX::Encode::BibTeX;

our @ISA = qw(Encode::Encoding);

our $VERSION = '1.2';

__PACKAGE__->Define(qw(LaTeX latex));

sub _bad_cp
{
	return sprintf("Unsupported character code point 0x%04x\n", ord($_[0]));
}

sub encode
{
	my( undef, $string, $check ) = @_;

	my $bad_cp = 0;

	# set up a "check" sub that will determine how we handle unsupported code
	# points
	$check = Encode::FB_DEFAULT if !defined $check;
	if( $check eq Encode::FB_DEFAULT )
	{
		$check = sub { '?' };
	}
	elsif( $check eq Encode::FB_CROAK )
	{
		$check = sub { Carp::croak(&_bad_cp(@_)) };
	}
	elsif( $check eq Encode::FB_QUIET )
	{
		$check = sub { $bad_cp = 1; '' };
	}
	elsif( $check eq Encode::FB_WARN )
	{
		$check = sub { Carp::carp(&_bad_cp(@_)); $bad_cp = 1; '' };
	}
	else
	{
		Carp::confess( "Unknown check argument: expected one of undef, FB_DEFAULT, FB_CROAK, FB_QUIET or FB_WARN" );
	}

	my $tex = "";

	pos($string) = 0;

	for($string)
	{
		while(!$bad_cp) {
		last if pos($_) == length($_);

		# escape reserved characters
		/\G($TeX::Encode::charmap::RESERVED_RE)/gc and ($tex .= $TeX::Encode::charmap::RESERVED{$1}, next);

		# escape all characters supported by tex
		if( /\G($TeX::Encode::charmap::CHAR_MAP_RE)/gc )
		{
			$tex .= $TeX::Encode::charmap::CHAR_MAP{$1};
			if( /\G[a-zA-Z_]/gc )
			{
				--pos($_);
				$tex =~ /[a-zA-Z_]$/ and $tex .= '{}';
			}
			next;
		}

		# basic unreserved characters
		/\G([\sa-zA-Z0-9\.,:;'"\(\)=\/]+)/gc and ($tex .= $1, next);

		# unsupported code point (may set $bad_cp)
		/\G(.)/gc and ($tex .= &$check(ord($1)), next);

		Carp::confess "Shouldn't happen";
		}
	}

	if( $bad_cp )
	{
		$_[1] = substr($string,pos($string)-1);
	}

	return $tex;
}

# decode($octets [,$check])
sub decode
{
	my( undef, $tex, $check ) = @_;

	pos($tex) = 0;

	my $str = "";

	while(pos($tex) < length($tex))
	{
		$str .= _decode( $tex, $check );
	}

	return $str;
}

sub _decode
{
	my $str = Encode::decode_utf8( "" );

	for($_[0])
	{
		/\G\%([^\n]+\n)?/gc and next; # comment
# not sure about this:
#		/\G\\ensuremath/gc and ($str .= _decode_mathmode(_decode_bracket($_)), next); # mathmode
		/\G\$/gc and ($str .= _decode_mathmode($_), next); # mathmode
		/\G($TeX::Encode::charmap::MACROS_RE)/gc and ($str .= $TeX::Encode::charmap::MACROS{$1}, next); # macro
		/\G\\(.)/gc and ($str .= _decode_macro($1,$_), next); # unknown macro
		/\G\{/gc and ($str .= _decode_brace($_), next); # {foo}
		/\G\[/gc and ($str .= _decode_bracket($_), next); # [foo]
		/\G_/gc and ($str .= _subscript(&_decode), next); # _ (subscript)
		/\G\^/gc and ($str .= _superscript(&_decode), next); # ^ (superscript)
		/\G([^_\^\%\$\\\{\[ \t\n\r]+)/gc and $str .= $1, next;
		/\G([ \t\n\r])+/gc and $str .= $1, next;

		Carp::confess "Shouldn't happen: ".substr($_,0,10)." ...".substr($_,pos($_),10)." [".pos($_)."/".length($_)."]";
	}

	return $str;
}

sub _subscript
{
	my( $tex ) = @_;
	return $tex if $tex =~ /[^0-9+\-]/;
	return _subscript_digits( $tex );
}

sub _superscript
{
	my( $tex ) = @_;
	return $tex if $tex =~ /[^0-9+\-]/;
	return _superscript_digits( $tex );
}

my %SUBSCRIPTS = (
	'+' => chr(0x208a),
	'-' => chr(0x208b),
);
$SUBSCRIPTS{''.$_} = chr(0x2080+$_) for 0..9;
sub _subscript_digits
{
	my( $tex ) = @_;
	$tex =~ s/(.)/$SUBSCRIPTS{$1}/g;
	return $tex;
}

my %SUPERSCRIPTS = (
	'0' => chr(0x2070),
	'1' => chr(0xb9),
	'2' => chr(0xb2),
	'3' => chr(0xb3),
	'4' => chr(0x2074),
	'5' => chr(0x2075),
	'6' => chr(0x2076),
	'7' => chr(0x2077),
	'8' => chr(0x2078),
	'9' => chr(0x2079),
	'+' => chr(0x207a),
	'-' => chr(0x207b),
);
sub _superscript_digits
{
	my( $tex ) = @_;
	$tex =~ s/(.)/$SUPERSCRIPTS{$1}/g;
	return $tex;
}

sub perlio_ok { 0 }

sub _decode_mathmode
{
	my $str = "";

	for($_[0])
	{
		while(1) {
		last if pos($_) == length($_);
	
		/\G(\\.)/gc and ($str .= $1, next);
		/\G\$/gc and last;
		/\G($TeX::Encode::charmap::MATH_CHARS_RE)/gc and ($str .= $TeX::Encode::charmap::MATH_CHARS{$1}, next);
		/\G([^\\\$]+)/gc and ($str .= $1, next);

		Carp::confess "Shouldn't happen";
		}
	}

	return decode(undef, $str);
}

# try again to expand a macro
sub _decode_macro
{
	my( $c ) = @_;

	my $str = "\\$c";

	for($_[1])
	{
		# expand \'{e} to \'e
		/\G\{/ and ($str .= _decode_brace( $_ ), next);
		last;
	}

	return $TeX::Encode::charmap::MACROS{$str} || $str;
}

sub _decode_bracket
{
	my $str = "";

	my $depth = 1;
	for($_[0])
	{
		while(1) {
		last if pos($_) == length($_) or $depth == 0;

		/\G(\\.)/gc and ($str .= $1, next);
		/\G\[/gc and (--$depth, next);
		/\G\]/gc and (++$depth, next); 
		/\G([^\\\[\]]+)/gc and ($str .= $1, next);

		Carp::confess "Shouldn't happen";
		}
	}

	return $str;
}

sub _decode_brace
{
	my $str = "";

	my $depth = 1;
	for($_[0])
	{
		while(1) {
		last if pos($_) == length($_) or $depth == 0;

		/\G(\\.)/gc and ($str .= $1, next);
		/\G\}/gc and ($str .= '}', --$depth, next);
		/\G\{/gc and ($str .= '{', ++$depth, next); 
		/\G([^\\\{\}]+)/gc and ($str .= $1, next);

		Carp::confess "Shouldn't happen";
		}
	}

	chop($str); # remove trailing '}'

	return decode(undef, $str);
}

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

=head1 METHODS

=over 4

=item TeX::Encode::encode STRING [, CHECK]

Encodes a utf8 string into TeX. CHECK isn't implemented.

=item TeX::Encode::decode STRING [, CHECK]

Decodes a TeX string into utf8. CHECK isn't implemented.

=item TeX::Encode::perlio_ok

Returns 0. PerlIO isn't implemented.

=back

=head1 CAVEATS

Proper Encode checking is not implemented.

LaTeX comments (% ...) are ignored because chopping a lot of text may not be what you actually want.

=head2 encode()

Converts non-ASCII Unicode characters to their equivalent TeX symbols (unTeXable characters will result in undef warnings).

=head2 decode()

Attempts to convert TeX symbols (e.g. \ae) to Unicode characters. As an experimental feature this also handles Math-mode TeX by inserting HTML into the resulting string (so you end up with an HTML approximation of the maths - NOT MathML).

=head1 SEE ALSO

L<Encode::Encoding>, L<Pod::LaTeX>, L<Encode>

=head1 AUTHOR

Timothy D Brody, E<lt>tdb01r@ecs.soton.ac.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-2007 by Timothy D Brody

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
