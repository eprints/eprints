package TeX::Encode::charmap;

=head1 NAME

TeX::Encode::charmap - Character mappings between TeX and Unicode

=head1 DESCRIPTION

This mapping was built from Tralics, see http://www-sop.inria.fr/apics/tralics/

=cut

use vars qw( %RESERVED %BIBTEX_RESERVED %CHARS %ACCENTED_CHARS %LATEX_MACROS %GREEK %TEX_GREEK %MATH %MATH_CHARS );

# reserved latex characters
%RESERVED = (
'#' => '\\#',
'$' => '\\$',
'%' => '\\%',
'&' => '\\&',
'_' => '\\_',
'{' => '\\{',
'}' => '\\}',
'\\' => '\\texttt{\\char92}',
'^' => '\^{ }', # '\\texttt{\\char94}',
'~' => '\\texttt{\\char126}',
);

%BIBTEX_RESERVED = (
'#' => '\\#',
'$' => '\\$',
'%' => '\\%',
'&' => '\\&',
'_' => '\\_',
'{' => '\\{',
'}' => '\\}',
'\\' => '{$\\backslash$}',
'^' => '{\^{ }}',
'~' => '{\\texttt{\\char126}}',
);

# single, non-ligature characters
%CHARS = (

# ASCII characters
'<' => "\\ensuremath{<}",
'>' => "\\ensuremath{>}",
'|' => "\\ensuremath{|}",
chr(0x2014) => "--", # emdash

# non-accented
chr(0x00a3) => "\\pounds", # £
chr(0x00a7) => "\\S", # §
chr(0x00a9) => "\\copyright",
chr(0x00b6) => "\\P", # ¶
chr(0x00c5) => "\\AA", # Å
chr(0x00c6) => "\\AE", # Æ
chr(0x00d0) => "\\DH", # Ð
chr(0x00d8) => "\\O", # Ø
chr(0x00de) => "\\TH", # Þ
chr(0x00df) => "\\ss", # ß
chr(0x00e5) => "\\aa", # å
chr(0x00e6) => "\\ae", # æ
chr(0x00f0) => "\\dh", # ð
chr(0x00f8) => "\\o", # ø
chr(0x00fe) => "\\th", # þ
chr(0x0110) => "\\DJ", # Đ
chr(0x0111) => "\\dj", # đ
chr(0x0132) => "\\IJ", # Ĳ
chr(0x0133) => "\\ij", # ĳ
chr(0x0141) => "\\L", # Ł
chr(0x0142) => "\\l", # ł
chr(0x014a) => "\\NG", # Ŋ
chr(0x014b) => "\\ng", # ŋ
chr(0x0152) => "\\OE", # Œ
chr(0x0153) => "\\oe", # œ

# superscript/subscript (maths)
chr(0x2070) => '$^0$',
chr(0x2071) => '$^i$',
chr(0x2074) => '$^4$',
chr(0x2075) => '$^5$',
chr(0x2076) => '$^6$',
chr(0x2077) => '$^7$',
chr(0x2078) => '$^8$',
chr(0x2079) => '$^9$',
chr(0x207A) => '$^+$',
chr(0x207B) => '$^-$',
chr(0x207C) => '$^=$',
chr(0x207D) => '$^($',
chr(0x207E) => '$^)$',
chr(0x207F) => '$^n$',
chr(0x2080) => '$_0$',
chr(0x2081) => '$_1$',
chr(0x2082) => '$_2$',
chr(0x2083) => '$_3$',
chr(0x2084) => '$_4$',
chr(0x2085) => '$_5$',
chr(0x2086) => '$_6$',
chr(0x2087) => '$_7$',
chr(0x2088) => '$_8$',
chr(0x2089) => '$_9$',
chr(0x208A) => '$_+$',
chr(0x208B) => '$_-$',
chr(0x208C) => '$_=$',
chr(0x208D) => '$_($',
chr(0x208E) => '$_)$',

);

