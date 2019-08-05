package LaTeX::ToUnicode::Tables;
BEGIN {
  $LaTeX::ToUnicode::Tables::VERSION = '0.05';
}
use strict;
use warnings;
#ABSTRACT: Character tables for LaTeX::ToUnicode

use utf8;


our %COMMANDS = (
    'LaTeX'     => 'LaTeX',
    'TeX'     => 'TEX',
    '-'         => '', # hypenation
    '/'         => '', # italic correction
    'log'       => 'log',
);


our @SPECIALS = ( qw( $ % & _ { } ), '#' );


our %SYMBOLS = ( # Table 3.2 in Lamport
    'aa'	=> 'å',
    'AA'	=> 'Å',
    'ae'	=> 'æ',
    'AE'	=> 'Æ',
    'dh'	=> 'ð',
    'DH'	=> 'Ð',
    'dj'	=> 'đ',
    'DJ'	=> 'Ð',
    'i'         => chr(0x131), # small dotless i
    'l'	        => 'ł',
    'L'	        => 'Ł',
    'ng'	=> 'ŋ',
    'NG'	=> 'Ŋ',
    'oe'	=> 'œ',
    'OE'	=> 'Œ',
    'o'	        => 'ø',
    'O'         => 'Ø',
    'ss'	=> 'ß',
    'SS'	=> 'SS',
    'th'	=> 'þ',
    'TH'	=> 'Þ',
    'TM'        => chr(0x2122),
);


