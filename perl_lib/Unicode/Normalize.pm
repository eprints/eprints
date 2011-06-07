package Unicode::Normalize;

BEGIN {
    unless ("A" eq pack('U', 0x41)) {
	die "Unicode::Normalize cannot stringify a Unicode code point\n";
    }
}

use 5.006;
use strict;
use warnings;
use Carp;
use File::Spec;

our $VERSION = '0.23';
our $PACKAGE = __PACKAGE__;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw( NFC NFD NFKC NFKD );
our @EXPORT_OK = qw(
    normalize decompose reorder compose
    checkNFD checkNFKD checkNFC checkNFKC check
    getCanon getCompat getComposite getCombinClass
    isExclusion isSingleton isNonStDecomp isComp2nd isComp_Ex
    isNFD_NO isNFC_NO isNFC_MAYBE isNFKD_NO isNFKC_NO isNFKC_MAYBE
);
our %EXPORT_TAGS = (
    all       => [ @EXPORT, @EXPORT_OK ],
    normalize => [ @EXPORT, qw/normalize decompose reorder compose/ ],
    check     => [ qw/checkNFD checkNFKD checkNFC checkNFKC check/ ],
);

##########
use constant SBase  => 0xAC00;
use constant SFinal => 0xD7A3; # SBase -1 + SCount
use constant SCount =>  11172; # LCount * NCount
use constant NCount =>    588; # VCount * TCount
use constant LBase  => 0x1100;
use constant LFinal => 0x1112;
use constant LCount =>     19;
use constant VBase  => 0x1161;
use constant VFinal => 0x1175;
use constant VCount =>     21;
use constant TBase  => 0x11A7;
use constant TFinal => 0x11C2;
use constant TCount =>     28;

our $Combin = do "unicore/CombiningClass.pl"
    || do "unicode/CombiningClass.pl"
    || croak "$PACKAGE: CombiningClass.pl not found";

our $Decomp = do "unicore/Decomposition.pl"
    || do "unicode/Decomposition.pl"
    || croak "$PACKAGE: Decomposition.pl not found";

our %Combin;	# $codepoint => $number    : combination class
our %Canon;	# $codepoint => \@codepoints : canonical decomp.
our %Compat;	# $codepoint => \@codepoints : compat. decomp.
our %Exclus;	# $codepoint => 1          : composition exclusions
our %Single;	# $codepoint => 1          : singletons
our %NonStD;	# $codepoint => 1          : non-starter decompositions

our %Comp2nd;	# $codepoint => 1          : may be composed with a prev char.
our %Compos;	# $1st,$2nd  => $codepoint : composite

{
    my($f, $fh);
    foreach my $d (@INC) {
	$f = File::Spec->catfile($d, "unicore", "CompositionExclusions.txt");
	last if open($fh, $f);
	$f = File::Spec->catfile($d, "unicore", "CompExcl.txt");
	last if open($fh, $f);
	$f = File::Spec->catfile($d, "unicode", "CompExcl.txt");
	last if open($fh, $f);
	$f = undef;
    }
    croak "$PACKAGE: CompExcl.txt not found in @INC" unless defined $f;

    while (<$fh>) {
	next if /^#/ or /^$/;
	s/#.*//;
	$Exclus{ hex($1) } = 1 if /([0-9A-Fa-f]+)/;
    }
    close $fh;
}

##
## converts string "hhhh hhhh hhhh" to a numeric list
##
sub _getHexArray { map hex, $_[0] =~ /([0-9A-Fa-f]+)/g }


######

while ($Combin =~ /(.+)/g) {
    my @tab = split /\t/, $1;
    my $ini = hex $tab[0];
    if ($tab[1] eq '') {
	$Combin{ $ini } = $tab[2];
    } else {
	$Combin{ $_ } = $tab[2] foreach $ini .. hex($tab[1]);
    }
}