# accented characters
%ACCENTED_CHARS = (

### Æ

chr(0x01fc) => "\\\'{\\AE}", # Ǽ
chr(0x01e2) => "\\\={\\AE}", # Ǣ

### æ

chr(0x01fd) => "\\\'{\\ae}", # ǽ
chr(0x01e3) => "\\\={\\ae}", # ǣ

### Å

chr(0x01fa) => "\\\'{\\AA}", # Ǻ

### å

chr(0x01fb) => "\\\'{\\aa}", # ǻ

### Ø

chr(0x01fe) => "\\\'{\\O}", # Ǿ

### ø

chr(0x01ff) => "\\\'{\\o}", # ǿ

### 


### 


### A

chr(0x00c1) => "\\\'A", # Á
chr(0x00c0) => "\\\`A", # À
chr(0x00c2) => "\\\^A", # Â
chr(0x00c4) => "\\\"A", # Ä
chr(0x00c3) => "\\\~A", # Ã
chr(0x0104) => "\\kA", # Ą
chr(0x01cd) => "\\vA", # Ǎ
chr(0x0102) => "\\uA", # Ă
chr(0x0226) => "\\\.A", # Ȧ
chr(0x0100) => "\\\=A", # Ā
chr(0x00c5) => "\\rA", # Å
chr(0x1ea0) => "\\dA", # Ạ
chr(0x0200) => "\\CA", # Ȁ
chr(0x0202) => "\\fA", # Ȃ
chr(0x1e00) => "\\DA", # Ḁ
chr(0x1ea2) => "\\hA", # Ả

### B

chr(0x1e02) => "\\\.B", # Ḃ
chr(0x1e06) => "\\bB", # Ḇ
chr(0x1e04) => "\\dB", # Ḅ

### C

chr(0x0106) => "\\\'C", # Ć
chr(0x0108) => "\\\^C", # Ĉ
chr(0x010c) => "\\vC", # Č
chr(0x00c7) => "\\cC", # Ç
chr(0x010a) => "\\\.C", # Ċ

### D

chr(0x010e) => "\\vD", # Ď
chr(0x1e10) => "\\cD", # Ḑ
chr(0x1e0a) => "\\\.D", # Ḋ
chr(0x1e0e) => "\\bD", # Ḏ
chr(0x1e0c) => "\\dD", # Ḍ
chr(0x1e12) => "\\VD", # Ḓ

### E

chr(0x00c9) => "\\\'E", # É
chr(0x00c8) => "\\\`E", # È
chr(0x00ca) => "\\\^E", # Ê
chr(0x00cb) => "\\\"E", # Ë
chr(0x1ebc) => "\\\~E", # Ẽ
chr(0x0118) => "\\kE", # Ę
chr(0x011a) => "\\vE", # Ě
chr(0x0114) => "\\uE", # Ĕ
chr(0x0228) => "\\cE", # Ȩ
chr(0x0116) => "\\\.E", # Ė
chr(0x0112) => "\\\=E", # Ē
chr(0x1eb8) => "\\dE", # Ẹ
chr(0x0204) => "\\CE", # Ȅ
chr(0x0206) => "\\fE", # Ȇ
chr(0x1e1a) => "\\TE", # Ḛ
chr(0x1e18) => "\\VE", # Ḙ
chr(0x1eba) => "\\hE", # Ẻ

### F

chr(0x1e1e) => "\\\.F", # Ḟ

### G

chr(0x01f4) => "\\\'G", # Ǵ
chr(0x011c) => "\\\^G", # Ĝ
chr(0x01e6) => "\\vG", # Ǧ
chr(0x011e) => "\\uG", # Ğ
chr(0x0122) => "\\cG", # Ģ
chr(0x0120) => "\\\.G", # Ġ
chr(0x1e20) => "\\\=G", # Ḡ

### H

chr(0x0124) => "\\\^H", # Ĥ
chr(0x1e26) => "\\\"H", # Ḧ
chr(0x021e) => "\\vH", # Ȟ
chr(0x1e28) => "\\cH", # Ḩ
chr(0x1e22) => "\\\.H", # Ḣ
chr(0x0126) => "\\\=H", # Ħ
chr(0x1e24) => "\\dH", # Ḥ

### I

chr(0x00cd) => "\\\'I", # Í
chr(0x00cc) => "\\\`I", # Ì
chr(0x00ce) => "\\\^I", # Î
chr(0x00cf) => "\\\"I", # Ï
chr(0x0128) => "\\\~I", # Ĩ
chr(0x012e) => "\\kI", # Į
chr(0x01cf) => "\\vI", # Ǐ
chr(0x012c) => "\\uI", # Ĭ
chr(0x0130) => "\\\.I", # İ
chr(0x012a) => "\\\=I", # Ī
chr(0x1eca) => "\\dI", # Ị
chr(0x0208) => "\\CI", # Ȉ
chr(0x020a) => "\\fI", # Ȋ
chr(0x1e2c) => "\\TI", # Ḭ
chr(0x1ec8) => "\\hI", # Ỉ

### J

chr(0x0134) => "\\\^J", # Ĵ

### K

chr(0x1e30) => "\\\'K", # Ḱ
chr(0x01e8) => "\\vK", # Ǩ
chr(0x0136) => "\\cK", # Ķ
chr(0x1e34) => "\\bK", # Ḵ
chr(0x1e32) => "\\dK", # Ḳ

### L

chr(0x0139) => "\\\'L", # Ĺ
chr(0x013d) => "\\vL", # Ľ
chr(0x013b) => "\\cL", # Ļ
chr(0x013f) => "\\\.L", # Ŀ
chr(0x1e3a) => "\\bL", # Ḻ
chr(0x1e36) => "\\dL", # Ḷ
chr(0x1e3c) => "\\VL", # Ḽ

### M

chr(0x1e3e) => "\\\'M", # Ḿ
chr(0x1e40) => "\\\.M", # Ṁ
chr(0x1e42) => "\\dM", # Ṃ

### N

chr(0x0143) => "\\\'N", # Ń
chr(0x01f8) => "\\\`N", # Ǹ
chr(0x00d1) => "\\\~N", # Ñ
chr(0x0147) => "\\vN", # Ň
chr(0x0145) => "\\cN", # Ņ
chr(0x1e44) => "\\\.N", # Ṅ
chr(0x1e48) => "\\bN", # Ṉ
chr(0x1e46) => "\\dN", # Ṇ
chr(0x1e4a) => "\\VN", # Ṋ

### O

chr(0x00d3) => "\\\'O", # Ó
chr(0x00d2) => "\\\`O", # Ò
chr(0x00d4) => "\\\^O", # Ô
chr(0x00d6) => "\\\"O", # Ö
chr(0x00d5) => "\\\~O", # Õ
chr(0x01ea) => "\\kO", # Ǫ
chr(0x0150) => "\\HO", # Ő
chr(0x01d1) => "\\vO", # Ǒ
chr(0x014e) => "\\uO", # Ŏ
chr(0x022e) => "\\\.O", # Ȯ
chr(0x014c) => "\\\=O", # Ō
chr(0x1ecc) => "\\dO", # Ọ
chr(0x020c) => "\\CO", # Ȍ
chr(0x020e) => "\\fO", # Ȏ
chr(0x1ece) => "\\hO", # Ỏ

### P

chr(0x1e54) => "\\\'P", # Ṕ
chr(0x1e56) => "\\\.P", # Ṗ

### Q


### R

chr(0x0154) => "\\\'R", # Ŕ
chr(0x0158) => "\\vR", # Ř
chr(0x0156) => "\\cR", # Ŗ
chr(0x1e58) => "\\\.R", # Ṙ
chr(0x1e5e) => "\\bR", # Ṟ
chr(0x1e5a) => "\\dR", # Ṛ
chr(0x0210) => "\\CR", # Ȑ
chr(0x0212) => "\\fR", # Ȓ

### S

chr(0x015a) => "\\\'S", # Ś
chr(0x015c) => "\\\^S", # Ŝ
chr(0x0160) => "\\vS", # Š
chr(0x015e) => "\\cS", # Ş
chr(0x1e60) => "\\\.S", # Ṡ
chr(0x1e62) => "\\dS", # Ṣ

### T

chr(0x0164) => "\\vT", # Ť
chr(0x0162) => "\\cT", # Ţ
chr(0x1e6a) => "\\\.T", # Ṫ
chr(0x0166) => "\\\=T", # Ŧ
chr(0x1e6e) => "\\bT", # Ṯ
chr(0x1e6c) => "\\dT", # Ṭ
chr(0x1e70) => "\\VT", # Ṱ

### U

chr(0x00da) => "\\\'U", # Ú
chr(0x00d9) => "\\\`U", # Ù
chr(0x00db) => "\\\^U", # Û
chr(0x00dc) => "\\\"U", # Ü
chr(0x0168) => "\\\~U", # Ũ
chr(0x0172) => "\\kU", # Ų
chr(0x0170) => "\\HU", # Ű
chr(0x01d3) => "\\vU", # Ǔ
chr(0x016c) => "\\uU", # Ŭ
chr(0x016a) => "\\\=U", # Ū
chr(0x016e) => "\\rU", # Ů
chr(0x1ee4) => "\\dU", # Ụ
chr(0x0214) => "\\CU", # Ȕ
chr(0x0216) => "\\fU", # Ȗ
chr(0x1e74) => "\\TU", # Ṵ
chr(0x1e76) => "\\VU", # Ṷ
chr(0x1ee6) => "\\hU", # Ủ

### V

chr(0x1e7c) => "\\\~V", # Ṽ
chr(0x1e7e) => "\\dV", # Ṿ

### W

chr(0x1e82) => "\\\'W", # Ẃ
chr(0x1e80) => "\\\`W", # Ẁ
chr(0x0174) => "\\\^W", # Ŵ
chr(0x1e84) => "\\\"W", # Ẅ
chr(0x1e86) => "\\\.W", # Ẇ
chr(0x1e88) => "\\dW", # Ẉ

### X

chr(0x1e8c) => "\\\"X", # Ẍ
chr(0x1e8a) => "\\\.X", # Ẋ

### Y

chr(0x00dd) => "\\\'Y", # Ý
chr(0x1ef2) => "\\\`Y", # Ỳ
chr(0x0176) => "\\\^Y", # Ŷ
chr(0x0178) => "\\\"Y", # Ÿ
chr(0x1ef8) => "\\\~Y", # Ỹ
chr(0x1e8e) => "\\\.Y", # Ẏ
chr(0x0232) => "\\\=Y", # Ȳ
chr(0x1ef4) => "\\dY", # Ỵ
chr(0x1ef6) => "\\hY", # Ỷ

### Z

chr(0x0179) => "\\\'Z", # Ź
chr(0x1e90) => "\\\^Z", # Ẑ
chr(0x017d) => "\\vZ", # Ž
chr(0x017b) => "\\\.Z", # Ż
chr(0x1e94) => "\\bZ", # Ẕ
chr(0x1e92) => "\\dZ", # Ẓ

### [


### \


### ]


### ^


### _


### `


### a

chr(0x00e1) => "\\\'a", # á
chr(0x00e0) => "\\\`a", # à
chr(0x00e2) => "\\\^a", # â
chr(0x00e4) => "\\\"a", # ä
chr(0x00e3) => "\\\~a", # ã
chr(0x0105) => "\\ka", # ą
chr(0x01ce) => "\\va", # ǎ
chr(0x0103) => "\\ua", # ă
chr(0x0227) => "\\\.a", # ȧ
chr(0x0101) => "\\\=a", # ā
chr(0x00e5) => "\\ra", # å
chr(0x1ea1) => "\\da", # ạ
chr(0x0201) => "\\Ca", # ȁ
chr(0x0203) => "\\fa", # ȃ
chr(0x1e01) => "\\Da", # ḁ
chr(0x1ea3) => "\\ha", # ả

### b

chr(0x1e03) => "\\\.b", # ḃ
chr(0x1e07) => "\\bb", # ḇ
chr(0x1e05) => "\\db", # ḅ

### c

chr(0x0107) => "\\\'c", # ć
chr(0x0109) => "\\\^c", # ĉ
chr(0x010d) => "\\vc", # č
chr(0x00e7) => "\\cc", # ç
chr(0x010b) => "\\\.c", # ċ

### d

chr(0x010f) => "\\vd", # ď
chr(0x1e11) => "\\cd", # ḑ
chr(0x1e0b) => "\\\.d", # ḋ
chr(0x1e0f) => "\\bd", # ḏ
chr(0x1e0d) => "\\dd", # ḍ
chr(0x1e13) => "\\Vd", # ḓ

### e

chr(0x00e9) => "\\\'e", # é
chr(0x00e8) => "\\\`e", # è
chr(0x00ea) => "\\\^e", # ê
chr(0x00eb) => "\\\"e", # ë
chr(0x1ebd) => "\\\~e", # ẽ
chr(0x0119) => "\\ke", # ę
chr(0x011b) => "\\ve", # ě
chr(0x0115) => "\\ue", # ĕ
chr(0x0229) => "\\ce", # ȩ
chr(0x0117) => "\\\.e", # ė
chr(0x0113) => "\\\=e", # ē
chr(0x1eb9) => "\\de", # ẹ
chr(0x0205) => "\\Ce", # ȅ
chr(0x0207) => "\\fe", # ȇ
chr(0x1e1b) => "\\Te", # ḛ
chr(0x1e19) => "\\Ve", # ḙ
chr(0x1ebb) => "\\he", # ẻ

### f

chr(0x1e1f) => "\\\.f", # ḟ

### g

chr(0x01f5) => "\\\'g", # ǵ
chr(0x011d) => "\\\^g", # ĝ
chr(0x01e7) => "\\vg", # ǧ
chr(0x011f) => "\\ug", # ğ
chr(0x0123) => "\\cg", # ģ
chr(0x0121) => "\\\.g", # ġ
chr(0x1e21) => "\\\=g", # ḡ

### h

chr(0x0125) => "\\\^h", # ĥ
chr(0x1e27) => "\\\"h", # ḧ
chr(0x021f) => "\\vh", # ȟ
chr(0x1e29) => "\\ch", # ḩ
chr(0x1e23) => "\\\.h", # ḣ
chr(0x0127) => "\\\=h", # ħ
chr(0x1e96) => "\\bh", # ẖ
chr(0x1e25) => "\\dh", # ḥ

### i

chr(0x00ed) => "\\\'i", # í
chr(0x00ec) => "\\\`i", # ì
chr(0x00ee) => "\\\^i", # î
chr(0x00ef) => "\\\"i", # ï
chr(0x0129) => "\\\~i", # ĩ
chr(0x012f) => "\\ki", # į
chr(0x01d0) => "\\vi", # ǐ
chr(0x012d) => "\\ui", # ĭ
chr(0x012b) => "\\\=i", # ī
chr(0x1ecb) => "\\di", # ị
chr(0x0209) => "\\Ci", # ȉ
chr(0x020b) => "\\fi", # ȋ
chr(0x1e2d) => "\\Ti", # ḭ
chr(0x1ec9) => "\\hi", # ỉ

### j

chr(0x0135) => "\\\^j", # ĵ
chr(0x01f0) => "\\vj", # ǰ

### k

chr(0x1e31) => "\\\'k", # ḱ
chr(0x01e9) => "\\vk", # ǩ
chr(0x0137) => "\\ck", # ķ
chr(0x1e35) => "\\bk", # ḵ
chr(0x1e33) => "\\dk", # ḳ

### l

chr(0x013a) => "\\\'l", # ĺ
chr(0x013e) => "\\vl", # ľ
chr(0x013c) => "\\cl", # ļ
chr(0x0140) => "\\\.l", # ŀ
chr(0x1e3b) => "\\bl", # ḻ
chr(0x1e37) => "\\dl", # ḷ
chr(0x1e3d) => "\\Vl", # ḽ

### m

chr(0x1e3f) => "\\\'m", # ḿ
chr(0x1e41) => "\\\.m", # ṁ
chr(0x1e43) => "\\dm", # ṃ

### n

chr(0x0144) => "\\\'n", # ń
chr(0x01f9) => "\\\`n", # ǹ
chr(0x00f1) => "\\\~n", # ñ
chr(0x0148) => "\\vn", # ň
chr(0x0146) => "\\cn", # ņ
chr(0x1e45) => "\\\.n", # ṅ
chr(0x1e49) => "\\bn", # ṉ
chr(0x1e47) => "\\dn", # ṇ
chr(0x1e4b) => "\\Vn", # ṋ

### o

chr(0x00f3) => "\\\'o", # ó
chr(0x00f2) => "\\\`o", # ò
chr(0x00f4) => "\\\^o", # ô
chr(0x00f6) => "\\\"o", # ö
chr(0x00f5) => "\\\~o", # õ
chr(0x01eb) => "\\ko", # ǫ
chr(0x0151) => "\\Ho", # ő
chr(0x01d2) => "\\vo", # ǒ
chr(0x014f) => "\\uo", # ŏ
chr(0x022f) => "\\\.o", # ȯ
chr(0x014d) => "\\\=o", # ō
chr(0x1ecd) => "\\do", # ọ
chr(0x020d) => "\\Co", # ȍ
chr(0x020f) => "\\fo", # ȏ
chr(0x1ecf) => "\\ho", # ỏ

### p

chr(0x1e55) => "\\\'p", # ṕ
chr(0x1e57) => "\\\.p", # ṗ

### q


### r

chr(0x0155) => "\\\'r", # ŕ
chr(0x0159) => "\\vr", # ř
chr(0x0157) => "\\cr", # ŗ
chr(0x1e59) => "\\\.r", # ṙ
chr(0x1e5f) => "\\br", # ṟ
chr(0x1e5b) => "\\dr", # ṛ
chr(0x0211) => "\\Cr", # ȑ
chr(0x0213) => "\\fr", # ȓ

### s

chr(0x015b) => "\\\'s", # ś
chr(0x015d) => "\\\^s", # ŝ
chr(0x0161) => "\\vs", # š
chr(0x015f) => "\\cs", # ş
chr(0x1e61) => "\\\.s", # ṡ
chr(0x1e63) => "\\ds", # ṣ

### t

chr(0x1e97) => "\\\"t", # ẗ
chr(0x0165) => "\\vt", # ť
chr(0x0163) => "\\ct", # ţ
chr(0x1e6b) => "\\\.t", # ṫ
chr(0x0167) => "\\\=t", # ŧ
chr(0x1e6f) => "\\bt", # ṯ
chr(0x1e6d) => "\\dt", # ṭ
chr(0x1e71) => "\\Vt", # ṱ

### u

chr(0x00fa) => "\\\'u", # ú
chr(0x00f9) => "\\\`u", # ù
chr(0x00fb) => "\\\^u", # û
chr(0x00fc) => "\\\"u", # ü
chr(0x0169) => "\\\~u", # ũ
chr(0x0173) => "\\ku", # ų
chr(0x0171) => "\\Hu", # ű
chr(0x01d4) => "\\vu", # ǔ
chr(0x016d) => "\\uu", # ŭ
chr(0x016b) => "\\\=u", # ū
chr(0x016f) => "\\ru", # ů
chr(0x1ee5) => "\\du", # ụ
chr(0x0215) => "\\Cu", # ȕ
chr(0x0217) => "\\fu", # ȗ
chr(0x1e75) => "\\Tu", # ṵ
chr(0x1e77) => "\\Vu", # ṷ
chr(0x1ee7) => "\\hu", # ủ

### v

chr(0x1e7d) => "\\\~v", # ṽ
chr(0x1e7f) => "\\dv", # ṿ

### w

chr(0x1e83) => "\\\'w", # ẃ
chr(0x1e81) => "\\\`w", # ẁ
chr(0x0175) => "\\\^w", # ŵ
chr(0x1e85) => "\\\"w", # ẅ
chr(0x1e87) => "\\\.w", # ẇ
chr(0x1e98) => "\\rw", # ẘ
chr(0x1e89) => "\\dw", # ẉ

### x

chr(0x1e8d) => "\\\"x", # ẍ
chr(0x1e8b) => "\\\.x", # ẋ

### y

chr(0x00fd) => "\\\'y", # ý
chr(0x1ef3) => "\\\`y", # ỳ
chr(0x0177) => "\\\^y", # ŷ
chr(0x00ff) => "\\\"y", # ÿ
chr(0x1ef9) => "\\\~y", # ỹ
chr(0x1e8f) => "\\\.y", # ẏ
chr(0x0233) => "\\\=y", # ȳ
chr(0x1e99) => "\\ry", # ẙ
chr(0x1ef5) => "\\dy", # ỵ
chr(0x1ef7) => "\\hy", # ỷ

### z

chr(0x017a) => "\\\'z", # ź
chr(0x1e91) => "\\\^z", # ẑ
chr(0x017e) => "\\vz", # ž
chr(0x017c) => "\\\.z", # ż
chr(0x1e95) => "\\bz", # ẕ
chr(0x1e93) => "\\dz", # ẓ

);

