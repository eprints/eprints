######################################################################
#
# EPrints::Index::Tokenizer
#
######################################################################
#
#
######################################################################


=pod

=head1 NAME

B<EPrints::Index::Tokenizer> - text indexing utility methods

=head1 DESCRIPTION

This module provides utility methods for processing free text into indexable things.

=head1 METHODS

=over 4

=cut

package EPrints::Index::Tokenizer;

######################################################################
=pod

=item @words = EPrints::Index::Tokenizer::split_words( $session, $utext )

Splits a utf8 string into individual words. 

=cut
######################################################################

sub split_words
{
	my( $session, $utext ) = @_;

	if( ref($utext) eq "Unicode::String" )
	{
		$utext = "$utext";
	}
	else
	{
		utf8::encode($utext);
	}
	# fix malformed UTF-8 data
	$utext = Encode::decode("UTF-8", $utext, Encode::FB_DEFAULT);

	return split /[^\w']+/, $utext;
}

=item @terms = EPrints::Index::Tokenizer::split_search_value( $session, $value )

Splits and returns $value into search terms.

=cut

sub split_search_value
{
	my( $session, $value ) = @_;

	# transliterate to English
	$value = apply_mapping( $session, $value );

	return split /[^\w'\*]+/, $value;
}

######################################################################
=pod

=item $utext2 = EPrints::Index::Tokenizer::apply_mapping( $session, $utext )

Replaces certain unicode characters with ASCII equivalents and returns
the new string.

This is used before indexing words so that things like umlauts will
be ignored when searching.

=cut
######################################################################

sub apply_mapping
{
	my( $session, $text ) = @_;

	if( ref($utext) eq "Unicode::String" )
	{
		$utext = "$utext";
		utf8::decode($utext);
	}

	return join("", map {
		exists($EPrints::Index::FREETEXT_CHAR_MAPPING->{$_}) ?
		$EPrints::Index::FREETEXT_CHAR_MAPPING->{$_} :
		$_;
	} split(//, $text));
}

##############################################################################
# Mappings and character tables
##############################################################################

# This map is used to convert Unicode characters
# to ASCII characters below 127, in the word index.
# This means that the word Fête is indexed as 'fete' and
# "fete" or "fête" will match it.
# There's no reason mappings have to be a single character.

$EPrints::Index::FREETEXT_CHAR_MAPPING = {
		chr(0x0027) => "'",      # '
		chr(0x00a1) => '!',     # ¡
		chr(0x00a2) => 'c',     # ¢
		chr(0x00a3) => 'L',     # £
		chr(0x00a4) => 'o',     # ¤
		chr(0x00a5) => 'Y',     # ¥
		chr(0x00a6) => '|',     # ¦
		chr(0x00a7) => 'S',     # §
		chr(0x00a8) => '"',     # ¨
		chr(0x00a9) => '(c)',   # ©
		chr(0x00aa) => 'a',     # ª
		chr(0x00ab) => '<<',    # «
		chr(0x00ac) => '-',     # ¬
		chr(0x00ad) => '-',     # ­
		chr(0x00ae) => '(R)',   # ®
		chr(0x00af) => '-',     # ¯
		chr(0x00b0) => 'o',     # °
		chr(0x00b1) => '+-',    # ±
		chr(0x00b2) => '2',     # ²
		chr(0x00b3) => '3',     # ³
		chr(0x00b5) => 'u',     # µ
		chr(0x00b6) => 'q',     # ¶
		chr(0x00b7) => '.',     # ·
		chr(0x00b8) => ',',     # ¸
		chr(0x00b9) => '1',     # ¹
		chr(0x00ba) => 'o',     # º
		chr(0x00bb) => '>>',    # »
		chr(0x00bc) => '1/4',   # ¼
		chr(0x00bd) => '1/2',   # ½
		chr(0x00be) => '3/4',   # ¾
		chr(0x00bf) => '?',     # ¿
		chr(0x00c0) => 'A',     # À
		chr(0x00c1) => 'A',     # Á
		chr(0x00c2) => 'A',     # Â
		chr(0x00c3) => 'A',     # Ã
		chr(0x00c4) => 'Ae',     # Ä
		chr(0x00c6) => 'AE',    # Æ
		chr(0x00c7) => 'C',     # Ç
		chr(0x00c8) => 'E',     # È
		chr(0x00c9) => 'E',     # É
		chr(0x00ca) => 'E',     # Ê
		chr(0x00cb) => 'E',     # Ë
		chr(0x00cc) => 'I',     # Ì
		chr(0x00cd) => 'I',     # Í
		chr(0x00ce) => 'I',     # Î
		chr(0x00cf) => 'I',     # Ï
		chr(0x00d0) => 'D',     # Ð
		chr(0x00d1) => 'N',     # Ñ
		chr(0x00d2) => 'O',     # Ò
		chr(0x00d3) => 'O',     # Ó
		chr(0x00d4) => 'O',     # Ô
		chr(0x00d5) => 'O',     # Õ
		chr(0x00d6) => 'Oe',     # Ö
		chr(0x00d7) => 'x',     # ×
		chr(0x00d8) => 'O',     # Ø
		chr(0x00d9) => 'U',     # Ù
		chr(0x00da) => 'U',     # Ú
		chr(0x00db) => 'U',     # Û
		chr(0x00dc) => 'Ue',     # Ü
		chr(0x00dd) => 'Y',     # Ý
		chr(0x00de) => 'TH',    # Þ
		chr(0x00df) => 'ss',     # ß
		chr(0x00e0) => 'a',     # à
		chr(0x00e1) => 'a',     # á
		chr(0x00e2) => 'a',     # â
		chr(0x00e3) => 'a',     # ã
		chr(0x00e4) => 'ae',     # ä
		chr(0x00e5) => 'a',     # å
		chr(0x00e6) => 'ae',    # æ
		chr(0x00e7) => 'c',     # ç
		chr(0x00e8) => 'e',     # è
		chr(0x00e9) => 'e',     # é
		chr(0x00ea) => 'e',     # ê
		chr(0x00eb) => 'e',     # ë
		chr(0x00ec) => 'i',     # ì
		chr(0x00ed) => 'i',     # í
		chr(0x00ee) => 'i',     # î
		chr(0x00ef) => 'i',     # ï
		chr(0x00f0) => 'd',     # ð
		chr(0x00f1) => 'n',     # ñ
		chr(0x00f2) => 'o',     # ò
		chr(0x00f3) => 'o',     # ó
		chr(0x00f4) => 'o',     # ô
		chr(0x00f5) => 'o',     # õ
		chr(0x00f6) => 'oe',     # ö
		chr(0x00f7) => '/',     # ÷
		chr(0x00f8) => 'oe',     # ø
		chr(0x00f9) => 'u',     # ù
		chr(0x00fa) => 'u',     # ú
		chr(0x00fb) => 'u',     # û
		chr(0x00fc) => 'ue',     # ü
		chr(0x00fd) => 'y',     # ý
		chr(0x00fe) => 'th',    # þ
		chr(0x00ff) => 'y',     # ÿ
		chr(0x0150) => 'o',     # ~O
		chr(0x0170) => 'u',     # ~U
		chr(0x0171) => 'u',     # ~u
};

# Minimum size word to normally index.
$EPrints::Index::FREETEXT_MIN_WORD_SIZE = 3;

# We use a hash rather than an array for good and bad
# words as we only use these to lookup if words are in
# them or not. If we used arrays and we had lots of words
# it might slow things down.

# Words to never index, despite their length.
$EPrints::Index::FREETEXT_STOP_WORDS = {
	"this"=>1,	"are"=>1,	"which"=>1,	"with"=>1,
	"that"=>1,	"can"=>1,	"from"=>1,	"these"=>1,
	"those"=>1,	"the"=>1,	"you"=>1,	"for"=>1,
	"been"=>1,	"have"=>1,	"were"=>1,	"what"=>1,
	"where"=>1,	"is"=>1,	"and"=>1, 	"fnord"=>1
};

# Words to always index, despite their length.
$EPrints::Index::FREETEXT_ALWAYS_WORDS = {
		"ok" => 1 
};

# Chars which separate words. Pretty much anything except
# A-Z a-z 0-9 and single quote '

# If you want to add other seperator characters then they
# should be encoded in utf8. The Unicode::String man page
# details some useful methods.

$EPrints::Index::FREETEXT_SEPERATOR_CHARS = {
	'@' => 1, 	'[' => 1, 	'\\' => 1, 	']' => 1,
	'^' => 1, 	'_' => 1,	' ' => 1, 	'`' => 1,
	'!' => 1, 	'"' => 1, 	'#' => 1, 	'$' => 1,
	'%' => 1, 	'&' => 1, 	'(' => 1, 	')' => 1,
	'*' => 1, 	'+' => 1, 	',' => 1, 	'-' => 1,
	'.' => 1, 	'/' => 1, 	':' => 1, 	';' => 1,
	'{' => 1, 	'<' => 1, 	'|' => 1, 	'=' => 1,
	'}' => 1, 	'>' => 1, 	'~' => 1, 	'?' => 1,
	chr(0xb4) => 1, # Acute Accent (closing quote)
};
$EPrints::Index::FREETEXT_SEPERATOR_REGEXP = quotemeta(join "", keys %$EPrints::Index::FREETEXT_SEPERATOR_CHARS);
$EPrints::Index::FREETEXT_SEPERATOR_REGEXP = qr/[$EPrints::Index::FREETEXT_SEPERATOR_REGEXP\x00-\x20]/;

# Compatibility with Unicode::String keys
foreach my $mapping (
	$EPrints::Index::FREETEXT_CHAR_MAPPING,
	$EPrints::Index::FREETEXT_SEPERATOR_CHARS
)
{
	foreach my $char (keys %$mapping)
	{
		my $bytes = $char;
		utf8::encode($bytes);
		$mapping->{$bytes} = $mapping->{$char};
	}
}

1;

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