while ($Decomp =~ /(.+)/g) {
    my @tab = split /\t/, $1;
    my $compat = $tab[2] =~ s/<[^>]+>//;
    my $dec = [ _getHexArray($tab[2]) ]; # decomposition
    my $ini = hex($tab[0]); # initial decomposable character

    if ($tab[1] eq '') {
	$Compat{ $ini } = $dec;

	if (! $compat) {
	    $Canon{ $ini } = $dec;

	    if (@$dec == 2) {
		if ($Combin{ $dec->[0] }) {
		    $NonStD{ $ini } = 1;
		} else {
		    $Compos{ $dec->[0] }{ $dec->[1] } = $ini;
		    $Comp2nd{ $dec->[1] } = 1 if ! $Exclus{$ini};
		}
	    } elsif (@$dec == 1) {
		$Single{ $ini } = 1;
	    } else {
		croak("Weird Canonical Decomposition of U+$tab[0]");
	    }
	}
    } else {
	foreach my $u ($ini .. hex($tab[1])) {
	    $Compat{ $u } = $dec;

	    if (! $compat) {
		$Canon{ $u } = $dec;

		if (@$dec == 2) {
		    if ($Combin{ $dec->[0] }) {
			$NonStD{ $u } = 1;
		    } else {
			$Compos{ $dec->[0] }{ $dec->[1] } = $u;
			$Comp2nd{ $dec->[1] } = 1 if ! $Exclus{$u};
		    }
		} elsif (@$dec == 1) {
		    $Single{ $u } = 1;
		} else {
		    croak("Weird Canonical Decomposition of U+$tab[0]");
		}
	    }
	}
    }
}

# modern HANGUL JUNGSEONG and HANGUL JONGSEONG jamo
foreach my $j (0x1161..0x1175, 0x11A8..0x11C2) {
    $Comp2nd{$j} = 1;
}

sub getCanonList {
    my @src = @_;
    my @dec = map {
	(SBase <= $_ && $_ <= SFinal) ? decomposeHangul($_)
	    : $Canon{$_} ? @{ $Canon{$_} } : $_
		} @src;
    return join(" ",@src) eq join(" ",@dec) ? @dec : getCanonList(@dec);
    # condition @src == @dec is not ok.
}

sub getCompatList {
    my @src = @_;
    my @dec =  map {
	(SBase <= $_ && $_ <= SFinal) ? decomposeHangul($_)
	    : $Compat{$_} ? @{ $Compat{$_} } : $_
		} @src;
    return join(" ",@src) eq join(" ",@dec) ? @dec : getCompatList(@dec);
    # condition @src == @dec is not ok.
}

# exhaustive decomposition
foreach my $key (keys %Canon) {
    $Canon{$key}  = [ getCanonList($key) ];
}

# exhaustive decomposition
foreach my $key (keys %Compat) {
    $Compat{$key} = [ getCompatList($key) ];
}

######

sub pack_U {
    return pack('U*', @_);
}

sub unpack_U {
    return unpack('U*', pack('U*').shift);
}

######

sub getHangulComposite ($$) {
    if ((LBase <= $_[0] && $_[0] <= LFinal)
     && (VBase <= $_[1] && $_[1] <= VFinal)) {
	my $lindex = $_[0] - LBase;
	my $vindex = $_[1] - VBase;
	return (SBase + ($lindex * VCount + $vindex) * TCount);
    }
    if ((SBase <= $_[0] && $_[0] <= SFinal && (($_[0] - SBase ) % TCount) == 0)
     && (TBase  < $_[1] && $_[1] <= TFinal)) {
	return($_[0] + $_[1] - TBase);
    }
    return undef;
}

sub decomposeHangul {
    my $SIndex = $_[0] - SBase;
    my $LIndex = int( $SIndex / NCount);
    my $VIndex = int(($SIndex % NCount) / TCount);
    my $TIndex =      $SIndex % TCount;
    my @ret = (
       LBase + $LIndex,
       VBase + $VIndex,
      $TIndex ? (TBase + $TIndex) : (),
    );
    wantarray ? @ret : pack_U(@ret);
}

##########