our %ACCENTS = (
  "\"" => {
    A => "\304",
    E => "\313",
    H => "\x{1e26}",
    I => "\317",
    O => "\326",
    U => "\334",
    W => "\x{1e84}",
    X => "\x{1e8c}",
    Y => "\x{178}",
    "\\I" => "\317",
    "\\i" => "\357",
    a => "\344",
    e => "\353",
    h => "\x{1e27}",
    i => "\357",
    o => "\366",
    t => "\x{1e97}",
    u => "\374",
    w => "\x{1e85}",
    x => "\x{1e8d}",
    y => "\377"
  },
  "'" => {
    A => "\301",
    AE => "\x{1fc}",
    C => "\x{106}",
    E => "\311",
    G => "\x{1f4}",
    I => "\315",
    K => "\x{1e30}",
    L => "\x{139}",
    M => "\x{1e3e}",
    N => "\x{143}",
    O => "\323",
    P => "\x{1e54}",
    R => "\x{154}",
    S => "\x{15a}",
    U => "\332",
    W => "\x{1e82}",
    Y => "\335",
    Z => "\x{179}",
    "\\I" => "\315",
    "\\i" => "\355",
    a => "\341",
    ae => "\x{1fd}",
    c => "\x{107}",
    e => "\351",
    g => "\x{1f5}",
    i => "\355",
    k => "\x{1e31}",
    l => "\x{13a}",
    m => "\x{1e3f}",
    n => "\x{144}",
    o => "\363",
    p => "\x{1e55}",
    r => "\x{155}",
    s => "\x{15b}",
    u => "\372",
    w => "\x{1e83}",
    y => "\375",
    z => "\x{17a}"
  },
  "." => {
    A => "\x{226}",
    B => "\x{1e02}",
    C => "\x{10a}",
    D => "\x{1e0a}",
    E => "\x{116}",
    F => "\x{1e1e}",
    G => "\x{120}",
    H => "\x{1e22}",
    I => "\x{130}",
    M => "\x{1e40}",
    N => "\x{1e44}",
    O => "\x{22e}",
    P => "\x{1e56}",
    R => "\x{1e58}",
    S => "\x{1e60}",
    T => "\x{1e6a}",
    W => "\x{1e86}",
    X => "\x{1e8a}",
    Y => "\x{1e8e}",
    Z => "\x{17b}",
    "\\I" => "\x{130}",
    a => "\x{227}",
    b => "\x{1e03}",
    c => "\x{10b}",
    d => "\x{1e0b}",
    e => "\x{117}",
    f => "\x{1e1f}",
    g => "\x{121}",
    h => "\x{1e23}",
    m => "\x{1e41}",
    n => "\x{1e45}",
    o => "\x{22f}",
    p => "\x{1e57}",
    r => "\x{1e59}",
    s => "\x{1e61}",
    t => "\x{1e6b}",
    w => "\x{1e87}",
    x => "\x{1e8b}",
    y => "\x{1e8f}",
    z => "\x{17c}"
  },
  '=' => {
    A => "\x{100}",
    AE => "\x{1e2}",
    E => "\x{112}",
    G => "\x{1e20}",
    I => "\x{12a}",
    O => "\x{14c}",
    U => "\x{16a}",
    Y => "\x{232}",
    "\\I" => "\x{12a}",
    "\\i" => "\x{12b}",
    a => "\x{101}",
    ae => "\x{1e3}",
    e => "\x{113}",
    g => "\x{1e21}",
    i => "\x{12b}",
    o => "\x{14d}",
    u => "\x{16b}",
    y => "\x{233}"
  },
  H => {
    O => "\x{150}",
    U => "\x{170}",
    o => "\x{151}",
    u => "\x{171}"
  },
  "^" => {
    A => "\302",
    C => "\x{108}",
    E => "\312",
    G => "\x{11c}",
    H => "\x{124}",
    I => "\316",
    J => "\x{134}",
    O => "\324",
    S => "\x{15c}",
    U => "\333",
    W => "\x{174}",
    Y => "\x{176}",
    Z => "\x{1e90}",
    "\\I" => "\316",
    "\\i" => "\356",
    a => "\342",
    c => "\x{109}",
    e => "\352",
    g => "\x{11d}",
    h => "\x{125}",
    i => "\356",
    j => "\x{135}",
    o => "\364",
    s => "\x{15d}",
    u => "\373",
    w => "\x{175}",
    y => "\x{177}",
    z => "\x{1e91}"
  },
  "`" => {
    A => "\300",
    E => "\310",
    I => "\314",
    N => "\x{1f8}",
    O => "\322",
    U => "\331",
    W => "\x{1e80}",
    Y => "\x{1ef2}",
    "\\I" => "\314",
    "\\i" => "\354",
    a => "\340",
    e => "\350",
    i => "\354",
    n => "\x{1f9}",
    o => "\362",
    u => "\371",
    w => "\x{1e81}",
    y => "\x{1ef3}"
  },
  c => {
    C => "\307",
    D => "\x{1e10}",
    E => "\x{228}",
    G => "\x{122}",
    H => "\x{1e28}",
    K => "\x{136}",
    L => "\x{13b}",
    N => "\x{145}",
    R => "\x{156}",
    S => "\x{15e}",
    T => "\x{162}",
    c => "\347",
    d => "\x{1e11}",
    e => "\x{229}",
    g => "\x{123}",
    h => "\x{1e29}",
    k => "\x{137}",
    l => "\x{13c}",
    n => "\x{146}",
    r => "\x{157}",
    s => "\x{15f}",
    t => "\x{163}"
  },
  d => {
    A => "\x{1ea0}",
    B => "\x{1e04}",
    D => "\x{1e0c}",
    E => "\x{1eb8}",
    H => "\x{1e24}",
    I => "\x{1eca}",
    K => "\x{1e32}",
    L => "\x{1e36}",
    M => "\x{1e42}",
    N => "\x{1e46}",
    O => "\x{1ecc}",
    R => "\x{1e5a}",
    S => "\x{1e62}",
    T => "\x{1e6c}",
    U => "\x{1ee4}",
    V => "\x{1e7e}",
    W => "\x{1e88}",
    Y => "\x{1ef4}",
    Z => "\x{1e92}",
    "\\I" => "\x{1eca}",
    "\\i" => "\x{1ecb}",
    a => "\x{1ea1}",
    b => "\x{1e05}",
    d => "\x{1e0d}",
    e => "\x{1eb9}",
    h => "\x{1e25}",
    i => "\x{1ecb}",
    k => "\x{1e33}",
    l => "\x{1e37}",
    m => "\x{1e43}",
    n => "\x{1e47}",
    o => "\x{1ecd}",
    r => "\x{1e5b}",
    s => "\x{1e63}",
    t => "\x{1e6d}",
    u => "\x{1ee5}",
    v => "\x{1e7f}",
    w => "\x{1e89}",
    y => "\x{1ef5}",
    z => "\x{1e93}"
  },
  h => {
    A => "\x{1ea2}",
    E => "\x{1eba}",
    I => "\x{1ec8}",
    O => "\x{1ece}",
    U => "\x{1ee6}",
    Y => "\x{1ef6}",
    "\\I" => "\x{1ec8}",
    "\\i" => "\x{1ec9}",
    a => "\x{1ea3}",
    e => "\x{1ebb}",
    i => "\x{1ec9}",
    o => "\x{1ecf}",
    u => "\x{1ee7}",
    y => "\x{1ef7}"
  },
  k => {
    A => "\x{104}",
    E => "\x{118}",
    I => "\x{12e}",
    O => "\x{1ea}",
    U => "\x{172}",
    "\\I" => "\x{12e}",
    "\\i" => "\x{12f}",
    a => "\x{105}",
    e => "\x{119}",
    i => "\x{12f}",
    o => "\x{1eb}",
    u => "\x{173}"
  },
  r => {
    A => "\305",
    U => "\x{16e}",
    a => "\345",
    u => "\x{16f}",
    w => "\x{1e98}",
    y => "\x{1e99}"
  },
  u => {
    A => "\x{102}",
    E => "\x{114}",
    G => "\x{11e}",
    I => "\x{12c}",
    O => "\x{14e}",
    U => "\x{16c}",
    "\\I" => "\x{12c}",
    "\\i" => "\x{12d}",
    a => "\x{103}",
    e => "\x{115}",
    g => "\x{11f}",
    i => "\x{12d}",
    o => "\x{14f}",
    u => "\x{16d}"
  },
  v => {
    A => "\x{1cd}",
    C => "\x{10c}",
    D => "\x{10e}",
    DZ => "\x{1c4}",
    E => "\x{11a}",
    G => "\x{1e6}",
    H => "\x{21e}",
    I => "\x{1cf}",
    K => "\x{1e8}",
    L => "\x{13d}",
    N => "\x{147}",
    O => "\x{1d1}",
    R => "\x{158}",
    S => "\x{160}",
    T => "\x{164}",
    U => "\x{1d3}",
    Z => "\x{17d}",
    "\\I" => "\x{1cf}",
    "\\i" => "\x{1d0}",
    a => "\x{1ce}",
    c => "\x{10d}",
    d => "\x{10f}",
    dz => "\x{1c6}",
    e => "\x{11b}",
    g => "\x{1e7}",
    h => "\x{21f}",
    i => "\x{1d0}",
    j => "\x{1f0}",
    k => "\x{1e9}",
    l => "\x{13e}",
    n => "\x{148}",
    o => "\x{1d2}",
    r => "\x{159}",
    s => "\x{161}",
    t => "\x{165}",
    u => "\x{1d4}",
    z => "\x{17e}"
  },
  "~" => {
    A => "\303",
    E => "\x{1ebc}",
    I => "\x{128}",
    N => "\321",
    O => "\325",
    U => "\x{168}",
    V => "\x{1e7c}",
    Y => "\x{1ef8}",
    "\\I" => "\x{128}",
    "\\i" => "\x{129}",
    a => "\343",
    e => "\x{1ebd}",
    i => "\x{129}",
    n => "\361",
    o => "\365",
    u => "\x{169}",
    v => "\x{1e7d}",
    y => "\x{1ef9}"
  }
);


