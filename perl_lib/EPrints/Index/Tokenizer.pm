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

use Unicode::Normalize qw( normalize );

## Returns a basic Perl string containing normalized UTF-8 bytes
sub _cast_string
{
	my( $utext ) = @_;

	# ensure it's a UTF-8 Perl string
	if( ref($utext) eq "Unicode::String" )
	{
		$utext = $utext->utf8;
	}
	else
	{
		utf8::encode($utext);
	}

	# fix malformed UTF-8 data
	$utext = Encode::decode("UTF-8", $utext, Encode::FB_DEFAULT);

	# normalize with compatibility-decompose + canonical-compose (NFKC)
	$utext = normalize( 'KC', $utext );

	return $utext;
}

######################################################################
=pod

=item @words = EPrints::Index::Tokenizer::split_words( $session, $utext )

Splits a utf8 string into individual words. 

=cut
######################################################################

sub split_words
{
	my( $session, $utext ) = @_;

	$utext = _cast_string( $utext );

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
	my( $session, $utext ) = @_;

	$utext = _cast_string( $utext );

	return join("", map {
		exists($EPrints::Index::FREETEXT_CHAR_MAPPING->{$_}) ?
		$EPrints::Index::FREETEXT_CHAR_MAPPING->{$_} :
		$_;
	} split(//, $utext));
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
		chr(0x00c4) => 'AE',    # Ä
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
		chr(0x00d6) => 'OE',    # Ö
		chr(0x00d7) => 'x',     # ×
		chr(0x00d8) => 'O',     # Ø
		chr(0x00d9) => 'U',     # Ù
		chr(0x00da) => 'U',     # Ú
		chr(0x00db) => 'U',     # Û
		chr(0x00dc) => 'UE',    # Ü
		chr(0x00dd) => 'Y',     # Ý
		chr(0x00de) => 'TH',    # Þ
		chr(0x00df) => 'ss',    # ß
		chr(0x00e0) => 'a',     # à
		chr(0x00e1) => 'a',     # á
		chr(0x00e2) => 'a',     # â
		chr(0x00e3) => 'a',     # ã
		chr(0x00e4) => 'ae',    # ä
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
		chr(0x00c4) => 'AE',	# Ä
		chr(0x00C5) => 'A',	# Å
		chr(0x00c6) => 'AE',	# Æ
		chr(0x00c7) => 'C',	# Ç
		chr(0x00c8) => 'E',	# È
		chr(0x00c9) => 'E',	# É
		chr(0x00ca) => 'E',	# Ê
		chr(0x00cb) => 'E',	# Ë
		chr(0x00cc) => 'I',	# Ì
		chr(0x00cd) => 'I',	# Í
		chr(0x00ce) => 'I',	# Î
		chr(0x00cf) => 'I',	# Ï
		chr(0x00d0) => 'D',	# Ð
		chr(0x00d1) => 'N',	# Ñ
		chr(0x00d2) => 'O',	# Ò
		chr(0x00d3) => 'O',	# Ó
		chr(0x00d4) => 'O',	# Ô
		chr(0x00d5) => 'O',	# Õ
		chr(0x00d6) => 'OE',	# Ö
		chr(0x00d7) => 'x',	# ×
		chr(0x00d8) => 'O',	# Ø
		chr(0x00d9) => 'U',	# Ù
		chr(0x00da) => 'U',	# Ú
		chr(0x00db) => 'U',	# Û
		chr(0x00dc) => 'UE',	# Ü
		chr(0x00dd) => 'Y',	# Ý
		chr(0x00de) => 'TH',	# Þ
		chr(0x00df) => 'ss',	# ß
		chr(0x00e0) => 'a',	# à
		chr(0x00e1) => 'a',	# á
		chr(0x00e2) => 'a',	# â
		chr(0x00e3) => 'a',	# ã
		chr(0x00e4) => 'ae',	# ä
		chr(0x00e5) => 'a',	# å
		chr(0x00e6) => 'ae',	# æ
		chr(0x00e7) => 'c',	# ç
		chr(0x00e8) => 'e',	# è
		chr(0x00e9) => 'e',	# é
		chr(0x00ea) => 'e',	# ê
		chr(0x00eb) => 'e',	# ë
		chr(0x00ec) => 'i',	# ì
		chr(0x00ed) => 'i',	# í
		chr(0x00ee) => 'i',	# î
		chr(0x00ef) => 'i',	# ï
		chr(0x00f0) => 'd',	# ð
		chr(0x00f1) => 'n',	# ñ
		chr(0x00f2) => 'o',	# ò
		chr(0x00f3) => 'o',	# ó
		chr(0x00f4) => 'o',	# ô
		chr(0x00f5) => 'o',	# õ
		chr(0x00f6) => 'oe',	# ö
		chr(0x00f7) => '/',	# ÷
		chr(0x00f8) => 'oe',	# ø
		chr(0x00f9) => 'u',	# ù
		chr(0x00fa) => 'u',	# ú
		chr(0x00fb) => 'u',	# û
		chr(0x00fc) => 'ue',	# ü
		chr(0x00fd) => 'y',	# ý
		chr(0x00fe) => 'th',	# þ
		chr(0x00ff) => 'y',	# ÿ
		chr(0x0100) => 'A',
		chr(0x0101) => 'a',
		chr(0x0102) => 'a',
		chr(0x0103) => 'a',
		chr(0x0104) => 'A',
		chr(0x0105) => 'a',
		chr(0x0106) => 'C',
		chr(0x0107) => 'c',
		chr(0x0108) => 'C',
		chr(0x0109) => 'c',
		chr(0x010A) => 'C',
		chr(0x010B) => 'c',
		chr(0x010C) => 'C',
		chr(0x010D) => 'c',
		chr(0x010E) => 'D',
		chr(0x010F) => 'd',
		chr(0x0110) => 'D',
		chr(0x0111) => 'd',
		chr(0x0112) => 'E',
		chr(0x0113) => 'e',
		chr(0x0114) => 'E',
		chr(0x0115) => 'e',
		chr(0x0116) => 'E',
		chr(0x0117) => 'e',
		chr(0x0118) => 'E',
		chr(0x0119) => 'e',
		chr(0x011A) => 'E',
		chr(0x011B) => 'e',
		chr(0x011C) => 'G',
		chr(0x011D) => 'g',
		chr(0x011E) => 'G',
		chr(0x011F) => 'g',
		chr(0x0120) => 'G',
		chr(0x0121) => 'g',
		chr(0x0122) => 'G',
		chr(0x0123) => 'g',
		chr(0x0124) => 'H',
		chr(0x0125) => 'h',
		chr(0x0126) => 'H',
		chr(0x0127) => 'h',
		chr(0x0128) => 'I',
		chr(0x0129) => 'i',
		chr(0x012A) => 'I',
		chr(0x012B) => 'i',
		chr(0x012C) => 'I',
		chr(0x012D) => 'i',
		chr(0x012E) => 'I',
		chr(0x012F) => 'i',
		chr(0x0130) => 'I',
		chr(0x0131) => 'i',
		chr(0x0132) => 'IJ',     # Ĳ
		chr(0x0133) => 'ij',     # ĳ
		chr(0x0134) => 'J',
		chr(0x0135) => 'j',
		chr(0x0136) => 'K',
		chr(0x0137) => 'k',
		chr(0x0138) => 'k',
		chr(0x0139) => 'L',
		chr(0x013A) => 'l',
		chr(0x013B) => 'L',
		chr(0x013C) => 'l',
		chr(0x013D) => 'L',
		chr(0x013E) => 'l',
		chr(0x013F) => 'L',
		chr(0x0140) => 'l',
		chr(0x0141) => 'L',
		chr(0x0142) => 'l',
		chr(0x0143) => 'N',
		chr(0x0144) => 'n',
		chr(0x0145) => 'N',
		chr(0x0146) => 'n',
		chr(0x0147) => 'N',
		chr(0x0148) => 'n',
		chr(0x0149) => 'n',
		chr(0x014A) => 'N',
		chr(0x014B) => 'n',
		chr(0x014C) => 'O',
		chr(0x014D) => 'o',
		chr(0x014E) => 'O',
		chr(0x014F) => 'o',
		chr(0x0150) => 'OE',     # Ö
		chr(0x0151) => 'oe',     # ö
		chr(0x0152) => 'OE',     # Œ
		chr(0x0153) => 'oe',     # œ
		chr(0x0154) => 'R',
		chr(0x0155) => 'r',
		chr(0x0156) => 'R',
		chr(0x0157) => 'r',
		chr(0x0158) => 'R',
		chr(0x0159) => 'r',
		chr(0x015A) => 'S',
		chr(0x015B) => 's',
		chr(0x015C) => 'S',
		chr(0x015D) => 's',
		chr(0x015E) => 'S',
		chr(0x015F) => 's',
		chr(0x0160) => 'S',
		chr(0x0161) => 's',
		chr(0x0162) => 'T',
		chr(0x0163) => 't',
		chr(0x0164) => 'T',
		chr(0x0165) => 't',
		chr(0x0166) => 'T',
		chr(0x0167) => 't',
		chr(0x0168) => 'U',
		chr(0x0169) => 'u',
		chr(0x016A) => 'U',
		chr(0x016B) => 'u',
		chr(0x016C) => 'U',
		chr(0x016D) => 'u',
		chr(0x016E) => 'U',
		chr(0x016F) => 'u',
		chr(0x0170) => 'UE',     # Ü
		chr(0x0171) => 'ue',     # ü
		chr(0x0172) => 'U',
		chr(0x0173) => 'u',
		chr(0x0174) => 'W',
		chr(0x0175) => 'w',
		chr(0x0176) => 'Y',
		chr(0x0177) => 'y',
		chr(0x0178) => 'Y',
		chr(0x0179) => 'Z',
		chr(0x017A) => 'z',
		chr(0x017B) => 'Z',
		chr(0x017C) => 'z',
		chr(0x017D) => 'Z',
		chr(0x017E) => 'z',
		chr(0x0300) => '', # combining diacritical marks start
		chr(0x0301) => '',
		chr(0x0302) => '',
		chr(0x0303) => '',
		chr(0x0304) => '',
		chr(0x0305) => '',
		chr(0x0306) => '',
		chr(0x0307) => '',
		chr(0x0308) => '',
		chr(0x0309) => '',
		chr(0x030A) => '',
		chr(0x030B) => '',
		chr(0x030C) => '',
		chr(0x030D) => '',
		chr(0x030E) => '',
		chr(0x030F) => '',
		chr(0x0310) => '',
                chr(0x0311) => '',
                chr(0x0312) => '',
                chr(0x0313) => '',
                chr(0x0314) => '',
                chr(0x0315) => '',
                chr(0x0316) => '',
                chr(0x0317) => '',
                chr(0x0318) => '',
                chr(0x0319) => '',
		chr(0x031A) => '',
                chr(0x031B) => '',
                chr(0x031C) => '',
                chr(0x031D) => '',
                chr(0x031E) => '',
                chr(0x031F) => '',
		chr(0x0320) => '',
                chr(0x0321) => '',
                chr(0x0322) => '',
                chr(0x0323) => '',
                chr(0x0324) => '',
                chr(0x0325) => '',
                chr(0x0326) => '',
                chr(0x0327) => '',
                chr(0x0328) => '',
                chr(0x0329) => '',
		chr(0x032A) => '',
                chr(0x032B) => '',
                chr(0x032C) => '',
                chr(0x032D) => '',
                chr(0x032E) => '',
                chr(0x032F) => '',
		chr(0x0330) => '',
                chr(0x0331) => '',
                chr(0x0332) => '',
                chr(0x0333) => '',
                chr(0x0334) => '',
                chr(0x0335) => '',
                chr(0x0336) => '',
                chr(0x0337) => '',
                chr(0x0338) => '',
                chr(0x0339) => '',
		chr(0x033A) => '',
                chr(0x033B) => '',
                chr(0x033C) => '',
                chr(0x033D) => '',
                chr(0x033E) => '',
                chr(0x033F) => '',
		chr(0x0340) => '',
                chr(0x0341) => '',
                chr(0x0342) => '',
                chr(0x0343) => '',
                chr(0x0344) => '',
                chr(0x0345) => '',
                chr(0x0346) => '',
                chr(0x0347) => '',
                chr(0x0348) => '',
                chr(0x0349) => '',
		chr(0x034A) => '',
                chr(0x034B) => '',
                chr(0x034C) => '',
                chr(0x034D) => '',
                chr(0x034E) => '',
                chr(0x034F) => '',
		chr(0x0350) => '',
                chr(0x0351) => '',
                chr(0x0352) => '',
                chr(0x0353) => '',
                chr(0x0354) => '',
                chr(0x0355) => '',
                chr(0x0356) => '',
                chr(0x0357) => '',
                chr(0x0358) => '',
                chr(0x0359) => '',
		chr(0x035A) => '',
                chr(0x035B) => '',
                chr(0x035C) => '',
                chr(0x035D) => '',
                chr(0x035E) => '',
                chr(0x035F) => '',
		chr(0x0360) => '',
                chr(0x0361) => '',
                chr(0x0362) => '', # combining diacritical marks end
		chr(0x0391) => 'A',
		chr(0x03B1) => 'a',
		chr(0x0392) => 'B',
		chr(0x03B2) => 'b',
		chr(0x0393) => 'G',
		chr(0x03B3) => 'g',
		chr(0x0394) => 'D',
		chr(0x03B4) => 'd',
		chr(0x0395) => 'E',
		chr(0x03B5) => 'e',
		chr(0x0396) => 'Z',
		chr(0x03B6) => 'z',
		chr(0x0397) => 'E',
		chr(0x03B7) => 'e',
		chr(0x0398) => 'TH',
		chr(0x03B8) => 'th',
		chr(0x0399) => 'I',
		chr(0x03B9) => 'i',
		chr(0x039A) => 'K',
		chr(0x03BA) => 'k',
		chr(0x039B) => 'L',
		chr(0x03BB) => 'l',
		chr(0x039C) => 'M',
		chr(0x03BC) => 'm',
		chr(0x039D) => 'N',
		chr(0x03BD) => 'n',
		chr(0x039E) => 'X',
		chr(0x03BE) => 'x',
		chr(0x039F) => 'O',
		chr(0x03BF) => 'o',
		chr(0x03A0) => 'P',
		chr(0x03C0) => 'p',
		chr(0x03A1) => 'R',
		chr(0x03C1) => 'r',
		chr(0x03A3) => 'S',
		chr(0x03C3) => 's',
		chr(0x03A4) => 'T',
		chr(0x03C4) => 't',
		chr(0x03A5) => 'Y',
		chr(0x03C5) => 'y',
		chr(0x03A6) => 'Ph',
		chr(0x03C6) => 'ph',
		chr(0x03A7) => 'Ch',
		chr(0x03C7) => 'ch',
		chr(0x03A8) => 'Ps',
		chr(0x03C8) => 'ps',
		chr(0x03A9) => 'O',
		chr(0x03C9) => 'o',
		chr(0x03AA) => 'I',
		chr(0x03CA) => 'i',
		chr(0x03AB) => 'Y',
		chr(0x03CB) => 'y',
		chr(0x03AC) => 'a',
		chr(0x03AD) => 'e',
		chr(0x03AE) => 'e',
		chr(0x03AF) => 'i',
		chr(0x03B0) => 'y',
		chr(0x03CC) => 'o',
		chr(0x03CD) => 'y',
		chr(0x03CE) => 'o',
		chr(0x0386) => 'A',
		chr(0x0389) => 'E',
		chr(0x038A) => 'I',
		chr(0x038C) => 'O',
		chr(0x038E) => 'Y',
		chr(0x038F) => 'O',
		chr(0x0390) => 'i',
		chr(0x0387) => ';',
		chr(0x0363) => 'a',
		chr(0x0364) => 'e',
		chr(0x0365) => 'i',
		chr(0x0366) => 'o',
		chr(0x0367) => 'u',
		chr(0x0368) => 'c',
		chr(0x0369) => 'd',
		chr(0x036A) => 'h',
		chr(0x036B) => 'm',
		chr(0x036C) => 'r',
		chr(0x036D) => 't',
		chr(0x036E) => 'v',
		chr(0x036F) => 'x',
		chr(0x2010) => '-',
		chr(0x2011) => '-',
		chr(0x2012) => '-',
		chr(0x2013) => '-',
		chr(0x2014) => '-',
		chr(0x2019) => "'",     # ’
		chr(0x2074) => '4',
		chr(0x2075) => '5',
		chr(0x2076) => '6',
		chr(0x2077) => '7',
		chr(0x2078) => '8',
		chr(0x2079) => '9',
		chr(0x207A) => '+',
		chr(0x207B) => '-',
		chr(0x207C) => '=',
		chr(0x207D) => '(',
		chr(0x207E) => ')',
		chr(0x2080) => '0',
		chr(0x2081) => '1',
		chr(0x2082) => '2',
		chr(0x2083) => '3',
		chr(0x2084) => '4',
		chr(0x2085) => '5',
		chr(0x2086) => '6',
		chr(0x2087) => '7',
		chr(0x2088) => '8',
		chr(0x2089) => '9',
		chr(0x208A) => '+',
		chr(0x208B) => '-',
		chr(0x208C) => '=',
		chr(0x208D) => '(',
		chr(0x208E) => ')',
		chr(0x2090) => 'a',
		chr(0x2091) => 'e',
		chr(0x2092) => 'o',
		chr(0x2093) => 'x',
		chr(0x2094) => 'e',
		chr(0x2153) => '1/3',
		chr(0x2154) => '2/3',
		chr(0x2155) => '1/5',
		chr(0x2156) => '2/5',
		chr(0x2157) => '3/5',
		chr(0x2158) => '4/5',
		chr(0x2159) => '1/6',
		chr(0x215A) => '5/6',
		chr(0x215B) => '1/8',
		chr(0x215C) => '3/8',
		chr(0x215D) => '5/8',
		chr(0x215E) => '7/8',
		chr(0x215F) => '1/',
		chr(0x2160) => 'I',
		chr(0x2161) => 'II',
		chr(0x2162) => 'III',
		chr(0x2163) => 'IV',
		chr(0x2164) => 'V',
		chr(0x2165) => 'VI',
		chr(0x2166) => 'VII',
		chr(0x2167) => 'VIII',
		chr(0x2168) => 'IX',
		chr(0x2169) => 'X',
		chr(0x216A) => 'XI',
		chr(0x216B) => 'XII',
		chr(0x216C) => 'L',
		chr(0x216D) => 'C',
		chr(0x216E) => 'D',
		chr(0x216F) => 'M',
		chr(0x2170) => 'i',
		chr(0x2171) => 'ii',
		chr(0x2172) => 'iii',
		chr(0x2173) => 'iv',
		chr(0x2174) => 'v',
		chr(0x2175) => 'vi',
		chr(0x2176) => 'vii',
		chr(0x2177) => 'viii',
		chr(0x2178) => 'ix',
		chr(0x2179) => 'x',
		chr(0x217A) => 'xi',
		chr(0x217B) => 'xii',
		chr(0x217C) => 'l',
		chr(0x217D) => 'c',
		chr(0x217E) => 'd',
		chr(0x217F) => 'm',
		chr(0x2122) => 'TM',
		chr(0x25CC) => '', # dotted circle left when removing modifier for combining diacritical marks
		chr(0xFB00) => 'ff',     # ﬀ
		chr(0xFB01) => 'fi',     # ﬁ
		chr(0xFB02) => 'fl',     # ﬂ
		chr(0xFB03) => 'ffi',     # ﬃ
		chr(0xFB04) => 'ffl',     # ﬄ
		chr(0xFB05) => 'st',     # ﬅ
		chr(0xFB06) => 'st',     # ﬆ
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