sub getCombinClass ($) {
    my $uv = 0 + shift;
    return $Combin{$uv} || 0;
}

sub getCanon ($) {
    my $uv = 0 + shift;
    return exists $Canon{$uv}
	? pack_U(@{ $Canon{$uv} })
	: (SBase <= $uv && $uv <= SFinal)
	    ? scalar decomposeHangul($uv)
	    : undef;
}

sub getCompat ($) {
    my $uv = 0 + shift;
    return exists $Compat{$uv}
	? pack_U(@{ $Compat{$uv} })
	: (SBase <= $uv && $uv <= SFinal)
	    ? scalar decomposeHangul($uv)
	    : undef;
}

sub getComposite ($$) {
    my $uv1 = 0 + shift;
    my $uv2 = 0 + shift;
    my $hangul = getHangulComposite($uv1, $uv2);
    return $hangul if $hangul;
    return $Compos{ $uv1 } && $Compos{ $uv1 }{ $uv2 };
}

sub isExclusion  ($) {
    my $uv = 0 + shift;
    return exists $Exclus{$uv};
}

sub isSingleton  ($) {
    my $uv = 0 + shift;
    return exists $Single{$uv};
}

sub isNonStDecomp($) {
    my $uv = 0 + shift;
    return exists $NonStD{$uv};
}

sub isComp2nd ($) {
    my $uv = 0 + shift;
    return exists $Comp2nd{$uv};
}

sub isNFC_MAYBE ($) {
    my $uv = 0 + shift;
    return exists $Comp2nd{$uv};
}

sub isNFKC_MAYBE($) {
    my $uv = 0 + shift;
    return exists $Comp2nd{$uv};
}

sub isNFD_NO ($) {
    my $uv = 0 + shift;
    return exists $Canon {$uv} || (SBase <= $uv && $uv <= SFinal);
}

sub isNFKD_NO ($) {
    my $uv = 0 + shift;
    return exists $Compat{$uv} || (SBase <= $uv && $uv <= SFinal);
}

sub isComp_Ex ($) {
    my $uv = 0 + shift;
    return exists $Exclus{$uv} || exists $Single{$uv} || exists $NonStD{$uv};
}

sub isNFC_NO ($) {
    my $uv = 0 + shift;
    return exists $Exclus{$uv} || exists $Single{$uv} || exists $NonStD{$uv};
}

sub isNFKC_NO ($) {
    my $uv = 0 + shift;
    return 1  if $Exclus{$uv} || $Single{$uv} || $NonStD{$uv};
    return '' if (SBase <= $uv && $uv <= SFinal) || !exists $Compat{$uv};
    return 1  if ! exists $Canon{$uv};
    return pack('N*', @{ $Canon{$uv} }) ne pack('N*', @{ $Compat{$uv} });
}

##
## string decompose(string, compat?)
##
sub decompose ($;$)
{
    my $hash = $_[1] ? \%Compat : \%Canon;
    return pack_U map {
	$hash->{ $_ } ? @{ $hash->{ $_ } } :
	    (SBase <= $_ && $_ <= SFinal) ? decomposeHangul($_) : $_
    } unpack_U($_[0]);
}

##
## string reorder(string)
##
sub reorder ($)
{
    my @src = unpack_U($_[0]);

    for (my $i=0; $i < @src;) {
	$i++, next if ! $Combin{ $src[$i] };

	my $ini = $i;
	$i++ while $i < @src && $Combin{ $src[$i] };

        my @tmp = sort {
		$Combin{ $src[$a] } <=> $Combin{ $src[$b] } || $a <=> $b
	    } $ini .. $i - 1;

	@src[ $ini .. $i - 1 ] = @src[ @tmp ];
    }
    return pack_U(@src);
}


