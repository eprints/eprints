package TeX::Encode::BibTeX;

use 5.008;
use strict;

#use AutoLoader qw(AUTOLOAD);

use TeX::Encode;

our @ISA = qw(Encode::Encoding);

our $VERSION = '1.2';

__PACKAGE__->Define(qw(BibTeX bibtex));

# encode($self, $string [,$check])
sub encode
{
	my( undef, $string, $check ) = @_;

	my $tex = "";

	pos($string) = 0;

	for($string)
	{
		while(1) {
		last if pos($_) == length($_);

		/\G($TeX::Encode::charmap::BIBTEX_RESERVED_RE)/gc and ($tex .= $TeX::Encode::charmap::BIBTEX_RESERVED{$1}, next);

		# BibTeX requires extra braces around any LaTeX mark-up
		# (we assume anything we substitute with will be BibTeX-safe)
		/\G($TeX::Encode::charmap::CHAR_MAP_RE)/gc and ($tex .= '{'.$TeX::Encode::charmap::CHAR_MAP{$1}.'}', next);

		# basic unreserved characters
		/\G([\sa-zA-Z0-9\.,:;'"\(\)=\-\/\[\]\*\+]+)/gc and ($tex .= $1, next);
		/\G([\x00-\x7e])/gc and ($tex .= $1, next);

		/\G(.)/gc and ($tex .= '?', next);

		Carp::confess "Shouldn't happen";
		}
	}

	return $tex;
}

# encode_url($self, $string [,$check])
sub encode_url
{
	my( undef, $str, $check ) = @_;

	# replace braces/slash (URL???) and underscore with their URI escape points
	$str =~ s/([\{\}\\_])/sprintf("%%%02x",ord($1))/seg;
	$str =~ s/(%)/$TeX::Encode::charmap::BIBTEX_RESERVED{$1}/sg;

	return $str;
}

# decode($octets [,$check])
sub decode
{
	return &TeX::Encode::decode;
}

sub perlio_ok { 0 }

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

TeX::Encode::BibTeX - Encode/decode Perl utf-8 strings into BibTeX

=head1 SYNOPSIS

  use TeX::Encode;
  use Encode;

  $tex = encode('bibtex', "This will encode an e-acute (".chr(0xe9).") as \'e");
  $str = decode('bibtex', $tex); # Will decode the \'e too!

=head1 DESCRIPTION

This module provides encoding to LaTeX escapes from utf8 using mapping tables in L<Pod::LaTeX> and L<HTML::Entities>. This covers only a subset of the Unicode character table (undef warnings will occur for non-mapped chars). This module is intentionally vague about what it will handle, see Caveats below.

Mileage will vary when decoding (converting TeX to utf8), as TeX is in essence a programming language, and this module does not implement TeX.

I use this module to encode author names in BibTeX and to do a rough job at presenting LaTeX abstracts in HTML. Using decode rather than seeing $\sqrt{\Omega^2\zeta_n}$ you get something that looks like the formula.

The next logical step for this module is to integrate some level of TeX grammar to improve the decoding, in particular to handle fractions and font changes (which should probably be dropped).

=head1 METHODS

=over 4

=item TeX::Encode::BibTeX::encode STRING [, CHECK]

Encodes a utf8 string into TeX. CHECK isn't implemented.

=item TeX::Encode::BibTeX::encode_url STRING

Make a URL safe for inclusion in BibTeX.

=item TeX::Encode::BibTeX::decode STRING [, CHECK]

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