our %GERMAN = ( # for package `german'/`ngerman'
    '"a'	=> 'ä',
    '"A'	=> 'Ä',
    '"e'	=> 'ë',
    '"E'	=> 'Ë',
    '"i'	=> 'ï',
    '"I'	=> 'Ï',
    '"o'	=> 'ö',
    '"O'	=> 'Ö',
    '"u'	=> 'ü',
    '"U'	=> 'Ü',
    '"s'	=> 'ß',
    '"S'	=> 'SS',
    '"z'	=> 'ß',
    '"Z'	=> 'SZ',
    '"ck'	=> 'ck', # old spelling: ck -> k-k
    '"ff'	=> 'ff', # old spelling: ff -> ff-f
    '"`'	=> '„',
    "\"'"	=> '“',
    '"<'	=> '«',
    '">'	=> '»',
    '"-'	=> "\x{AD}", # soft hyphen
    '""'	=> "\x{200B}", # zero width space
    '"~'	=> "\x{2011}", # non-breaking hyphen
    '"='	=> '-',
    '\glq'      => '‚', # left german single quote
    '\grq'      => '‘', # right german single quote
    '\flqq'     => '«',
    '\frqq'     => '»',
    '\dq'       => '"',
);


our @MARKUPS = ( qw( em tt small sl bf sc rm it cal ) );

1;

__END__
=pod

=encoding utf-8

=head1 NAME

LaTeX::ToUnicode::Tables - Character tables for LaTeX::ToUnicode

=head1 VERSION

version 0.05

=head1 CONSTANTS

=head2 %COMMANDS

Names of argument-less commands like C<\LaTeX> as keys.
Values are the replacements.

=head2 @SPECIALS

TeX's metacharacters that need to be escaped in TeX documents

=head2 %SYMBOLS

Predefined escape commands for extended characters.

=head2 %ACCENTS

Two-level hash of accented characters like C<\'{a}>. The keys of this hash
are the accent symbols, e.g C<`>, C<"> or C<'>. The corresponding values are
references to hashes, where the keys are the base letters and the values are
the decoded characters. As an example, C<< $ACCENTS{'`'}->{a} eq 'à' >>.

=head2 %GERMAN

Escape sequences as defined by the package `german'/`ngerman', e.g.
C<"a> (a with umlaut), C<"s> (german sharp s) or C<"`"> (german left quote).
Note the missing backslash.

The keys of this hash are the literal escape sequences.

=head2 @MARKUPS

Command names of formatting commands like C<\tt>

=head1 AUTHOR

Gerhard Gossen <gerhard.gossen@googlemail.com> and Boris Veytsman <boris@varphi.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010-2015 by Gerhard Gossen and Boris Veytsman

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