##
## string compose(string)
##
## S : starter; NS : not starter;
##
## composable sequence begins at S.
## S + S or (S + S) + S may be composed.
## NS + NS must not be composed.
##
sub compose ($)
{
    my @src = unpack_U($_[0]);

    for (my $s = 0; $s+1 < @src; $s++) {
	next unless defined $src[$s] && ! $Combin{ $src[$s] };
	 # S only; removed or combining are skipped as a starter.

	my($c, $blocked, $uncomposed_cc);
	for (my $j = $s+1; $j < @src && !$blocked; $j++) {
	    ($Combin{ $src[$j] } ? $uncomposed_cc : $blocked) = 1;

	    # S + C + S => S-S + C would be blocked.
	    next if $blocked && $uncomposed_cc;

	    # blocked by same CC
	    next if defined $src[$j-1]   && $Combin{ $src[$j-1] }
		&& $Combin{ $src[$j-1] } == $Combin{ $src[$j] };

	    $c = getComposite($src[$s], $src[$j]);

	    # no composite or is exclusion
	    next if !$c || $Exclus{$c};

	    # replace by composite
	    $src[$s] = $c; $src[$j] = undef;
	    if ($blocked) { $blocked = 0 } else { -- $uncomposed_cc }
	}
    }
    return pack_U(grep defined(), @src);
}

##
## normalization forms
##

use constant COMPAT => 1;

sub NFD  ($) { reorder(decompose($_[0])) }
sub NFKD ($) { reorder(decompose($_[0], COMPAT)) }
sub NFC  ($) { compose(reorder(decompose($_[0]))) }
sub NFKC ($) { compose(reorder(decompose($_[0], COMPAT))) }

sub normalize($$)
{
    my $form = shift;
    my $str = shift;
    $form =~ s/^NF//;
    return
	$form eq 'D'  ? NFD ($str) :
	$form eq 'C'  ? NFC ($str) :
	$form eq 'KD' ? NFKD($str) :
	$form eq 'KC' ? NFKC($str) :
      croak $PACKAGE."::normalize: invalid form name: $form";
}


##
## quick check
##
sub checkNFD ($)
{
    my $preCC = 0;
    my $curCC;
    for my $uv (unpack_U($_[0])) {
	$curCC = $Combin{ $uv } || 0;
	return '' if $preCC > $curCC && $curCC != 0;
	return '' if exists $Canon{$uv} || (SBase <= $uv && $uv <= SFinal);
	$preCC = $curCC;
    }
    return 1;
}

sub checkNFKD ($)
{
    my $preCC = 0;
    my $curCC;
    for my $uv (unpack_U($_[0])) {
	$curCC = $Combin{ $uv } || 0;
	return '' if $preCC > $curCC && $curCC != 0;
	return '' if exists $Compat{$uv} || (SBase <= $uv && $uv <= SFinal);
	$preCC = $curCC;
    }
    return 1;
}

sub checkNFC ($)
{
    my $preCC = 0;
    my($curCC, $isMAYBE);
    for my $uv (unpack_U($_[0])) {
	$curCC = $Combin{ $uv } || 0;
	return '' if $preCC > $curCC && $curCC != 0;

	if (isNFC_MAYBE($uv)) {
	    $isMAYBE = 1;
	} elsif (isNFC_NO($uv)) {
	    return '';
	}
	$preCC = $curCC;
    }
    return $isMAYBE ? undef : 1;
}

sub checkNFKC ($)
{
    my $preCC = 0;
    my($curCC, $isMAYBE);
    for my $uv (unpack_U($_[0])) {
	$curCC = $Combin{ $uv } || 0;
	return '' if $preCC > $curCC && $curCC != 0;

	if (isNFKC_MAYBE($uv)) {
	    $isMAYBE = 1;
	} elsif (isNFKC_NO($uv)) {
	    return '';
	}
	$preCC = $curCC;
    }
    return $isMAYBE ? undef : 1;
}

sub check($$)
{
    my $form = shift;
    my $str = shift;
    $form =~ s/^NF//;
    return
	$form eq 'D'  ? checkNFD ($str) :
	$form eq 'C'  ? checkNFC ($str) :
	$form eq 'KD' ? checkNFKD($str) :
	$form eq 'KC' ? checkNFKC($str) :
      croak $PACKAGE."::check: invalid form name: $form";
}