# latex character references
%LATEX_MACROS = (

"\\\\" => "\n",

"\\char92" => '\\',
"\\char94" => '^',
"\\char126" => '~',

"--" => chr(0x2014), # --

"\\acute{e}" => chr(0x00e9), # é
"\\textunderscore" => chr(0x005f), # _
"\\textbraceleft" => chr(0x007b), # {
"\\textbraceright" => chr(0x007d), # }
"\\textasciitilde" => chr(0x007e), # ~
"\\textexclamdown" => chr(0x00a1), # ¡
"\\textcent" => chr(0x00a2), # ¢
"\\textsterling" => chr(0x00a3), # £
"\\textcurrency" => chr(0x00a4), # ¤
"\\textyen" => chr(0x00a5), # ¥
"\\textbrokenbar" => chr(0x00a6), # ¦
"\\textsection" => chr(0x00a7), # §
"\\textasciidieresis" => chr(0x00a8), # ¨
"\\copyright" => chr(0x00a9), # ©
"\\textcopyright" => chr(0x00a9), # ©
"\\textordfeminine" => chr(0x00aa), # ª
"\\guillemotleft" => chr(0x00ab), # «
"\\textlnot" => chr(0x00ac), # ¬
"\\textsofthyphen" => chr(0x00ad), # ­
"\\textregistered" => chr(0x00ae), # ®
"\\textasciimacron" => chr(0x00af), # ¯
"\\textdegree" => chr(0x00b0), # °
"\\textpm" => chr(0x00b1), # ±
"\\texttwosuperior" => chr(0x00b2), # ²
"\\textthreesuperior" => chr(0x00b3), # ³
"\\apostrophe" => chr(0x00b4), # ´
"\\textasciiacute" => chr(0x00b4), # ´
"\\textmu" => chr(0x00b5), # µ
"\\textpilcrow" => chr(0x00b6), # ¶
"\\textparagraph" => chr(0x00b6), # ¶
"\\textperiodcentered" => chr(0x00b7), # ·
"\\textasciicedilla" => chr(0x00b8), # ¸
"\\textonesuperior" => chr(0x00b9), # ¹
"\\textordmasculine" => chr(0x00ba), # º
"\\guillemotright" => chr(0x00bb), # »
"\\textonequarter" => chr(0x00bc), # ¼
"\\textonehalf" => chr(0x00bd), # ½
"\\textthreequarters" => chr(0x00be), # ¾
"\\textquestiondown" => chr(0x00bf), # ¿
"\\texttimes" => chr(0x00d7), # ×
"\\textdiv" => chr(0x00f7), # ÷
"\\textflorin" => chr(0x0192), # ƒ
"\\textasciibreve" => chr(0x0306), # ̆
"\\textasciicaron" => chr(0x030c), # ̌
"\\textbaht" => chr(0x0e3f), # ฿
"\\textnospace" => chr(0x200b), # ​
"\\textendash" => chr(0x2013), # –
"\\textemdash" => chr(0x2014), # —
"\\textbardbl" => chr(0x2016), # ‖
"\\textquoteleft" => chr(0x2018), # ‘
"\\textquoteright" => chr(0x2019), # ’
"\\textquotedblleft" => chr(0x201c), # “
"\\textquotedblright" => chr(0x201d), # ”
"\\textdagger" => chr(0x2020), # †
"\\textdaggerdbl" => chr(0x2021), # ‡
"\\textbullet" => chr(0x2022), # •
"\\textellipsis" => chr(0x2026), # …
"\\textperthousand" => chr(0x2030), # ‰
"\\textpertenthousand" => chr(0x2031), # ‱
"\\textacutedbl" => chr(0x2033), # ″
"\\textasciigrave" => chr(0x2035), # ‵
"\\textgravedbl" => chr(0x2036), # ‶
"\\textreferencemark" => chr(0x203b), # ※
"\\textinterrobang" => chr(0x203d), # ‽
"\\textfractionsolidus" => chr(0x2044), # ⁄
"\\textlquill" => chr(0x2045), # ⁅
"\\textrquill" => chr(0x2046), # ⁆
"\\textasteriskcentered" => chr(0x204e), # ⁎
"\\textcolonmonetary" => chr(0x20a1), # ₡
"\\textfrenchfranc" => chr(0x20a3), # ₣
"\\textlira" => chr(0x20a4), # ₤
"\\textnaira" => chr(0x20a6), # ₦
"\\textwon" => chr(0x20a9), # ₩
"\\textdong" => chr(0x20ab), # ₫
"\\texteuro" => chr(0x20ac), # €
"\\textpeso" => chr(0x20b1), # ₱
"\\textcelsius" => chr(0x2103), # ℃
"\\textnumero" => chr(0x2116), # №
"\\textcircledP" => chr(0x2117), # ℗
"\\textrecipe" => chr(0x211e), # ℞
"\\textservicemark" => chr(0x2120), # ℠
"\\texttrademark" => chr(0x2122), # ™
"\\textohm" => chr(0x2126), # Ω
"\\textmho" => chr(0x2127), # ℧
"\\textestimated" => chr(0x212e), # ℮
"\\textleftarrow" => chr(0x2190), # ←
"\\textuparrow" => chr(0x2191), # ↑
"\\textrightarrow" => chr(0x2192), # →
"\\textdownarrow" => chr(0x2193), # ↓
"\\textsurd" => chr(0x221a), # √
"\\textasciicircum" => chr(0x2303), # ⌃
"\\textvisiblespace" => chr(0x2423), # ␣
"\\textopenbullet" => chr(0x25e6), # ◦
"\\textbigcircle" => chr(0x25ef), # ◯
"\\textmusicalnote" => chr(0x266a), # ♪
"\\textlangle" => chr(0x3008), # 〈
"\\textrangle" => chr(0x3009), # 〉

);