1;
__END__

=head1 NAME

Unicode::Normalize - Unicode Normalization Forms

=head1 SYNOPSIS

  use Unicode::Normalize;

  $NFD_string  = NFD($string);  # Normalization Form D
  $NFC_string  = NFC($string);  # Normalization Form C
  $NFKD_string = NFKD($string); # Normalization Form KD
  $NFKC_string = NFKC($string); # Normalization Form KC

   or

  use Unicode::Normalize 'normalize';

  $NFD_string  = normalize('D',  $string);  # Normalization Form D
  $NFC_string  = normalize('C',  $string);  # Normalization Form C
  $NFKD_string = normalize('KD', $string);  # Normalization Form KD
  $NFKC_string = normalize('KC', $string);  # Normalization Form KC

=head1 DESCRIPTION

Parameters:

C<$string> is used as a string under character semantics
(see F<perlunicode>).

C<$codepoint> should be an unsigned integer
representing a Unicode code point.

Note: Between XS edition and pure Perl edition,
interpretation of C<$codepoint> as a decimal number has incompatibility.
XS converts C<$codepoint> to an unsigned integer, but pure Perl does not.
Do not use a floating point nor a negative sign in C<$codepoint>.

=head2 Normalization Forms

=over 4

=item C<$NFD_string = NFD($string)>

returns the Normalization Form D (formed by canonical decomposition).

=item C<$NFC_string = NFC($string)>

returns the Normalization Form C (formed by canonical decomposition
followed by canonical composition).

=item C<$NFKD_string = NFKD($string)>

returns the Normalization Form KD (formed by compatibility decomposition).

=item C<$NFKC_string = NFKC($string)>

returns the Normalization Form KC (formed by compatibility decomposition
followed by B<canonical> composition).

=item C<$normalized_string = normalize($form_name, $string)>

As C<$form_name>, one of the following names must be given.

  'C'  or 'NFC'  for Normalization Form C
  'D'  or 'NFD'  for Normalization Form D
  'KC' or 'NFKC' for Normalization Form KC
  'KD' or 'NFKD' for Normalization Form KD

=back

=head2 Decomposition and Composition

=over 4

=item C<$decomposed_string = decompose($string)>

=item C<$decomposed_string = decompose($string, $useCompatMapping)>

Decomposes the specified string and returns the result.

If the second parameter (a boolean) is omitted or false, decomposes it
using the Canonical Decomposition Mapping.
If true, decomposes it using the Compatibility Decomposition Mapping.

The string returned is not always in NFD/NFKD.
Reordering may be required.

    $NFD_string  = reorder(decompose($string));       # eq. to NFD()
    $NFKD_string = reorder(decompose($string, TRUE)); # eq. to NFKD()

=item C<$reordered_string  = reorder($string)>

Reorders the combining characters and the like in the canonical ordering
and returns the result.

E.g., when you have a list of NFD/NFKD strings,
you can get the concatenated NFD/NFKD string from them, saying

    $concat_NFD  = reorder(join '', @NFD_strings);
    $concat_NFKD = reorder(join '', @NFKD_strings);

=item C<$composed_string   = compose($string)>

Returns the string where composable pairs are composed.

E.g., when you have a NFD/NFKD string,
you can get its NFC/NFKC string, saying

    $NFC_string  = compose($NFD_string);
    $NFKC_string = compose($NFKD_string);

=back

=head2 Quick Check