%GREEK = %TEX_GREEK = ();
{
	my $i = 0;
	for(qw( alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho varsigma sigma tau upsilon phi chi psi omega )) {
		# lowercase
		$GREEK{$TEX_GREEK{"\\$_"} = chr(0x3b1+$i)} = "\\ensuremath{\\$_}";
		# uppercase
		$GREEK{$TEX_GREEK{"\\\u$_"} = chr(0x391+$i)} = "\\ensuremath{\\\u$_}";
		$i++;
	}
	# lamda/lambda
	$TEX_GREEK{"\\lamda"} = $LATEX_Escapes_inv{"\\lambda"};
	$TEX_GREEK{"\\Lamda"} = $LATEX_Escapes_inv{"\\Lambda"};
	# Remove Greek letters that aren't available in TeX
	# http://www.artofproblemsolving.com/Wiki/index.php/LaTeX:Symbols
	for(qw( omicron Alpha Beta Epsilon Zeta Eta Iota Kappa Mu Nu Omicron Rho Varsigma Tau Chi Omega ))
	{
		delete $GREEK{delete $TEX_GREEK{"\\$_"}};
	}
}
 
%MATH_CHARS = (
	# Sets, http://www.unicode.org/charts/PDF/Unicode-4.1/U41-2100.pdf
	'N' => chr(0x2115),
	'R' => chr(0x211d),
	'Z' => chr(0x2124),
);

%MATH = (
	# 'sin' => 'sin', # sin (should be romanised), other trigonometric functions???
	chr(0x2192) => '\\to', # -->
	chr(0x2190) => '\\leftarrow', # <--
	chr(0x2192) => '\\rightarrow', # -->
	chr(0x2248) => '\\approx', # &asymp; Approximately equal to
	chr(0x2272) => '\\lesssim', # May not exist!
	chr(0x2273) => '\\gtrsim', # May not exist!
	chr(0x2243) => '\\simeq',
	chr(0x2264) => '\\leq',
	chr(0x00b1) => '\\pm', # &plusmn; Plus-minus
	chr(0x00d7) => '\\times', # &times; Times
	chr(0x2299) => '\\odot', # odot
	chr(0x222b) => '\\int', # integral
	chr(0x221a) => '\\sqrt', # square root
	chr(0x223c) => '\\sim', # tilda/mathematical similar
	chr(0x22c5) => '\\cdot', # dot
);

# derived mappings
use vars qw( %CHAR_MAP $CHAR_MAP_RE );

%CHAR_MAP = (%CHARS, %ACCENTED_CHARS, %GREEK);
for(keys %MATH)
{
	$CHAR_MAP{$_} ||= '$' . $MATH{$_} . '$';
}
for(keys %MATH_CHARS)
{
	$CHAR_MAP{$MATH_CHARS{$_}} ||= '$' . $_ . '$';
}

$CHAR_MAP_RE = '[' . join('', map { quotemeta($_) } sort { length($b) <=> length($a) } keys %CHAR_MAP) . ']';

use vars qw( $RESERVED_RE $BIBTEX_RESERVED_RE );

$RESERVED_RE = '[' . join('', map { quotemeta($_) } sort { length($b) <=> length($a) } keys %RESERVED) . ']';
$BIBTEX_RESERVED_RE = '[' . join('', map { quotemeta($_) } sort { length($b) <=> length($a) } keys %BIBTEX_RESERVED) . ']';

use vars qw( %MACROS $MACROS_RE );

%MACROS = (
	reverse(%RESERVED),
	reverse(%CHARS),
	reverse(%ACCENTED_CHARS),
	reverse(%MATH),
	%TEX_GREEK,
	%LATEX_MACROS
);

$MACROS_RE = join('|', map { "(?:$_)" } map { quotemeta($_) } sort { length($b) <=> length($a) } keys %MACROS);

use vars qw( $MATH_CHARS_RE );

$MATH_CHARS_RE = '[' . join('', map { quotemeta($_) } sort { length($b) <=> length($a) } keys %MATH_CHARS) . ']';

1;