(see Annex 8, UAX #15; F<DerivedNormalizationProps.txt>)

The following functions check whether the string is in that normalization form.

The result returned will be:

    YES     The string is in that normalization form.
    NO      The string is not in that normalization form.
    MAYBE   Dubious. Maybe yes, maybe no.

=over 4

=item C<$result = checkNFD($string)>

returns C<YES> (C<1>) or C<NO> (C<empty string>).

=item C<$result = checkNFC($string)>

returns C<YES> (C<1>), C<NO> (C<empty string>), or C<MAYBE> (C<undef>).

=item C<$result = checkNFKD($string)>

returns C<YES> (C<1>) or C<NO> (C<empty string>).

=item C<$result = checkNFKC($string)>

returns C<YES> (C<1>), C<NO> (C<empty string>), or C<MAYBE> (C<undef>).

=item C<$result = check($form_name, $string)>

returns C<YES> (C<1>), C<NO> (C<empty string>), or C<MAYBE> (C<undef>).

C<$form_name> is alike to that for C<normalize()>.

=back

B<Note>

In the cases of NFD and NFKD, the answer must be either C<YES> or C<NO>.
The answer C<MAYBE> may be returned in the cases of NFC and NFKC.

A MAYBE-NFC/NFKC string should contain at least
one combining character or the like.
For example, C<COMBINING ACUTE ACCENT> has
the MAYBE_NFC/MAYBE_NFKC property.
Both C<checkNFC("A\N{COMBINING ACUTE ACCENT}")>
and C<checkNFC("B\N{COMBINING ACUTE ACCENT}")> will return C<MAYBE>.
C<"A\N{COMBINING ACUTE ACCENT}"> is not in NFC
(its NFC is C<"\N{LATIN CAPITAL LETTER A WITH ACUTE}">),
while C<"B\N{COMBINING ACUTE ACCENT}"> is in NFC.

If you want to check exactly, compare the string with its NFC/NFKC; i.e.,

    $string eq NFC($string)    # more thorough than checkNFC($string)
    $string eq NFKC($string)   # more thorough than checkNFKC($string)

=head2 Character Data

These functions are interface of character data used internally.
If you want only to get Unicode normalization forms, you don't need
call them yourself.

=over 4

=item C<$canonical_decomposed = getCanon($codepoint)>

If the character of the specified codepoint is canonically
decomposable (including Hangul Syllables),
returns the B<completely decomposed> string canonically equivalent to it.

If it is not decomposable, returns C<undef>.

=item C<$compatibility_decomposed = getCompat($codepoint)>

If the character of the specified codepoint is compatibility
decomposable (including Hangul Syllables),
returns the B<completely decomposed> string compatibility equivalent to it.

If it is not decomposable, returns C<undef>.

=item C<$codepoint_composite = getComposite($codepoint_here, $codepoint_next)>

If two characters here and next (as codepoints) are composable
(including Hangul Jamo/Syllables and Composition Exclusions),
returns the codepoint of the composite.

If they are not composable, returns C<undef>.

=item C<$combining_class = getCombinClass($codepoint)>

Returns the combining class of the character as an integer.

=item C<$is_exclusion = isExclusion($codepoint)>

Returns a boolean whether the character of the specified codepoint
is a composition exclusion.

=item C<$is_singleton = isSingleton($codepoint)>

Returns a boolean whether the character of the specified codepoint is
a singleton.

=item C<$is_non_starter_decomposition = isNonStDecomp($codepoint)>

Returns a boolean whether the canonical decomposition
of the character of the specified codepoint
is a Non-Starter Decomposition.

=item C<$may_be_composed_with_prev_char = isComp2nd($codepoint)>

Returns a boolean whether the character of the specified codepoint
may be composed with the previous one in a certain composition
(including Hangul Compositions, but excluding
Composition Exclusions and Non-Starter Decompositions).

=back

=head2 EXPORT

C<NFC>, C<NFD>, C<NFKC>, C<NFKD>: by default.

C<normalize> and other some functions: on request.

=head1 AUTHOR

SADAHIRO Tomoyuki, E<lt>SADAHIRO@cpan.orgE<gt>

  http://homepage1.nifty.com/nomenclator/perl/

  Copyright(C) 2001-2003, SADAHIRO Tomoyuki. Japan. All rights reserved.

  This module is free software; you can redistribute it
  and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item http://www.unicode.org/unicode/reports/tr15/

Unicode Normalization Forms - UAX #15

=item http://www.unicode.org/Public/UNIDATA/DerivedNormalizationProps.txt

Derived Normalization Properties

=back

=cut

