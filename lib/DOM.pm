################################################################################
#
# Perl module: EPrints::DOM
#
# By Enno Derksen (official maintainer), enno@att.com
# and Clark Cooper, coopercl@sch.ge.com
#
################################################################################
#
# To do:
#
# * BUG: setOwnerDocument - does not process default attr values correctly,
#   they still point to the old doc.
# * change Exception mechanism
# * entity expansion
# * maybe: more checking of sysId etc.
# * NoExpand mode (don't know what else is useful)
# * various odds and ends: see comments starting with "??"
# * normalize(1) should also expand CDataSections and EntityReferences
# * parse a DocumentFragment?
# * encoding support
# * someone reported an error that an Entity or something contained a single
#   quote and it printed ''' or something...
#
######################################################################

package Stat;
#?? Debugging class - remove later

sub cnt
{
    $cnt{$_[0]}++;
}

sub print
{
    for (keys %cnt)
    {
	print "$_: " . $cnt{$_} . "\n";
    }
}

######################################################################
package EPrints::DOM;
######################################################################

use strict;
use vars qw( $VERSION @ISA @EXPORT
	     $IgnoreReadOnly $SafeMode $TagStyle
	     %DefaultEntities %DecodeDefaultEntity
	     $ChBaseChar $ChIdeographic
	     $ChLetter $ChDigit $ChExtender $ChCombiningChar $ChNameChar 
	     $ReName $ReNmToken $ReEntityRef $ReCharRef $ReReference $ReAttValue
	   );
use Carp;

BEGIN
{
    require XML::Parser;
    $VERSION = '1.25';

    my $needVersion = '2.23';
    die "need at least XML::Parser version $needVersion (current=" .
		$XML::Parser::VERSION . ")"
	unless $XML::Parser::VERSION >= $needVersion;

    @ISA = qw( Exporter );
    @EXPORT = qw(
	     UNKNOWN_NODE
	     ELEMENT_NODE
	     ATTRIBUTE_NODE
	     TEXT_NODE
	     CDATA_SECTION_NODE
	     ENTITY_REFERENCE_NODE
	     ENTITY_NODE
	     PROCESSING_INSTRUCTION_NODE
	     COMMENT_NODE
	     DOCUMENT_NODE
	     DOCUMENT_TYPE_NODE
	     DOCUMENT_FRAGMENT_NODE
	     NOTATION_NODE
	     ELEMENT_DECL_NODE
	     ATT_DEF_NODE
	     XML_DECL_NODE
	     ATTLIST_DECL_NODE
	    );
}

#---- Constant definitions

# Node types

sub UNKNOWN_NODE                () {0;}		# not in the DOM Spec

sub ELEMENT_NODE                () {1;}
sub ATTRIBUTE_NODE              () {2;}
sub TEXT_NODE                   () {3;}
sub CDATA_SECTION_NODE          () {4;}
sub ENTITY_REFERENCE_NODE       () {5;}
sub ENTITY_NODE                 () {6;}
sub PROCESSING_INSTRUCTION_NODE () {7;}
sub COMMENT_NODE                () {8;}
sub DOCUMENT_NODE               () {9;}
sub DOCUMENT_TYPE_NODE          () {10;}
sub DOCUMENT_FRAGMENT_NODE      () {11;}
sub NOTATION_NODE               () {12;}

sub ELEMENT_DECL_NODE		() {13;}	# not in the DOM Spec
sub ATT_DEF_NODE 		() {14;}	# not in the DOM Spec
sub XML_DECL_NODE 		() {15;}	# not in the DOM Spec
sub ATTLIST_DECL_NODE		() {16;}	# not in the DOM Spec

#
# Definitions of the character classes and regular expressions as defined in the
# XML Spec.
# 
# NOTE: ChLetter maps to the 'Letter' definition in the XML Spec.
#

$ChBaseChar = '(?:[a-zA-Z]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|\xC4[\x80-\xB1\xB4-\xBE]|\xC5[\x81-\x88\x8A-\xBE]|\xC6[\x80-\xBF]|\xC7[\x80-\x83\x8D-\xB0\xB4\xB5\xBA-\xBF]|\xC8[\x80-\x97]|\xC9[\x90-\xBF]|\xCA[\x80-\xA8\xBB-\xBF]|\xCB[\x80\x81]|\xCE[\x86\x88-\x8A\x8C\x8E-\xA1\xA3-\xBF]|\xCF[\x80-\x8E\x90-\x96\x9A\x9C\x9E\xA0\xA2-\xB3]|\xD0[\x81-\x8C\x8E-\xBF]|\xD1[\x80-\x8F\x91-\x9C\x9E-\xBF]|\xD2[\x80\x81\x90-\xBF]|\xD3[\x80-\x84\x87\x88\x8B\x8C\x90-\xAB\xAE-\xB5\xB8\xB9]|\xD4[\xB1-\xBF]|\xD5[\x80-\x96\x99\xA1-\xBF]|\xD6[\x80-\x86]|\xD7[\x90-\xAA\xB0-\xB2]|\xD8[\xA1-\xBA]|\xD9[\x81-\x8A\xB1-\xBF]|\xDA[\x80-\xB7\xBA-\xBE]|\xDB[\x80-\x8E\x90-\x93\x95\xA5\xA6]|\xE0(?:\xA4[\x85-\xB9\xBD]|\xA5[\x98-\xA1]|\xA6[\x85-\x8C\x8F\x90\x93-\xA8\xAA-\xB0\xB2\xB6-\xB9]|\xA7[\x9C\x9D\x9F-\xA1\xB0\xB1]|\xA8[\x85-\x8A\x8F\x90\x93-\xA8\xAA-\xB0\xB2\xB3\xB5\xB6\xB8\xB9]|\xA9[\x99-\x9C\x9E\xB2-\xB4]|\xAA[\x85-\x8B\x8D\x8F-\x91\x93-\xA8\xAA-\xB0\xB2\xB3\xB5-\xB9\xBD]|\xAB\xA0|\xAC[\x85-\x8C\x8F\x90\x93-\xA8\xAA-\xB0\xB2\xB3\xB6-\xB9\xBD]|\xAD[\x9C\x9D\x9F-\xA1]|\xAE[\x85-\x8A\x8E-\x90\x92-\x95\x99\x9A\x9C\x9E\x9F\xA3\xA4\xA8-\xAA\xAE-\xB5\xB7-\xB9]|\xB0[\x85-\x8C\x8E-\x90\x92-\xA8\xAA-\xB3\xB5-\xB9]|\xB1[\xA0\xA1]|\xB2[\x85-\x8C\x8E-\x90\x92-\xA8\xAA-\xB3\xB5-\xB9]|\xB3[\x9E\xA0\xA1]|\xB4[\x85-\x8C\x8E-\x90\x92-\xA8\xAA-\xB9]|\xB5[\xA0\xA1]|\xB8[\x81-\xAE\xB0\xB2\xB3]|\xB9[\x80-\x85]|\xBA[\x81\x82\x84\x87\x88\x8A\x8D\x94-\x97\x99-\x9F\xA1-\xA3\xA5\xA7\xAA\xAB\xAD\xAE\xB0\xB2\xB3\xBD]|\xBB[\x80-\x84]|\xBD[\x80-\x87\x89-\xA9])|\xE1(?:\x82[\xA0-\xBF]|\x83[\x80-\x85\x90-\xB6]|\x84[\x80\x82\x83\x85-\x87\x89\x8B\x8C\x8E-\x92\xBC\xBE]|\x85[\x80\x8C\x8E\x90\x94\x95\x99\x9F-\xA1\xA3\xA5\xA7\xA9\xAD\xAE\xB2\xB3\xB5]|\x86[\x9E\xA8\xAB\xAE\xAF\xB7\xB8\xBA\xBC-\xBF]|\x87[\x80-\x82\xAB\xB0\xB9]|[\xB8\xB9][\x80-\xBF]|\xBA[\x80-\x9B\xA0-\xBF]|\xBB[\x80-\xB9]|\xBC[\x80-\x95\x98-\x9D\xA0-\xBF]|\xBD[\x80-\x85\x88-\x8D\x90-\x97\x99\x9B\x9D\x9F-\xBD]|\xBE[\x80-\xB4\xB6-\xBC\xBE]|\xBF[\x82-\x84\x86-\x8C\x90-\x93\x96-\x9B\xA0-\xAC\xB2-\xB4\xB6-\xBC])|\xE2(?:\x84[\xA6\xAA\xAB\xAE]|\x86[\x80-\x82])|\xE3(?:\x81[\x81-\xBF]|\x82[\x80-\x94\xA1-\xBF]|\x83[\x80-\xBA]|\x84[\x85-\xAC])|\xEA(?:[\xB0-\xBF][\x80-\xBF])|\xEB(?:[\x80-\xBF][\x80-\xBF])|\xEC(?:[\x80-\xBF][\x80-\xBF])|\xED(?:[\x80-\x9D][\x80-\xBF]|\x9E[\x80-\xA3]))';

$ChIdeographic = '(?:\xE3\x80[\x87\xA1-\xA9]|\xE4(?:[\xB8-\xBF][\x80-\xBF])|\xE5(?:[\x80-\xBF][\x80-\xBF])|\xE6(?:[\x80-\xBF][\x80-\xBF])|\xE7(?:[\x80-\xBF][\x80-\xBF])|\xE8(?:[\x80-\xBF][\x80-\xBF])|\xE9(?:[\x80-\xBD][\x80-\xBF]|\xBE[\x80-\xA5]))';

$ChDigit = '(?:[0-9]|\xD9[\xA0-\xA9]|\xDB[\xB0-\xB9]|\xE0(?:\xA5[\xA6-\xAF]|\xA7[\xA6-\xAF]|\xA9[\xA6-\xAF]|\xAB[\xA6-\xAF]|\xAD[\xA6-\xAF]|\xAF[\xA7-\xAF]|\xB1[\xA6-\xAF]|\xB3[\xA6-\xAF]|\xB5[\xA6-\xAF]|\xB9[\x90-\x99]|\xBB[\x90-\x99]|\xBC[\xA0-\xA9]))';

$ChExtender = '(?:\xC2\xB7|\xCB[\x90\x91]|\xCE\x87|\xD9\x80|\xE0(?:\xB9\x86|\xBB\x86)|\xE3(?:\x80[\x85\xB1-\xB5]|\x82[\x9D\x9E]|\x83[\xBC-\xBE]))';

$ChCombiningChar = '(?:\xCC[\x80-\xBF]|\xCD[\x80-\x85\xA0\xA1]|\xD2[\x83-\x86]|\xD6[\x91-\xA1\xA3-\xB9\xBB-\xBD\xBF]|\xD7[\x81\x82\x84]|\xD9[\x8B-\x92\xB0]|\xDB[\x96-\xA4\xA7\xA8\xAA-\xAD]|\xE0(?:\xA4[\x81-\x83\xBC\xBE\xBF]|\xA5[\x80-\x8D\x91-\x94\xA2\xA3]|\xA6[\x81-\x83\xBC\xBE\xBF]|\xA7[\x80-\x84\x87\x88\x8B-\x8D\x97\xA2\xA3]|\xA8[\x82\xBC\xBE\xBF]|\xA9[\x80-\x82\x87\x88\x8B-\x8D\xB0\xB1]|\xAA[\x81-\x83\xBC\xBE\xBF]|\xAB[\x80-\x85\x87-\x89\x8B-\x8D]|\xAC[\x81-\x83\xBC\xBE\xBF]|\xAD[\x80-\x83\x87\x88\x8B-\x8D\x96\x97]|\xAE[\x82\x83\xBE\xBF]|\xAF[\x80-\x82\x86-\x88\x8A-\x8D\x97]|\xB0[\x81-\x83\xBE\xBF]|\xB1[\x80-\x84\x86-\x88\x8A-\x8D\x95\x96]|\xB2[\x82\x83\xBE\xBF]|\xB3[\x80-\x84\x86-\x88\x8A-\x8D\x95\x96]|\xB4[\x82\x83\xBE\xBF]|\xB5[\x80-\x83\x86-\x88\x8A-\x8D\x97]|\xB8[\xB1\xB4-\xBA]|\xB9[\x87-\x8E]|\xBA[\xB1\xB4-\xB9\xBB\xBC]|\xBB[\x88-\x8D]|\xBC[\x98\x99\xB5\xB7\xB9\xBE\xBF]|\xBD[\xB1-\xBF]|\xBE[\x80-\x84\x86-\x8B\x90-\x95\x97\x99-\xAD\xB1-\xB7\xB9])|\xE2\x83[\x90-\x9C\xA1]|\xE3(?:\x80[\xAA-\xAF]|\x82[\x99\x9A]))';

$ChLetter	= "(?:$ChBaseChar|$ChIdeographic)";
$ChNameChar	= "(?:[-._:]|$ChLetter|$ChDigit|$ChCombiningChar|$ChExtender)";

$ReName		= "(?:(?:[:_]|$ChLetter)$ChNameChar*)";
$ReNmToken	= "(?:$ChNameChar)+";
$ReEntityRef	= "(?:\&$ReName;)";
$ReCharRef	= "(?:\&#(?:[0-9]+|x[0-9a-fA-F]+);)";
$ReReference	= "(?:$ReEntityRef|$ReCharRef)";

#?? what if it contains entity references?
$ReAttValue     = "(?:\"(?:[^\"&<]*|$ReReference)\"|'(?:[^\'&<]|$ReReference)*')";


%DefaultEntities = 
(
 "quot"		=> '"',
 "gt"		=> ">",
 "lt"		=> "<",
 "apos"		=> "'",
 "amp"		=> "&"
);

%DecodeDefaultEntity =
(
 '"' => "&quot;",
 ">" => "&gt;",
 "<" => "&lt;",
 "'" => "&apos;",
 "&" => "&amp;"
);

sub encodeCDATA
{
    my ($str) = shift;
    $str =~ s/]]>/]]&gt;/go;
    $str;
}

#
# PI may not contain "?>"
#
sub encodeProcessingInstruction
{
    my ($str) = shift;
    $str =~ s/\?>/?&gt;/go;
    $str;
}

#
#?? Not sure if this is right - must prevent double minus somehow...
#
sub encodeComment
{
    my ($str) = shift;
    return undef unless defined $str;

    $str =~ s/--/&#45;&#45;/go;
    $str;
}

# for debugging
sub toHex
{
    my $str = shift;
    my $len = length($str);
    my @a = unpack ("C$len", $str);
    my $s = "";
    for (@a)
    {
	$s .= sprintf ("%02x", $_);
    }
    $s;
}

#
# 2nd parameter $default: list of Default Entity characters that need to be 
# converted (e.g. "&<" for conversion to "&amp;" and "&lt;" resp.)
#

sub encodeText
{
    my ($str, $default) = @_;
    return undef unless defined $str;
    
    $str =~ s/([\xC0-\xDF].|[\xE0-\xEF]..|[\xF0-\xFF]...)|([$default])|(]]>)/
	defined($1) ? XmlUtf8Decode ($1) : 
	defined ($2) ? $DecodeDefaultEntity{$2} : "]]&gt;" /egs;

#?? could there be references that should not be expanded?
# e.g. should not replace &#nn; &#xAF; and &abc;
#    $str =~ s/&(?!($ReName|#[0-9]+|#x[0-9a-fA-F]+);)/&amp;/go;

    $str;
}

# Used by AttDef - default value

sub encodeAttrValue
{
    encodeText (shift, '"&<');
}

#
# Converts an integer (Unicode - ISO/IEC 10646) to a UTF-8 encoded character 
# sequence.
# Used when converting e.g. &#123; or &#x3ff; to a string value.
#
# Algorithm borrowed from expat/xmltok.c/XmlUtf8Encode()
#
# not checking for bad characters: < 0, x00-x08, x0B-x0C, x0E-x1F, xFFFE-xFFFF

sub XmlUtf8Encode
{
    my $n = shift;
    if ($n < 0x80)
    {
	return chr ($n);
    }
    elsif ($n < 0x800)
    {
	return pack ("CC", (($n >> 6) | 0xc0), (($n & 0x3f) | 0x80));
    }
    elsif ($n < 0x10000)
    {
	return pack ("CCC", (($n >> 12) | 0xe0), ((($n >> 6) & 0x3f) | 0x80),
		     (($n & 0x3f) | 0x80));
    }
    elsif ($n < 0x110000)
    {
	return pack ("CCCC", (($n >> 18) | 0xf0), ((($n >> 12) & 0x3f) | 0x80),
		     ((($n >> 6) & 0x3f) | 0x80), (($n & 0x3f) | 0x80));
    }
    croak "number is too large for Unicode [$n] in &XmlUtf8Encode";
}

#
# Opposite of XmlUtf8Decode plus it adds prefix "&#" or "&#x" and suffix ";"
# The 2nd parameter ($hex) indicates whether the result is hex encoded or not.
#
sub XmlUtf8Decode
{
    my ($str, $hex) = @_;
    my $len = length ($str);
    my $n;

    if ($len == 2)
    {
	my @n = unpack "C2", $str;
	$n = (($n[0] & 0x3f) << 6) + ($n[1] & 0x3f);
    }
    elsif ($len == 3)
    {
	my @n = unpack "C3", $str;
	$n = (($n[0] & 0x1f) << 12) + (($n[1] & 0x3f) << 6) + 
		($n[2] & 0x3f);
    }
    elsif ($len == 4)
    {
	my @n = unpack "C4", $str;
	$n = (($n[0] & 0x0f) << 18) + (($n[1] & 0x3f) << 12) + 
		(($n[2] & 0x3f) << 6) + ($n[3] & 0x3f);
    }
    elsif ($len == 1)	# just to be complete...
    {
	$n = ord ($str);
    }
    else
    {
	croak "bad value [$str] for XmlUtf8Decode";
    }
    $hex ? sprintf ("&#x%x;", $n) : "&#$n;";
}

$IgnoreReadOnly = 0;
$SafeMode = 1;

sub getIgnoreReadOnly
{
    $IgnoreReadOnly;
}

# The global flag $IgnoreReadOnly is set to the specified value and the old 
# value of $IgnoreReadOnly is returned.
#
# To temporarily disable read-only related exceptions (i.e. when parsing
# XML or temporarily), do the following:
#
# my $oldIgnore = EPrints::DOM::ignoreReadOnly (1);
# ... do whatever you want ...
# EPrints::DOM::ignoreReadOnly ($oldIgnore);
#
sub ignoreReadOnly
{
    my $i = $IgnoreReadOnly;
    $IgnoreReadOnly = $_[0];
    return $i;
}

# XML spec seems to break its own rules... (see ENTITY xmlpio)
sub forgiving_isValidName
{
    $_[0] =~ /^$ReName$/o;
}

# Don't allow names starting with xml (either case)
sub picky_isValidName
{
    $_[0] =~ /^$ReName$/o and $_[0] !~ /^xml/i;
}

# Be forgiving by default, 
*isValidName = \&forgiving_isValidName;

sub allowReservedNames
{
    *isValidName = ($_[0] ? \&forgiving_isValidName : \&picky_isValidName);
}

sub getAllowReservedNames
{
    *isValidName == \&forgiving_isValidName;
}

# Always compress empty tags by default
# This is used by Element::print.
$TagStyle = sub { 0 };

sub setTagCompression
{
    $TagStyle = shift;
}

######################################################################
package EPrints::DOM::PrintToFileHandle;
######################################################################

#
# Used by EPrints::DOM::Node::printToFileHandle
#

sub new
{
    my($class, $fn) = @_;
    bless $fn, $class;
}

sub print
{
    my ($self, $str) = @_;
    print $self $str;
}

######################################################################
package EPrints::DOM::PrintToString;
######################################################################

#
# Used by EPrints::DOM::Node::toString to concatenate strings
#

sub new
{
    my($class) = @_;
    my $str = "";
    bless \$str, $class;
}

sub print
{
    my ($self, $str) = @_;
    $$self .= $str;
}

sub toString
{
    my $self = shift;
    $$self;
}

sub reset
{
    ${$_[0]} = "";
}

*Singleton = \(new EPrints::DOM::PrintToString);

######################################################################
package EPrints::DOM::DOMException;
######################################################################

use Exporter;
use overload '""' => \&stringify;
use vars qw ( @ISA @EXPORT @ErrorNames );

BEGIN
{
  @ISA = qw( Exporter );
  @EXPORT = qw( INDEX_SIZE_ERR
		DOMSTRING_SIZE_ERR
		HIERARCHY_REQUEST_ERR
		WRONG_DOCUMENT_ERR
		INVALID_CHARACTER_ERR
		NO_DATA_ALLOWED_ERR
		NO_MODIFICATION_ALLOWED_ERR
		NOT_FOUND_ERR
		NOT_SUPPORTED_ERR
		INUSE_ATTRIBUTE_ERR
	      );
}

sub UNKNOWN_ERR			() {0;}	# not in the DOM Spec!
sub INDEX_SIZE_ERR		() {1;}
sub DOMSTRING_SIZE_ERR		() {2;}
sub HIERARCHY_REQUEST_ERR	() {3;}
sub WRONG_DOCUMENT_ERR		() {4;}
sub INVALID_CHARACTER_ERR	() {5;}
sub NO_DATA_ALLOWED_ERR		() {6;}
sub NO_MODIFICATION_ALLOWED_ERR	() {7;}
sub NOT_FOUND_ERR		() {8;}
sub NOT_SUPPORTED_ERR		() {9;}
sub INUSE_ATTRIBUTE_ERR		() {10;}

@ErrorNames = (
	       "UNKNOWN_ERR",
	       "INDEX_SIZE_ERR",
	       "DOMSTRING_SIZE_ERR",
	       "HIERARCHY_REQUEST_ERR",
	       "WRONG_DOCUMENT_ERR",
	       "INVALID_CHARACTER_ERR",
	       "NO_DATA_ALLOWED_ERR",
	       "NO_MODIFICATION_ALLOWED_ERR",
	       "NOT_FOUND_ERR",
	       "NOT_SUPPORTED_ERR",
	       "INUSE_ATTRIBUTE_ERR"
	      );

sub new
{
    my ($type, $code, $msg) = @_;
    my $self = bless {Code => $code}, $type;

    $self->{Message} = $msg if defined $msg;

#    print "=> Exception: " . $self->stringify . "\n"; 
    $self;
}

sub getCode
{
    $_[0]->{Code};
}

#------------------------------------------------------------
# Extra method implementations

sub getName
{
    $ErrorNames[$_[0]->{Code}];
}

sub getMessage
{
    $_[0]->{Message};
}

sub stringify
{
    my $self = shift;

    "EPrints::DOM::DOMException(Code=" . $self->getCode . ", Name=" .
	$self->getName . ", Message=" . $self->getMessage . ")";
}

######################################################################
package EPrints::DOM::NamedNodeMap;
######################################################################

BEGIN 
{
    import Carp;
    import EPrints::DOM::DOMException;
}

use vars qw( $Special );

# Constant definition:
# Note: a real Name should have at least 1 char, so nobody else should use this
$Special = "";

sub new 
{
    my ($class, %args) = @_;

    $args{Values} = new EPrints::DOM::NodeList;

    # Store all NamedNodeMap properties in element $Special
    bless { $Special => \%args}, $class;
}

sub getNamedItem 
{
    # Don't return the $Special item!
    ($_[1] eq $Special) ? undef : $_[0]->{$_[1]};
}

sub setNamedItem 
{
    my ($self, $node) = @_;
    my $prop = $self->{$Special};

    my $name = $node->getNodeName;

    if ($EPrints::DOM::SafeMode)
    {
	croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR)
	    if $self->isReadOnly;

	croak new EPrints::DOM::DOMException (WRONG_DOCUMENT_ERR)
	    if $node->{Doc} != $prop->{Doc};

	croak new EPrints::DOM::DOMException (INUSE_ATTRIBUTE_ERR)
	    if defined ($node->{UsedIn});

	croak new EPrints::DOM::DOMException (INVALID_CHARACTER_ERR,
		      "can't add name with NodeName [$name] to NamedNodeMap")
	    if $name eq $Special;
    }

    my $values = $prop->{Values};
    my $index = -1;

    my $prev = $self->{$name};
    if (defined $prev)
    {
	# decouple previous node
	delete $prev->{UsedIn};

	# find index of $prev
	$index = 0;
	for my $val (@{$values})
	{
	    last if ($val == $prev);
	    $index++;
	}
    }

    $self->{$name} = $node;    
    $node->{UsedIn} = $self;

    if ($index == -1)
    {
	push (@{$values}, $node);
    }
    else	# replace previous node with new node
    {
	splice (@{$values}, $index, 1, $node);
    }
    
    $prev;
}

sub removeNamedItem 
{
    my ($self, $name) = @_;

    # Be careful that user doesn't delete $Special node!
    croak new EPrints::DOM::DOMException (NOT_FOUND_ERR)
        if $name eq $Special;

    my $node = $self->{$name};

    croak new EPrints::DOM::DOMException (NOT_FOUND_ERR)
        unless defined $node;

    # The DOM Spec doesn't mention this Exception - I think it's an oversight
    croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR)
	if $self->isReadOnly;

    delete $node->{UsedIn};
    delete $self->{$name};

    # remove node from Values list
    my $values = $self->getValues;
    my $index = 0;
    for my $val (@{$values})
    {
	if ($val == $node)
	{
	    splice (@{$values}, $index, 1, ());
	    last;
	}
	$index++;
    }
    $node;
}

# The following 2 are really bogus. DOM should use an iterator instead (Clark)

sub item 
{
    my ($self, $item) = @_;
    $self->{$Special}->{Values}->[$item];
}

sub getLength 
{
    my ($self) = @_;
    my $vals = $self->{$Special}->{Values};
    int (@$vals);
}

#------------------------------------------------------------
# Extra method implementations

sub isReadOnly
{
    return 0 if $EPrints::DOM::IgnoreReadOnly;

    my $used = $_[0]->{$Special}->{UsedIn};
    defined $used ? $used->isReadOnly : 0;
}

sub cloneNode
{
    my ($self, $deep) = @_;
    my $prop = $self->{$Special};

    my $map = new EPrints::DOM::NamedNodeMap (Doc => $prop->{Doc});
    # Not copying Parent property on purpose! 

    my $oldIgnore = EPrints::DOM::ignoreReadOnly (1);	# temporarily...

    for my $val (@{$prop->{Values}})
    {
	my $key = $val->getNodeName;

	my $newNode = $val->cloneNode ($deep);
	$newNode->{UsedIn} = $map;
	$map->{$key} = $newNode;
	push (@{$map->{$Special}->{Values}}, $newNode);
    }
    EPrints::DOM::ignoreReadOnly ($oldIgnore);	# restore previous value

    $map;
}

sub setOwnerDocument
{
    my ($self, $doc) = @_;
    my $special = $self->{$Special};

    $special->{Doc} = $doc;
    for my $kid (@{$special->{Values}})
    {
	$kid->setOwnerDocument ($doc);
    }
}

sub getChildIndex
{
    my ($self, $attr) = @_;
    my $i = 0;
    for my $kid (@{$self->{$Special}->{Values}})
    {
	return $i if $kid == $attr;
	$i++;
    }
    -1;	# not found
}

sub getValues
{
    wantarray ? @{ $_[0]->{$Special}->{Values} } : $_[0]->{$Special}->{Values};
}

# Remove circular dependencies. The NamedNodeMap and its values should
# not be used afterwards.
sub dispose
{
    my $self = shift;

    for my $kid (@{$self->getValues})
    {
	delete $kid->{UsedIn};
	$kid->dispose;
    }

    delete $self->{$Special}->{Doc};
    delete $self->{$Special}->{Parent};
    delete $self->{$Special}->{Values};

    for my $key (keys %$self)
    {
	delete $self->{$key};
    }
}

sub setParentNode
{
    $_[0]->{$Special}->{Parent} = $_[1];
}

sub getProperty
{
    $_[0]->{$Special}->{$_[1]};
}

#?? remove after debugging
sub toString
{
    my ($self) = @_;
    my $str = "NamedNodeMap[";
    while (my ($key, $val) = each %$self)
    {
	if ($key eq $Special)
	{
	    $str .= "##Special (";
	    while (my ($k, $v) = each %$val)
	    {
		if ($k eq "Values")
		{
		    $str .= $k . " => [";
		    for my $a (@$v)
		    {
#			$str .= $a->getNodeName . "=" . $a . ",";
			$str .= $a->toString . ",";
		    }
		    $str .= "], ";
		}
		else
		{
		    $str .= $k . " => " . $v . ", ";
		}
	    }
	    $str .= "), ";
	}
	else
	{
	    $str .= $key . " => " . $val . ", ";
	}
    }
    $str . "]";
}

######################################################################
package EPrints::DOM::NodeList;
######################################################################

use vars qw ( $EMPTY );

# Empty NodeList
$EMPTY = new EPrints::DOM::NodeList;

sub new 
{
    bless [], $_[0];
}

sub item 
{
    $_[0]->[$_[1]];
}

sub getLength 
{
    int (@{$_[0]});
}

#------------------------------------------------------------
# Extra method implementations

sub dispose
{
    my $self = shift;
    for my $kid (@{$self})
    {
	$kid->dispose;
    }
}

sub setOwnerDocument
{
    my ($self, $doc) = @_;
    for my $kid (@{$self})
    { 
	$kid->setOwnerDocument ($doc);
    }
}

######################################################################
package EPrints::DOM::DOMImplementation;
######################################################################
 
$EPrints::DOM::DOMImplementation::Singleton =
  bless \$EPrints::DOM::DOMImplementation::Singleton, 'EPrints::DOM::DOMImplementation';
 
sub hasFeature 
{
    my ($self, $feature, $version) = @_;
 
    $feature eq 'XML' and $version eq '1.0';
}

######################################################################
package EPrints::DOM::Node;
######################################################################

use vars qw( @NodeNames @EXPORT @ISA );

BEGIN 
{
  import EPrints::DOM::DOMException;
  import Carp;

  require FileHandle;

  @ISA = qw( Exporter );
  @EXPORT = qw(
	     UNKNOWN_NODE
	     ELEMENT_NODE
	     ATTRIBUTE_NODE
	     TEXT_NODE
	     CDATA_SECTION_NODE
	     ENTITY_REFERENCE_NODE
	     ENTITY_NODE
	     PROCESSING_INSTRUCTION_NODE
	     COMMENT_NODE
	     DOCUMENT_NODE
	     DOCUMENT_TYPE_NODE
	     DOCUMENT_FRAGMENT_NODE
	     NOTATION_NODE
	     ELEMENT_DECL_NODE
	     ATT_DEF_NODE
	     XML_DECL_NODE
	     ATTLIST_DECL_NODE
	    );
}

#---- Constant definitions

# Node types

sub UNKNOWN_NODE                () {0;}		# not in the DOM Spec

sub ELEMENT_NODE                () {1;}
sub ATTRIBUTE_NODE              () {2;}
sub TEXT_NODE                   () {3;}
sub CDATA_SECTION_NODE          () {4;}
sub ENTITY_REFERENCE_NODE       () {5;}
sub ENTITY_NODE                 () {6;}
sub PROCESSING_INSTRUCTION_NODE () {7;}
sub COMMENT_NODE                () {8;}
sub DOCUMENT_NODE               () {9;}
sub DOCUMENT_TYPE_NODE          () {10;}
sub DOCUMENT_FRAGMENT_NODE      () {11;}
sub NOTATION_NODE               () {12;}

sub ELEMENT_DECL_NODE		() {13;}	# not in the DOM Spec
sub ATT_DEF_NODE 		() {14;}	# not in the DOM Spec
sub XML_DECL_NODE 		() {15;}	# not in the DOM Spec
sub ATTLIST_DECL_NODE		() {16;}	# not in the DOM Spec

@NodeNames = (
	      "UNKNOWN_NODE",	# not in the DOM Spec!

	      "ELEMENT_NODE",
	      "ATTRIBUTE_NODE",
	      "TEXT_NODE",
	      "CDATA_SECTION_NODE",
	      "ENTITY_REFERENCE_NODE",
	      "ENTITY_NODE",
	      "PROCESSING_INSTRUCTION_NODE",
	      "COMMENT_NODE",
	      "DOCUMENT_NODE",
	      "DOCUMENT_TYPE_NODE",
	      "DOCUMENT_FRAGMENT_NODE",
	      "NOTATION_NODE",

	      "ELEMENT_DECL_NODE",
	      "ATT_DEF_NODE",
	      "XML_DECL_NODE",
	      "ATTLIST_DECL_NODE"
	     );

sub getParentNode
{
    $_[0]->{Parent};
}

sub appendChild
{
    my ($self, $node) = @_;

    # REC 7473
    if ($EPrints::DOM::SafeMode)
    {
	croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
					  "node is ReadOnly")
	    if $self->isReadOnly;
    }

    my $isFrag = $node->isDocumentFragmentNode;
    my $doc = $self->{Doc};

    if ($isFrag)
    {
	if ($EPrints::DOM::SafeMode)
	{
	    for my $n (@{$node->{C}})
	    {
		croak new EPrints::DOM::DOMException (WRONG_DOCUMENT_ERR,
						  "nodes belong to different documents")
		    if $doc != $n->{Doc};
		
		croak new EPrints::DOM::DOMException (HIERARCHY_REQUEST_ERR,
						  "node is ancestor of parent node")
		    if $n->isAncestor ($self);
		
		croak new EPrints::DOM::DOMException (HIERARCHY_REQUEST_ERR,
						  "bad node type")
		    if $self->rejectChild ($n);
	    }
	}

	my @list = @{$node->{C}};	# don't try to compress this
	for my $n (@list)
	{
	    $n->setParentNode ($self);
	}
	push @{$self->{C}}, @list;
    }
    else
    {
	if ($EPrints::DOM::SafeMode)
	{
	    croak new EPrints::DOM::DOMException (WRONG_DOCUMENT_ERR,
						  "nodes belong to different documents")
		if $doc != $node->{Doc};
		
	    croak new EPrints::DOM::DOMException (HIERARCHY_REQUEST_ERR,
						  "node is ancestor of parent node")
		if $node->isAncestor ($self);
		
	    croak new EPrints::DOM::DOMException (HIERARCHY_REQUEST_ERR,
						  "bad node type")
		if $self->rejectChild ($node);
	}
	$node->setParentNode ($self);
	push @{$self->{C}}, $node;
    }
    $node;
}

sub getChildNodes
{
    # NOTE: if node can't have children, $self->{C} is undef.
    my $kids = $_[0]->{C};

    # Return a list if called in list context.
    wantarray ? (defined ($kids) ? @{ $kids } : ()) :
	        (defined ($kids) ? $kids : $EPrints::DOM::NodeList::EMPTY);
}

sub hasChildNodes
{
    my $kids = $_[0]->{C};
    defined ($kids) && @$kids > 0;
}

# This method is overriden in Document
sub getOwnerDocument
{
    $_[0]->{Doc};
}

sub getFirstChild
{
    my $kids = $_[0]->{C};
    defined $kids ? $kids->[0] : undef; 
}

sub getLastChild
{
    my $kids = $_[0]->{C};
    defined $kids ? $kids->[-1] : undef; 
}

sub getPreviousSibling
{
    my $self = shift;

    my $pa = $self->{Parent};
    return undef unless $pa;
    my $index = $pa->getChildIndex ($self);
    return undef unless $index;

    $pa->getChildAtIndex ($index - 1);
}

sub getNextSibling
{
    my $self = shift;

    my $pa = $self->{Parent};
    return undef unless $pa;

    $pa->getChildAtIndex ($pa->getChildIndex ($self) + 1);
}

sub insertBefore
{
    my ($self, $node, $refNode) = @_;

    return $self->appendChild ($node) unless $refNode;	# append at the end

    croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
				      "node is ReadOnly")
	if $self->isReadOnly;

    my @nodes = ($node);
    @nodes = @{$node->{C}}
	if $node->getNodeType == DOCUMENT_FRAGMENT_NODE;

    my $doc = $self->{Doc};

    for my $n (@nodes)
    {
	croak new EPrints::DOM::DOMException (WRONG_DOCUMENT_ERR,
					  "nodes belong to different documents")
	    if $doc != $n->{Doc};
	
	croak new EPrints::DOM::DOMException (HIERARCHY_REQUEST_ERR,
					  "node is ancestor of parent node")
	    if $n->isAncestor ($self);

	croak new EPrints::DOM::DOMException (HIERARCHY_REQUEST_ERR,
					  "bad node type")
	    if $self->rejectChild ($n);
    }
    my $index = $self->getChildIndex ($refNode);

    croak new EPrints::DOM::DOMException (NOT_FOUND_ERR,
				      "reference node not found")
	if $index == -1;

    for my $n (@nodes)
    {
	$n->setParentNode ($self);
    }

    splice (@{$self->{C}}, $index, 0, @nodes);
    $node;
}

sub replaceChild
{
    my ($self, $node, $refNode) = @_;

    croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
				      "node is ReadOnly")
	if $self->isReadOnly;

    my @nodes = ($node);
    @nodes = @{$node->{C}}
	if $node->getNodeType == DOCUMENT_FRAGMENT_NODE;

    for my $n (@nodes)
    {
	croak new EPrints::DOM::DOMException (WRONG_DOCUMENT_ERR,
					  "nodes belong to different documents")
	    if $self->{Doc} != $n->{Doc};

	croak new EPrints::DOM::DOMException (HIERARCHY_REQUEST_ERR,
					  "node is ancestor of parent node")
	    if $n->isAncestor ($self);

	croak new EPrints::DOM::DOMException (HIERARCHY_REQUEST_ERR,
					  "bad node type")
	    if $self->rejectChild ($n);
    }

    my $index = $self->getChildIndex ($refNode);
    croak new EPrints::DOM::DOMException (NOT_FOUND_ERR,
				      "reference node not found")
	if $index == -1;

    for my $n (@nodes)
    {
	$n->setParentNode ($self);
    }
    splice (@{$self->{C}}, $index, 1, @nodes);

    $refNode->removeChildHoodMemories;
    $refNode;
}

sub removeChild
{
    my ($self, $node) = @_;

    croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
				      "node is ReadOnly")
	if $self->isReadOnly;

    my $index = $self->getChildIndex ($node);

    croak new EPrints::DOM::DOMException (NOT_FOUND_ERR,
				      "reference node not found")
	if $index == -1;

    splice (@{$self->{C}}, $index, 1, ());

    $node->removeChildHoodMemories;
    $node;
}

# Merge all subsequent Text nodes in this subtree
sub normalize
{
    my ($self) = shift;
    my $prev = undef;	# previous Text node

    return unless defined $self->{C};

    my @nodes = @{$self->{C}};
    my $i = 0;
    my $n = @nodes;
    while ($i < $n)
    {
	my $node = $self->getChildAtIndex($i);
	my $type = $node->getNodeType;

	if (defined $prev)
	{
	    # It should not merge CDATASections. Dom Spec says:
	    #  Adjacent CDATASections nodes are not merged by use
	    #  of the Element.normalize() method.
	    if ($type == TEXT_NODE)
	    {
		$prev->appendData ($node->getData);
		$self->removeChild ($node);
		$i--;
		$n--;
	    }
	    else
	    {
		$prev = undef;
		if ($type == ELEMENT_NODE)
		{
		    $node->normalize;
		    for my $attr (@{$node->getAttributes->getValues})
		    {
			$attr->normalize;
		    }
		}
	    }
	}
	else
	{
	    if ($type == TEXT_NODE)
	    {
		$prev = $node;
	    }
	    elsif ($type == ELEMENT_NODE)
	    {
		$node->normalize;
		for my $attr (@{$node->getAttributes->getValues})
		{
		    $attr->normalize;
		}
	    }
	}
	$i++;
    }
}

# Return all Element nodes in the subtree that have the specified tagName.
# If tagName is "*", all Element nodes are returned.
# NOTE: the DOM Spec does not specify a 3rd or 4th parameter
sub getElementsByTagName
{
    my ($self, $tagName, $recurse, $list) = @_;
    $recurse = 1 unless defined $recurse;
    $list = (wantarray ? [] : new EPrints::DOM::NodeList) unless defined $list;

    return unless defined $self->{C};

    # preorder traversal: check parent node first
    for my $kid (@{$self->{C}})
    {
	if ($kid->isElementNode)
	{
	    if ($tagName eq "*" || $tagName eq $kid->getTagName)
	    {
		push @{$list}, $kid;
	    }
	    $kid->getElementsByTagName ($tagName, $recurse, $list) if $recurse;
	}
    }
    wantarray ? @{ $list } : $list;
}

sub getNodeValue
{
    undef;
}

sub setNodeValue
{
    # no-op
}

# Redefined by EPrints::DOM::Element
sub getAttributes
{
    undef;
}

#------------------------------------------------------------
# Extra method implementations

sub setOwnerDocument
{
    my ($self, $doc) = @_;
    $self->{Doc} = $doc;

    return unless defined $self->{C};

    for my $kid (@{$self->{C}})
    {
	$kid->setOwnerDocument ($doc);
    }
}

sub cloneChildren
{
    my ($self, $node, $deep) = @_;
    return unless $deep;
    
    return unless defined $self->{C};

    my $oldIgnore = EPrints::DOM::ignoreReadOnly (1);	# temporarily...

    for my $kid (@{$node->{C}})
    {
	my $newNode = $kid->cloneNode ($deep);
	push @{$self->{C}}, $newNode;
	$newNode->setParentNode ($self);
    }

    EPrints::DOM::ignoreReadOnly ($oldIgnore);	# restore previous value
}

# For internal use only!
sub removeChildHoodMemories
{
    my ($self) = @_;

#????? remove?
    delete $self->{Parent};
}

# Remove circular dependencies. The Node and its children should
# not be used afterwards.
sub dispose
{
    my $self = shift;

    $self->removeChildHoodMemories;

    if (defined $self->{C})
    {
	$self->{C}->dispose;
	delete $self->{C};
    }
    delete $self->{Doc};
}

# For internal use only!
sub setParentNode
{
    my ($self, $parent) = @_;

    # REC 7473
    my $oldParent = $self->{Parent};
    if (defined $oldParent)
    {
	# remove from current parent
	my $index = $oldParent->getChildIndex ($self);
	splice (@{$oldParent->{C}}, $index, 1, ());

	$self->removeChildHoodMemories;
    }
    $self->{Parent} = $parent;
}

# This function can return 3 values:
# 1: always readOnly
# 0: never readOnly
# undef: depends on parent node 
#
# Returns 1 for DocumentType, Notation, Entity, EntityReference, Attlist, 
# ElementDecl, AttDef. 
# The first 4 are readOnly according to the DOM Spec, the others are always 
# children of DocumentType. (Naturally, children of a readOnly node have to be
# readOnly as well...)
# These nodes are always readOnly regardless of who their ancestors are.
# Other nodes, e.g. Comment, are readOnly only if their parent is readOnly,
# which basically means that one of its ancestors has to be one of the
# aforementioned node types.
# Document and DocumentFragment return 0 for obvious reasons.
# Attr, Element, CDATASection, Text return 0. The DOM spec says that they can 
# be children of an Entity, but I don't think that that's possible
# with the current XML::Parser.
# Attr uses a {ReadOnly} property, which is only set if it's part of a AttDef.
# Always returns 0 if ignoreReadOnly is set.
sub isReadOnly
{
    # default implementation for Nodes that are always readOnly
    ! $EPrints::DOM::IgnoreReadOnly;
}

sub rejectChild
{
    1;
}

sub getNodeTypeName
{
    $NodeNames[$_[0]->getNodeType];
}

sub getChildIndex
{
    my ($self, $node) = @_;
    my $i = 0;

    return -1 unless defined $self->{C};

    for my $kid (@{$self->{C}})
    {
	return $i if $kid == $node;
	$i++;
    }
    -1;
}

sub getChildAtIndex
{
    my $kids = $_[0]->{C};
    defined ($kids) ? $kids->[$_[1]] : undef;
}

sub isAncestor
{
    my ($self, $node) = @_;

    do
    {
	return 1 if $self == $node;
	$node = $node->{Parent};
    }
    while (defined $node);

    0;
}

# Added for optimization. Overriden in EPrints::DOM::Text
sub isTextNode
{
    0;
}

# Added for optimization. Overriden in EPrints::DOM::DocumentFragment
sub isDocumentFragmentNode
{
    0;
}

# Added for optimization. Overriden in EPrints::DOM::Element
sub isElementNode
{
    0;
}

# Add a Text node with the specified value or append the text to the
# previous Node if it is a Text node.
sub addText
{
    # REC 9456 (if it was called)
    my ($self, $str) = @_;

    my $node = ${$self->{C}}[-1];	# $self->getLastChild

    if (defined ($node) && $node->isTextNode)
    {
	# REC 5475 (if it was called)
	$node->appendData ($str);
    }
    else
    {
	$node = $self->{Doc}->createTextNode ($str);
	$self->appendChild ($node);
    }
    $node;
}

# Add a CDATASection node with the specified value or append the text to the
# previous Node if it is a CDATASection node.
sub addCDATA
{
    my ($self, $str) = @_;

    my $node = ${$self->{C}}[-1];	# $self->getLastChild

    if (defined ($node) && $node->getNodeType == CDATA_SECTION_NODE)
    {
	# REC 5475
	$node->appendData ($str);
    }
    else
    {
	$node = $self->{Doc}->createCDATASection ($str);
	$self->appendChild ($node);
    }
    $node;
}

sub removeChildNodes
{
    my $self = shift;

    my $cref = $self->{C};
    return unless defined $cref;

    my $kid;
    while ($kid = pop @{$cref})
    {
	delete $kid->{Parent};
    }
}

sub toString
{
    my $self = shift;
    my $pr = $EPrints::DOM::PrintToString::Singleton;
    $pr->reset;
    $self->print ($pr);
    $pr->toString;
}

sub printToFile
{
    my ($self, $fileName) = @_;
    my $fh = new FileHandle ($fileName, "w") || 
	croak "printToFile - can't open output file $fileName";
    
    $self->print ($fh);
    $fh->close;
}

# Use print to print to a FileHandle object (see printToFile code)
sub printToFileHandle
{
    my ($self, $FH) = @_;
    my $pr = new EPrints::DOM::PrintToFileHandle ($FH);
    $self->print ($pr);
}

# Used by AttDef::setDefault to convert unexpanded default attribute value
sub expandEntityRefs
{
    my ($self, $str) = @_;
    my $doctype = $self->{Doc}->getDoctype;

    $str =~ s/&($EPrints::DOM::ReName|(#([0-9]+)|#x([0-9a-fA-F]+)));/
	defined($2) ? EPrints::DOM::XmlUtf8Encode ($3 || hex ($4)) 
		    : expandEntityRef ($1, $doctype)/ego;
    $str;
}

sub expandEntityRef
{
    my ($entity, $doctype) = @_;

    my $expanded = $EPrints::DOM::DefaultEntities{$entity};
    return $expanded if defined $expanded;

    $expanded = $doctype->getEntity ($entity);
    return $expanded->getValue if (defined $expanded);

#?? is this an error?
    croak "Could not expand entity reference of [$entity]\n";
#    return "&$entity;";	# entity not found
}

######################################################################
package EPrints::DOM::Attr;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
    import Carp;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

sub new
{
    my ($class, $doc, $name, $value, $specified) = @_;

    if ($EPrints::DOM::SafeMode)
    {
	croak new EPrints::DOM::DOMException (INVALID_CHARACTER_ERR,
				      "bad Attr name [$name]")
	    unless EPrints::DOM::isValidName ($name);
    }

    my $self = bless {Doc	=> $doc, 
		      C		=> new EPrints::DOM::NodeList,
		      Name	=> $name}, $class;
    
    if (defined $value)
    {
	$self->setValue ($value);
	$self->{Specified} = (defined $specified) ? $specified : 1;
    }
    else
    {
	$self->{Specified} = 0;
    }
    $self;
}

sub getNodeType
{
    ATTRIBUTE_NODE;
}

sub isSpecified
{
    $_[0]->{Specified};
}

sub getName
{
    $_[0]->{Name};
}

sub getValue
{
    my $self = shift;
    my $value = "";

    for my $kid (@{$self->{C}})
    {
	$value .= $kid->getData;
    }
    $value;
}

sub setValue
{
    my ($self, $value) = @_;

    # REC 1147
    $self->removeChildNodes;
    $self->appendChild ($self->{Doc}->createTextNode ($value));
    $self->{Specified} = 1;
}

sub getNodeName
{
    $_[0]->getName;
}

sub getNodeValue
{
    $_[0]->getValue;
}

sub setNodeValue
{
    $_[0]->setValue ($_[1]);
}

sub cloneNode
{
    my ($self) = @_;	# parameter deep is ignored

    my $node = $self->{Doc}->createAttribute ($self->getName);
    $node->{Specified} = $self->{Specified};
    $node->{ReadOnly} = 1 if $self->{ReadOnly};

    $node->cloneChildren ($self, 1);
    $node;
}

#------------------------------------------------------------
# Extra method implementations
#

sub isReadOnly
{
    # ReadOnly property is set if it's part of a AttDef
    ! $EPrints::DOM::IgnoreReadOnly && defined ($_[0]->{ReadOnly});
}

sub print
{
    my ($self, $FILE) = @_;    

    my $name = $self->{Name};

    $FILE->print ("$name=\"");
    for my $kid (@{$self->{C}})
    {
	if ($kid->getNodeType == TEXT_NODE)
	{
	    $FILE->print (EPrints::DOM::encodeAttrValue ($kid->getData));
	}
	else	# ENTITY_REFERENCE_NODE
	{
	    $kid->print ($FILE);
	}
    }
    $FILE->print ("\"");
}

sub rejectChild
{
    my $t = $_[1]->getNodeType;

    $t != TEXT_NODE && $t != ENTITY_REFERENCE_NODE;
}

######################################################################
package EPrints::DOM::ProcessingInstruction;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
    import Carp;

}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

sub new
{
    my ($class, $doc, $target, $data) = @_;

    croak new EPrints::DOM::DOMException (INVALID_CHARACTER_ERR,
			      "bad ProcessingInstruction Target [$target]")
	unless (EPrints::DOM::isValidName ($target) && $target !~ /^xml$/io);

    bless {Doc		=> $doc,
	   Target	=> $target,
	   Data		=> $data}, $class;
}

sub getNodeType
{
    PROCESSING_INSTRUCTION_NODE;
}

sub getTarget
{
    $_[0]->{Target};
}

sub getData
{
    $_[0]->{Data};
}

sub setData
{
    my ($self, $data) = @_;

    croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
				      "node is ReadOnly")
	if $self->isReadOnly;

    $self->{Data} = $data;
}

sub getNodeName
{
    $_[0]->{Target};
}

sub getNodeValue
{
    $_[0]->getData;
}

sub setNodeValue
{
    $_[0]->setData ($_[1]);
}

sub cloneNode
{
    my $self = shift;
    $self->{Doc}->createProcessingInstruction ($self->getTarget, 
					       $self->getData);
}

#------------------------------------------------------------
# Extra method implementations

sub isReadOnly
{
    return 0 if $EPrints::DOM::IgnoreReadOnly;

    my $pa = $_[0]->{Parent};
    defined ($pa) ? $pa->isReadOnly : 0;
}

sub print
{
    my ($self, $FILE) = @_;    

    $FILE->print ("<?");
    $FILE->print ($self->{Target});
    $FILE->print (" ");
    $FILE->print (EPrints::DOM::encodeProcessingInstruction ($self->{Data}));
    $FILE->print ("?>");
}

######################################################################
package EPrints::DOM::Notation;
######################################################################

BEGIN
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
    import Carp;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

sub new
{
    my ($class, $doc, $name, $base, $sysId, $pubId) = @_;

    croak new EPrints::DOM::DOMException (INVALID_CHARACTER_ERR, 
				      "bad Notation Name [$name]")
	unless EPrints::DOM::isValidName ($name);

    bless {Doc		=> $doc,
	   Name		=> $name,
	   Base		=> $base,
	   SysId	=> $sysId,
	   PubId	=> $pubId}, $class;
}

sub getNodeType
{
    NOTATION_NODE;
}

sub getPubId
{
    $_[0]->{PubId};
}

sub setPubId
{
    $_[0]->{PubId} = $_[1];
}

sub getSysId
{
    $_[0]->{SysId};
}

sub setSysId
{
    $_[0]->{SysId} = $_[1];
}

sub getName
{
    $_[0]->{Name};
}

sub setName
{
    $_[0]->{Name} = $_[1];
}

sub getBase
{
    $_[0]->{Base};
}

sub getNodeName
{
    $_[0]->{Name};
}

sub print
{
    my ($self, $FILE) = @_;    

    my $name = $self->{Name};
    my $sysId = $self->{SysId};
    my $pubId = $self->{PubId};

    $FILE->print ("<!NOTATION $name ");

    if (defined $pubId)
    {
	$FILE->print (" PUBLIC \"$pubId\"");	
    }
    if (defined $sysId)
    {
	$FILE->print (" SYSTEM \"$sysId\"");	
    }
    $FILE->print (">");
}

sub cloneNode
{
    my ($self) = @_;
    $self->{Doc}->createNotation ($self->{Name}, $self->{Base}, 
				  $self->{SysId}, $self->{PubId});
}


######################################################################
package EPrints::DOM::Entity;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
    import Carp;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

sub new
{
    my ($class, $doc, $par, $notationName, $value, $sysId, $pubId, $ndata) = @_;

    croak new EPrints::DOM::DOMException (INVALID_CHARACTER_ERR, 
				      "bad Entity Name [$notationName]")
	unless EPrints::DOM::isValidName ($notationName);

    bless {Doc		=> $doc,
	   NotationName	=> $notationName,
	   Parameter	=> $par,
	   Value	=> $value,
	   Ndata	=> $ndata,
	   SysId	=> $sysId,
	   PubId	=> $pubId}, $class;
#?? maybe Value should be a Text node
}

sub getNodeType
{
    ENTITY_NODE;
}

sub getPubId
{
    $_[0]->{PubId};
}

sub getSysId
{
    $_[0]->{SysId};
}

# Dom Spec says: 
#  For unparsed entities, the name of the notation for the
#  entity. For parsed entities, this is null.

#?? do we have unparsed entities?
sub getNotationName
{
    $_[0]->{NotationName};
}

sub getNodeName
{
    $_[0]->{NotationName};
}

sub cloneNode
{
    my $self = shift;
    $self->{Doc}->createEntity ($self->{Parameter}, 
				$self->{NotationName}, $self->{Value}, 
				$self->{SysId}, $self->{PubId}, 
				$self->{Ndata});
}

sub rejectChild
{
    return 1;
#?? if value is split over subnodes, recode this section
# also add:				   c => new EPrints::DOM::NodeList,

    my $t = $_[1];

    return $t == TEXT_NODE
	|| $t == ENTITY_REFERENCE_NODE 
	|| $t == PROCESSING_INSTRUCTION_NODE
	|| $t == COMMENT_NODE
	|| $t == CDATA_SECTION_NODE
	|| $t == ELEMENT_NODE;
}

sub getValue
{
    $_[0]->{Value};
}

sub isParameterEntity
{
    $_[0]->{Parameter};
}

sub getNdata
{
    $_[0]->{Ndata};
}

sub print
{
    my ($self, $FILE) = @_;    

    my $name = $self->{NotationName};

    my $par = $self->isParameterEntity ? "% " : "";

    $FILE->print ("<!ENTITY $par$name");

    my $value = $self->{Value};
    my $sysId = $self->{SysId};
    my $pubId = $self->{PubId};
    my $ndata = $self->{Ndata};

    if (defined $value)
    {
#?? Not sure what to do if it contains both single and double quote
	$value = ($value =~ /\"/) ? "'$value'" : "\"$value\"";
	$FILE->print (" $value");
    }
    if (defined $pubId)
    {
	$FILE->print (" PUBLIC \"$pubId\"");	
    }
    elsif (defined $sysId)
    {
	$FILE->print (" SYSTEM");
    }

    if (defined $sysId)
    {
	$FILE->print (" \"$sysId\"");
    }
    $FILE->print (" NDATA $ndata") if defined $ndata;
    $FILE->print (">");
}

######################################################################
package EPrints::DOM::EntityReference;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
    import Carp;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

sub new
{
    my ($class, $doc, $name, $parameter) = @_;

    croak new EPrints::DOM::DOMException (INVALID_CHARACTER_ERR, 
		      "bad Entity Name [$name] in EntityReference")
	unless EPrints::DOM::isValidName ($name);

    bless {Doc		=> $doc,
	   EntityName	=> $name,
	   Parameter	=> ($parameter || 0)}, $class;
}

sub getNodeType
{
    ENTITY_REFERENCE_NODE;
}

sub getNodeName
{
    $_[0]->{EntityName};
}

#------------------------------------------------------------
# Extra method implementations

sub getEntityName
{
    $_[0]->{EntityName};
}

sub isParameterEntity
{
    $_[0]->{Parameter};
}

sub getData
{
    my $self = shift;
    my $name = $self->{EntityName};
    my $parameter = $self->{Parameter};

    my $data = $self->{Doc}->expandEntity ($name, $parameter);

    unless (defined $data)
    {
#?? this is probably an error
	my $pc = $parameter ? "%" : "&";
	$data = "$pc$name;";
    }
    $data;
}

sub print
{
    my ($self, $FILE) = @_;    

    my $name = $self->{EntityName};

#?? or do we expand the entities?

    my $pc = $self->{Parameter} ? "%" : "&";
    $FILE->print ("$pc$name;");
}

# Dom Spec says:
#     [...] but if such an Entity exists, then
#     the child list of the EntityReference node is the same as that of the
#     Entity node. 
#
#     The resolution of the children of the EntityReference (the replacement
#     value of the referenced Entity) may be lazily evaluated; actions by the
#     user (such as calling the childNodes method on the EntityReference
#     node) are assumed to trigger the evaluation.
sub getChildNodes
{
    my $self = shift;
    my $entity = $self->{Doc}->getEntity ($self->{EntityName});
    defined ($entity) ? $entity->getChildNodes : new EPrints::DOM::NodeList;
}

sub cloneNode
{
    my $self = shift;
    $self->{Doc}->createEntityReference ($self->{EntityName}, 
					 $self->{Parameter});
}

# NOTE: an EntityReference can't really have children, so rejectChild
# is not reimplemented (i.e. it always returns 0.)

######################################################################
package EPrints::DOM::AttDef;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
    import Carp;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

#------------------------------------------------------------
# Extra method implementations

# AttDef is not part of DOM Spec
sub new
{
    my ($class, $doc, $name, $attrType, $default, $fixed) = @_;

    croak new EPrints::DOM::DOMException (INVALID_CHARACTER_ERR,
				      "bad Attr name in AttDef [$name]")
	unless EPrints::DOM::isValidName ($name);

    my $self = bless {Doc	=> $doc,
		      Name	=> $name,
		      Type	=> $attrType}, $class;

    if (defined $default)
    {
	if ($default eq "#REQUIRED")
	{
	    $self->{Required} = 1;
	}
	elsif ($default eq "#IMPLIED")
	{
	    $self->{Implied} = 1;
	}
	else
	{
	    # strip off quotes - see Attlist handler in XML::Parser
	    $default =~ m#^(["'])(.*)['"]$#;
	    
	    $self->{Quote} = $1;	# keep track of the quote character
	    $self->{Default} = $self->setDefault ($2);
	    
#?? should default value be decoded - what if it contains e.g. "&amp;"
	}
    }
    $self->{Fixed} = $fixed if defined $fixed;

    $self;
}

sub getNodeType
{
    ATT_DEF_NODE;
}

sub getName
{
    $_[0]->{Name};
}

# So it can be added to a NamedNodeMap
sub getNodeName
{
    $_[0]->{Name};
}

sub getDefault
{
    $_[0]->{Default};
}

sub setDefault
{
    my ($self, $value) = @_;

    # specified=0, it's the default !
    my $attr = $self->{Doc}->createAttribute ($self->{Name}, undef, 0);
    $attr->{ReadOnly} = 1;

#?? this should be split over Text and EntityReference nodes, just like other
# Attr nodes - just expand the text for now
    $value = $self->expandEntityRefs ($value);
    $attr->addText ($value);
#?? reimplement in NoExpand mode!

    $attr;
}

sub isFixed
{
    $_[0]->{Fixed} || 0;
}

sub isRequired
{
    $_[0]->{Required} || 0;
}

sub isImplied
{
    $_[0]->{Implied} || 0;
}

sub print
{
    my ($self, $FILE) = @_;    

    my $name = $self->{Name};
    my $type = $self->{Type};
    my $fixed = $self->{Fixed};
    my $default = $self->{Default};

    $FILE->print ("$name $type");
    $FILE->print (" #FIXED") if defined $fixed;

    if ($self->{Required})
    {
	$FILE->print (" #REQUIRED");
    }
    elsif ($self->{Implied})
    {
	$FILE->print (" #IMPLIED");
    }
    elsif (defined ($default))
    {
	my $quote = $self->{Quote};
	$FILE->print (" $quote");
	for my $kid (@{$default->{C}})
	{
	    $kid->print ($FILE);
	}
	$FILE->print ($quote);	
    }
}

sub getDefaultString
{
    my $self = shift;
    my $default;

    if ($self->{Required})
    {
	return "#REQUIRED";
    }
    elsif ($self->{Implied})
    {
	return "#IMPLIED";
    }
    elsif (defined ($default = $self->{Default}))
    {
	my $quote = $self->{Quote};
	$default = $default->toString;
	return "$quote$default$quote";
    }
    undef;
}

sub cloneNode
{
    my $self = shift;
    my $node = new EPrints::DOM::AttDef ($self->{Doc}, $self->{Name}, $self->{Type},
				     undef, $self->{Fixed});

    $node->{Required} = 1 if $self->{Required};
    $node->{Implied} = 1 if $self->{Implied};
    $node->{Fixed} = $self->{Fixed} if defined $self->{Fixed};

    if (defined $self->{Default})
    {
	$node->{Default} = $self->{Default}->cloneNode(1);
    }
    $node->{Quote} = $self->{Quote};

    $node;
}

sub setOwnerDocument
{
    my ($self, $doc) = @_;
    $self->SUPER::setOwnerDocument ($doc);

    if (defined $self->{Default})
    {
	$self->{Default}->setOwnerDocument ($doc);
    }
}

######################################################################
package EPrints::DOM::AttlistDecl;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
    import Carp;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

#------------------------------------------------------------
# Extra method implementations

# AttlistDecl is not part of the DOM Spec
sub new
{
    my ($class, $doc, $name) = @_;

    croak new EPrints::DOM::DOMException (INVALID_CHARACTER_ERR, 
			      "bad Element TagName [$name] in AttlistDecl")
	unless EPrints::DOM::isValidName ($name);

    my $self = bless {Doc	=> $doc,
		      C		=> new EPrints::DOM::NodeList,
		      ReadOnly	=> 1,
		      Name	=> $name}, $class;

    $self->{A} = new EPrints::DOM::NamedNodeMap (Doc	=> $doc,
					     ReadOnly	=> 1,
					     Parent	=> $self);

    $self;
}

sub getNodeType
{
    ATTLIST_DECL_NODE;
}

sub getName
{
    $_[0]->{Name};
}

sub getNodeName
{
    $_[0]->{Name};
}

sub getAttDef
{
    my ($self, $attrName) = @_;
    $self->{A}->getNamedItem ($attrName);
}

sub addAttDef
{
    my ($self, $attrName, $type, $default, $fixed) = @_;
    my $node = $self->getAttDef ($attrName);

    if (defined $node)
    {
	# data will be ignored if already defined
	my $elemName = $self->getName;
	warn "multiple definitions of attribute $attrName for element $elemName, only first one is recognized";
    }
    else
    {
	$node = new EPrints::DOM::AttDef ($self->{Doc}, $attrName, $type, 
				      $default, $fixed);
	$self->{A}->setNamedItem ($node);
    }
    $node;
}

sub getDefaultAttrValue
{
    my ($self, $attr) = @_;
    my $attrNode = $self->getAttDef ($attr);
    (defined $attrNode) ? $attrNode->getDefault : undef;
}

sub cloneNode
{
    my ($self, $deep) = @_;
    my $node = $self->{Doc}->createAttlistDecl ($self->{Name});
    
    $node->{A} = $self->{A}->cloneNode ($deep);
    $node;
}

sub setOwnerDocument
{
    my ($self, $doc) = @_;
    $self->SUPER::setOwnerDocument ($doc);

    $self->{A}->setOwnerDocument ($doc);
}

sub print
{
    my ($self, $FILE) = @_;    

    my $name = $self->getName;
    my @attlist = @{$self->{A}->getValues};

    if (@attlist > 0)
    {
	$FILE->print ("<!ATTLIST $name");

	if (@attlist == 1)
	{
	    $FILE->print (" ");
	    $attlist[0]->print ($FILE);	    
	}
	else
	{
	    for my $attr (@attlist)
	    {
		$FILE->print ("\x0A  ");
		$attr->print ($FILE);
	    }
	}
	$FILE->print (">");
    }
}

######################################################################
package EPrints::DOM::ElementDecl;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
    import Carp;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

#------------------------------------------------------------
# Extra method implementations

# ElementDecl is not part of the DOM Spec
sub new
{
    my ($class, $doc, $name, $model) = @_;

    croak new EPrints::DOM::DOMException (INVALID_CHARACTER_ERR, 
			      "bad Element TagName [$name] in ElementDecl")
	unless EPrints::DOM::isValidName ($name);

    bless {Doc		=> $doc,
	   Name		=> $name,
	   ReadOnly	=> 1,
	   Model	=> $model}, $class;
}

sub getNodeType
{
    ELEMENT_DECL_NODE;
}

sub getName
{
    $_[0]->{Name};
}

sub getNodeName
{
    $_[0]->{Name};
}

sub getModel
{
    $_[0]->{Model};
}

sub setModel
{
    my ($self, $model) = @_;

    $self->{Model} = $model;
}

sub print
{
    my ($self, $FILE) = @_;    

    my $name = $self->{Name};
    my $model = $self->{Model};

    $FILE->print ("<!ELEMENT $name $model>");
}

sub cloneNode
{
    my $self = shift;
    $self->{Doc}->createElementDecl ($self->{Name}, $self->{Model});
}

######################################################################
package EPrints::DOM::Element;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
    import Carp;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

sub new
{
    my ($class, $doc, $tagName) = @_;

    if ($EPrints::DOM::SafeMode)
    {
	croak new EPrints::DOM::DOMException (INVALID_CHARACTER_ERR, 
				      "bad Element TagName [$tagName]")
	    unless EPrints::DOM::isValidName ($tagName);
    }

    my $self = bless {Doc	=> $doc,
		      C		=> new EPrints::DOM::NodeList,
		      TagName	=> $tagName}, $class;

    $self->{A} = new EPrints::DOM::NamedNodeMap (Doc	=> $doc,
					     Parent	=> $self);
    $self;
}

sub getNodeType
{
    ELEMENT_NODE;
}

sub getTagName
{
    $_[0]->{TagName};
}

sub getNodeName
{
    $_[0]->{TagName};
}

sub getAttributeNode
{
    my ($self, $name) = @_;
    $self->getAttributes->{$name};
}

sub getAttribute
{
    my ($self, $name) = @_;
    my $attr = $self->getAttributeNode ($name);
    (defined $attr) ? $attr->getValue : "";
}

sub setAttribute
{
    my ($self, $name, $val) = @_;

    croak new EPrints::DOM::DOMException (INVALID_CHARACTER_ERR,
			      "bad Attr Name [$name]")
	unless EPrints::DOM::isValidName ($name);

    croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
				      "node is ReadOnly")
	if $self->isReadOnly;

    my $node = $self->{A}->{$name};
    if (defined $node)
    {
	$node->setValue ($val);
    }
    else
    {
	$node = $self->{Doc}->createAttribute ($name, $val);
	$self->{A}->setNamedItem ($node);
    }
}

sub setAttributeNode
{
    my ($self, $node) = @_;
    my $attr = $self->{A};
    my $name = $node->getNodeName;

    # REC 1147
    if ($EPrints::DOM::SafeMode)
    {
	croak new EPrints::DOM::DOMException (WRONG_DOCUMENT_ERR,
				      "nodes belong to different documents")
	    if $self->{Doc} != $node->{Doc};

	croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
					  "node is ReadOnly")
	    if $self->isReadOnly;

	my $attrParent = $node->{UsedIn};
	croak new EPrints::DOM::DOMException (INUSE_ATTRIBUTE_ERR,
			      "Attr is already used by another Element")
	    if (defined ($attrParent) && $attrParent != $attr);
    }

    my $other = $attr->{$name};
    $attr->removeNamedItem ($name) if defined $other;

    $attr->setNamedItem ($node);

    $other;
}

sub removeAttributeNode
{
    my ($self, $node) = @_;

    croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
				      "node is ReadOnly")
	if $self->isReadOnly;

    my $attr = $self->{A};
    my $name = $node->getNodeName;
    my $attrNode = $attr->getNamedItem ($name);

#?? should it croak if it's the default value?
    croak new EPrints::DOM::DOMException (NOT_FOUND_ERR)
	unless $node == $attrNode;

    # Not removing anything if it's the default value already
    return undef unless $node->isSpecified;

    $attr->removeNamedItem ($name);

    # Substitute with default value if it's defined
    my $default = $self->getDefaultAttrValue ($name);
    if (defined $default)
    {
	my $oldIgnore = EPrints::DOM::ignoreReadOnly (1);	# temporarily

	$default = $default->cloneNode (1);
	$attr->setNamedItem ($default);

	EPrints::DOM::ignoreReadOnly ($oldIgnore);	# restore previous value
    }
    $node;
}

sub removeAttribute
{
    my ($self, $name) = @_;
    my $node = $self->{A}->getNamedItem ($name);

#?? could use dispose() to remove circular references for gc, but what if
#?? somebody is referencing it?
    $self->removeAttributeNode ($node) if defined $node;
}

sub cloneNode
{
    my ($self, $deep) = @_;
    my $node = $self->{Doc}->createElement ($self->getTagName);

    # Always clone the Attr nodes, even if $deep == 0
    $node->{A} = $self->{A}->cloneNode (1);	# deep=1
    $node->{A}->setParentNode ($node);

    $node->cloneChildren ($self, $deep);
    $node;
}

sub getAttributes
{
    $_[0]->{A};
}

#------------------------------------------------------------
# Extra method implementations

# Added for convenience
sub setTagName
{
    my ($self, $tagName) = @_;

    croak new EPrints::DOM::DOMException (INVALID_CHARACTER_ERR, 
				      "bad Element TagName [$tagName]")
        unless EPrints::DOM::isValidName ($tagName);

    $self->{TagName} = $tagName;
}

sub isReadOnly
{
    0;
}

# Added for optimization.
sub isElementNode
{
    1;
}

sub rejectChild
{
    my $t = $_[1]->getNodeType;

    $t != TEXT_NODE
    && $t != ENTITY_REFERENCE_NODE 
    && $t != PROCESSING_INSTRUCTION_NODE
    && $t != COMMENT_NODE
    && $t != CDATA_SECTION_NODE
    && $t != ELEMENT_NODE;
}

sub getDefaultAttrValue
{
    my ($self, $attr) = @_;
    $self->{Doc}->getDefaultAttrValue ($self->{TagName}, $attr);
}

sub dispose
{
    my $self = shift;

    $self->{A}->dispose;
    $self->SUPER::dispose;
}

sub setOwnerDocument
{
    my ($self, $doc) = @_;
    $self->SUPER::setOwnerDocument ($doc);

    $self->{A}->setOwnerDocument ($doc);
}

sub print
{
    my ($self, $FILE) = @_;    

    my $name = $self->{TagName};

    $FILE->print ("<$name");

    for my $att (@{$self->{A}->getValues})
    {
	# skip un-specified (default) Attr nodes
	if ($att->isSpecified)
	{
	    $FILE->print (" ");
	    $att->print ($FILE);
	}
    }

    my @kids = @{$self->{C}};
    if (@kids > 0)
    {
	$FILE->print (">");
	for my $kid (@kids)
	{
	    $kid->print ($FILE);
	}
	$FILE->print ("</$name>");
    }
    else
    {
	my $style = &$EPrints::DOM::TagStyle ($name, $self);
	if ($style == 0)
	{
	    $FILE->print ("/>");
	}
	elsif ($style == 1)
	{
	    $FILE->print ("></$name>");
	}
	else
	{
	    $FILE->print (" />");
	}
    }
}

######################################################################
package EPrints::DOM::CharacterData;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
    import Carp;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

# CharacterData nodes should never be created directly, only subclassed!

sub appendData
{
    my ($self, $data) = @_;

    if ($EPrints::DOM::SafeMode)
    {
	croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
					  "node is ReadOnly")
	    if $self->isReadOnly;
    }
    $self->{Data} .= $data;
}

sub deleteData
{
    my ($self, $offset, $count) = @_;

    croak new EPrints::DOM::DOMException (INDEX_SIZE_ERR,
				      "bad offset [$offset]")
	if ($offset < 0 || $offset >= length ($self->{Data}));
#?? DOM Spec says >, but >= makes more sense!

    croak new EPrints::DOM::DOMException (INDEX_SIZE_ERR,
				      "negative count [$count]")
	if $count < 0;
 
    croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
				      "node is ReadOnly")
	if $self->isReadOnly;

    substr ($self->{Data}, $offset, $count) = "";
}

sub getData
{
    $_[0]->{Data};
}

sub getLength
{
    length $_[0]->{Data};
}

sub insertData
{
    my ($self, $offset, $data) = @_;

    croak new EPrints::DOM::DOMException (INDEX_SIZE_ERR,
				      "bad offset [$offset]")
	if ($offset < 0 || $offset >= length ($self->{Data}));
#?? DOM Spec says >, but >= makes more sense!

    croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
				      "node is ReadOnly")
	if $self->isReadOnly;

    substr ($self->{Data}, $offset, 0) = $data;
}

sub replaceData
{
    my ($self, $offset, $count, $data) = @_;

    croak new EPrints::DOM::DOMException (INDEX_SIZE_ERR,
				      "bad offset [$offset]")
	if ($offset < 0 || $offset >= length ($self->{Data}));
#?? DOM Spec says >, but >= makes more sense!

    croak new EPrints::DOM::DOMException (INDEX_SIZE_ERR,
				      "negative count [$count]")
	if $count < 0;
 
    croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
				      "node is ReadOnly")
	if $self->isReadOnly;

    substr ($self->{Data}, $offset, $count) = $data;
}

sub setData
{
    my ($self, $data) = @_;

    croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
				      "node is ReadOnly")
	if $self->isReadOnly;

    $self->{Data} = $data;
}

sub substringData
{
    my ($self, $offset, $count) = @_;
    my $data = $self->{Data};

    croak new EPrints::DOM::DOMException (INDEX_SIZE_ERR,
				      "bad offset [$offset]")
	if ($offset < 0 || $offset >= length ($data));
#?? DOM Spec says >, but >= makes more sense!

    croak new EPrints::DOM::DOMException (INDEX_SIZE_ERR,
				      "negative count [$count]")
	if $count < 0;
    
    substr ($data, $offset, $count);
}

sub getNodeValue
{
    $_[0]->getData;
}

sub setNodeValue
{
    $_[0]->setData ($_[1]);
}

######################################################################
package EPrints::DOM::CDATASection;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::CharacterData );

sub new
{
    my ($class, $doc, $data) = @_;
    bless {Doc	=> $doc, 
	   Data	=> $data}, $class;
}

sub getNodeName
{
    "#cdata-section";
}

sub getNodeType
{
    CDATA_SECTION_NODE;
}

sub cloneNode
{
    my $self = shift;
    $self->{Doc}->createCDATASection ($self->getData);
}

#------------------------------------------------------------
# Extra method implementations

sub isReadOnly
{
    0;
}

sub print
{
    my ($self, $FILE) = @_;
    $FILE->print ("<![CDATA[");
    $FILE->print (EPrints::DOM::encodeCDATA ($self->getData));
    $FILE->print ("]]>");
}

######################################################################
package EPrints::DOM::Comment;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
    import Carp;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::CharacterData );

#?? setData - could check comment for double minus

sub new
{
    my ($class, $doc, $data) = @_;
    bless {Doc	=> $doc, 
	   Data	=> $data}, $class;
}

sub getNodeType
{
    COMMENT_NODE;
}

sub getNodeName
{
    "#comment";
}

sub cloneNode
{
    my $self = shift;
    $self->{Doc}->createComment ($self->getData);
}

#------------------------------------------------------------
# Extra method implementations

sub isReadOnly
{
    return 0 if $EPrints::DOM::IgnoreReadOnly;

    my $pa = $_[0]->{Parent};
    defined ($pa) ? $pa->isReadOnly : 0;
}

sub print
{
    my ($self, $FILE) = @_;
    my $comment = EPrints::DOM::encodeComment ($self->{Data});

    $FILE->print ("<!--$comment-->");
}

######################################################################
package EPrints::DOM::Text;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
    import Carp;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::CharacterData );

sub new
{
    my ($class, $doc, $data) = @_;
    bless {Doc	=> $doc, 
	   Data	=> $data}, $class;
}

sub getNodeType
{
    TEXT_NODE;
}

sub getNodeName
{
    "#text";
}

sub splitText
{
    my ($self, $offset) = @_;

    my $data = $self->getData;
    croak new EPrints::DOM::DOMException (INDEX_SIZE_ERR,
				      "bad offset [$offset]")
	if ($offset < 0 || $offset >= length ($data));
#?? DOM Spec says >, but >= makes more sense!

    croak new EPrints::DOM::DOMException (NO_MODIFICATION_ALLOWED_ERR,
				      "node is ReadOnly")
	if $self->isReadOnly;

    my $rest = substring ($data, $offset);

    $self->setData (substring ($data, 0, $offset));
    my $node = $self->{Doc}->createTextNode ($rest);

    # insert new node after this node
    $self->{Parent}->insertAfter ($node, $self);

    $node;
}

sub cloneNode
{
    my $self = shift;
    $self->{Doc}->createTextNode ($self->getData);
}

#------------------------------------------------------------
# Extra method implementations

sub isReadOnly
{
    0;
}

sub print
{
    my ($self, $FILE) = @_;
    $FILE->print (EPrints::DOM::encodeText ($self->getData, "<&"));
}

sub isTextNode
{
    1;
}

######################################################################
package EPrints::DOM::XMLDecl;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

#------------------------------------------------------------
# Extra method implementations

# XMLDecl is not part of the DOM Spec
sub new
{
    my ($class, $doc, $version, $encoding, $standalone) = @_;
    my $self = bless {Doc => $doc}, $class;

    $self->{Version} = $version if defined $version;
    $self->{Encoding} = $encoding if defined $encoding;
    $self->{Standalone} = $standalone if defined $standalone;

    $self;
}

sub setVersion
{
    if (defined $_[1])
    {
	$_[0]->{Version} = $_[1];
    }
    else
    {
	delete $_[0]->{Version};
    }
}

sub getVersion
{
    $_[0]->{Version};
}

sub setEncoding
{
    if (defined $_[1])
    {
	$_[0]->{Encoding} = $_[1];
    }
    else
    {
	delete $_[0]->{Encoding};
    }
}

sub getEncoding
{
    $_[0]->{Encoding};
}

sub setStandalone
{
    if (defined $_[1])
    {
	$_[0]->{Standalone} = $_[1];
    }
    else
    {
	delete $_[0]->{Standalone};
    }
}

sub getStandalone
{
    $_[0]->{Standalone};
}

sub getNodeType
{
    XML_DECL_NODE;
}

sub cloneNode
{
    my $self = shift;

    new EPrints::DOM::XMLDecl ($self->{Doc}, $self->{Version}, 
			   $self->{Encoding}, $self->{Standalone});
}

sub print
{
    my ($self, $FILE) = @_;

    my $version = $self->{Version};
    my $encoding = $self->{Encoding};
    my $standalone = $self->{Standalone};
    $standalone = ($standalone ? "yes" : "no") if defined $standalone;

    $FILE->print ("<?xml");
    $FILE->print (" version=\"$version\"")	 if defined $version;    
    $FILE->print (" encoding=\"$encoding\"")	 if defined $encoding;
    $FILE->print (" standalone=\"$standalone\"") if defined $standalone;
    $FILE->print ("?>");
}

######################################################################
package EPrints::DOM::DocumentType;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

sub new
{
    my $class = shift;
    my $doc = shift;

    my $self = bless {Doc	=> $doc,
		      ReadOnly	=> 1,
		      C		=> new EPrints::DOM::NodeList}, $class;

    $self->{Entities} =  new EPrints::DOM::NamedNodeMap (Doc	=> $doc,
						     Parent	=> $self,
						     ReadOnly	=> 1);
    $self->{Notations} = new EPrints::DOM::NamedNodeMap (Doc	=> $doc,
						     Parent	=> $self,
						     ReadOnly	=> 1);
    $self->setParams (@_);
    $self;
}

sub getNodeType
{
    DOCUMENT_TYPE_NODE;
}

sub getNodeName
{
    $_[0]->{Name};
}

sub getName
{
    $_[0]->{Name};
}

sub getEntities
{
    $_[0]->{Entities};
}

sub getNotations
{
    $_[0]->{Notations};
}

sub setParentNode
{
    my ($self, $parent) = @_;
    $self->SUPER::setParentNode ($parent);

    $parent->{Doctype} = $self 
	if $parent->getNodeType == DOCUMENT_NODE;
}

sub cloneNode
{
    my ($self, $deep) = @_;

    my $node = new EPrints::DOM::DocumentType ($self->{Doc}, $self->{Name}, 
					   $self->{SysId}, $self->{PubId}, 
					   $self->{Internal});

#?? does it make sense to make a shallow copy?

    # clone the NamedNodeMaps
    $node->{Entities} = $self->{Entities}->cloneNode ($deep);

    $node->{Notations} = $self->{Notations}->cloneNode ($deep);

    $node->cloneChildren ($self, $deep);

    $node;
}

#------------------------------------------------------------
# Extra method implementations

sub getSysId
{
    $_[0]->{SysId};
}

sub getPubId
{
    $_[0]->{PubId};
}

sub setSysId
{
    $_[0]->{SysId} = $_[1];
}

sub setPubId
{
    $_[0]->{PubId} = $_[1];
}

sub setName
{
    $_[0]->{Name} = $_[1];
}

sub removeChildHoodMemories
{
    my ($self, $dontWipeReadOnly) = @_;

    my $parent = $self->{Parent};
    if (defined $parent && $parent->getNodeType == DOCUMENT_NODE)
    {
	delete $parent->{Doctype};
    }
    $self->SUPER::removeChildHoodMemories;
}

sub dispose
{
    my $self = shift;

    $self->{Entities}->dispose;
    $self->{Notations}->dispose;
    $self->SUPER::dispose;
}

sub setOwnerDocument
{
    my ($self, $doc) = @_;
    $self->SUPER::setOwnerDocument ($doc);

    $self->{Entities}->setOwnerDocument ($doc);
    $self->{Notations}->setOwnerDocument ($doc);
}

sub expandEntity
{
    my ($self, $ent, $param) = @_;

    my $kid = $self->{Entities}->getNamedItem ($ent);
    return $kid->getValue
	if (defined ($kid) && $param == $kid->isParameterEntity);

    undef;	# entity not found
}

sub getAttlistDecl
{
    my ($self, $elemName) = @_;
    for my $kid (@{$_[0]->{C}})
    {
	return $kid if ($kid->getNodeType == ATTLIST_DECL_NODE &&
			$kid->getName eq $elemName);
    }
    undef;	# not found
}

sub getElementDecl
{
    my ($self, $elemName) = @_;
    for my $kid (@{$_[0]->{C}})
    {
	return $kid if ($kid->getNodeType == ELEMENT_DECL_NODE &&
			$kid->getName eq $elemName);
    }
    undef;	# not found
}

sub addElementDecl
{
    my ($self, $name, $model) = @_;
    my $node = $self->getElementDecl ($name);

#?? could warn
    unless (defined $node)
    {
	$node = $self->{Doc}->createElementDecl ($name, $model);
	$self->appendChild ($node);
    }
    $node;
}

sub addAttlistDecl
{
    my ($self, $name) = @_;
    my $node = $self->getAttlistDecl ($name);

    unless (defined $node)
    {
	$node = $self->{Doc}->createAttlistDecl ($name);
	$self->appendChild ($node);
    }
    $node;
}

sub addNotation
{
    my $self = shift;
    my $node = $self->{Doc}->createNotation (@_);
    $self->{Notations}->setNamedItem ($node);
    $node;
}

sub addEntity
{
    my $self = shift;
    my $node = $self->{Doc}->createEntity (@_);

    $self->{Entities}->setNamedItem ($node);
    $node;
}

# All AttDefs for a certain Element are merged into a single ATTLIST
sub addAttDef
{
    my $self = shift;
    my $elemName = shift;

    # create the AttlistDecl if it doesn't exist yet
    my $elemDecl = $self->addAttlistDecl ($elemName);
    $elemDecl->addAttDef (@_);
}

sub getDefaultAttrValue
{
    my ($self, $elem, $attr) = @_;
    my $elemNode = $self->getAttlistDecl ($elem);
    (defined $elemNode) ? $elemNode->getDefaultAttrValue ($attr) : undef;
}

sub getEntity
{
    my ($self, $entity) = @_;
    $self->{Entities}->getNamedItem ($entity);
}

sub setParams
{
    my ($self, $name, $sysid, $pubid, $internal) = @_;

    $self->{Name} = $name;

#?? not sure if we need to hold on to these...
    $self->{SysId} = $sysid if defined $sysid;
    $self->{PubId} = $pubid if defined $pubid;
    $self->{Internal} = $internal if defined $internal;

    $self;
}

sub rejectChild
{
    # DOM Spec says: DocumentType -- no children
    not $EPrints::DOM::IgnoreReadOnly;
}

sub print
{
    my ($self, $FILE) = @_;

    my $name = $self->{Name};

    my $sysId = $self->{SysId};
    my $pubId = $self->{PubId};

    $FILE->print ("<!DOCTYPE $name");
    if (defined $pubId)
    {
	$FILE->print (" PUBLIC \"$pubId\" \"$sysId\"");
    }
    elsif (defined $sysId)
    {
	$FILE->print (" SYSTEM \"$sysId\"");
    }

    my @entities = @{$self->{Entities}->getValues};
    my @notations = @{$self->{Notations}->getValues};
    my @kids = @{$self->{C}};

    if (@entities || @notations || @kids)
    {
	$FILE->print (" [\x0A");

	for my $kid (@entities)
	{
	    $FILE->print (" ");
	    $kid->print ($FILE);
	    $FILE->print ("\x0A");
	}

	for my $kid (@notations)
	{
	    $FILE->print (" ");
	    $kid->print ($FILE);
	    $FILE->print ("\x0A");
	}

	for my $kid (@kids)
	{
	    $FILE->print (" ");
	    $kid->print ($FILE);
	    $FILE->print ("\x0A");
	}
	$FILE->print ("]");
    }
    $FILE->print (">");
}

######################################################################
package EPrints::DOM::DocumentFragment;
######################################################################

BEGIN 
{
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

sub new
{
    my ($class, $doc) = @_;
    bless {Doc	=> $doc,
	   C	=> new EPrints::DOM::NodeList}, $class;
}

sub getNodeType
{
    DOCUMENT_FRAGMENT_NODE;
}

sub getNodeName
{
    "#document-fragment";
}

sub cloneNode
{
    my ($self, $deep) = @_;
    my $node = $self->{Doc}->createDocumentFragment;

    $node->cloneChildren ($self, $deep);
    $node;
}

#------------------------------------------------------------
# Extra method implementations

sub isReadOnly
{
    0;
}

sub print
{
    my ($self, $FILE) = @_;

    for my $node (@{$self->{C}})
    {
	$node->print ($FILE);
    }
}

sub rejectChild
{
    my $t = $_[1]->getNodeType;

    $t != TEXT_NODE
	&& $t != ENTITY_REFERENCE_NODE 
	&& $t != PROCESSING_INSTRUCTION_NODE
	&& $t != COMMENT_NODE
	&& $t != CDATA_SECTION_NODE
	&& $t != ELEMENT_NODE;
}

sub isDocumentFragmentNode
{
    1;
}

######################################################################
package EPrints::DOM::Document;
######################################################################

BEGIN 
{
    import Carp;
    import EPrints::DOM::Node;
    import EPrints::DOM::DOMException;
}

use vars qw( @ISA );
@ISA = qw( EPrints::DOM::Node );

sub new
{
    my ($class) = @_;
    my $self = bless {C => new EPrints::DOM::NodeList}, $class;

    # keep Doc pointer, even though getOwnerDocument returns undef
    $self->{Doc} = $self;

    $self;
}

sub getNodeType
{
    DOCUMENT_NODE;
}

sub getNodeName
{
    "#document";
}

#?? not sure about keeping a fixed order of these nodes....
sub getDoctype
{
    $_[0]->{Doctype};
}

sub getDocumentElement
{
    my ($self) = @_;
    for my $kid (@{$self->{C}})
    {
	return $kid if $kid->isElementNode;
    }
    undef;
}

sub getOwnerDocument
{
    undef;
}

sub getImplementation 
{
    $EPrints::DOM::DOMImplementation::Singleton;
}

#
# Added extra parameters ($val, $specified) that are passed straight to the
# Attr constructor
# 
sub createAttribute
{
    new EPrints::DOM::Attr (@_);
}

sub createCDATASection
{
    new EPrints::DOM::CDATASection (@_);
}

sub createComment
{
    new EPrints::DOM::Comment (@_);

}

sub createElement
{
    new EPrints::DOM::Element (@_);
}

sub createTextNode
{
    new EPrints::DOM::Text (@_);
}

sub createProcessingInstruction
{
    new EPrints::DOM::ProcessingInstruction (@_);
}

sub createEntityReference
{
    new EPrints::DOM::EntityReference (@_);
}

sub createDocumentFragment
{
    new EPrints::DOM::DocumentFragment (@_);
}

sub createDocumentType
{
    new EPrints::DOM::DocumentType (@_);
}

sub cloneNode
{
    my ($self, $deep) = @_;
    my $node = new EPrints::DOM::Document;

    $node->cloneChildren ($self, $deep);

    my $xmlDecl = $self->{XmlDecl};
    $node->{XmlDecl} = $xmlDecl->cloneNode ($deep) if defined $xmlDecl;

    $node;
}

sub appendChild
{
    my ($self, $node) = @_;

    # Extra check: make sure sure we don't end up with more than 1 Elements.
    # Don't worry about multiple DocType nodes, because DocumentFragment
    # can't contain DocType nodes.

    my @nodes = ($node);
    @nodes = @{$node->{C}}
        if $node->getNodeType == DOCUMENT_FRAGMENT_NODE;
    
    my $elem = 0;
    for my $n (@nodes)
    {
	$elem++ if $n->isElementNode;
    }
    
    if ($elem > 0 && defined ($self->getDocumentElement))
    {
	croak new EPrints::DOM::DOMException (HIERARCHY_REQUEST_ERR,
					  "document can have only 1 Element");
    }
    $self->SUPER::appendChild ($node);
}

sub insertBefore
{
    my ($self, $node, $refNode) = @_;

    # Extra check: make sure sure we don't end up with more than 1 Elements.
    # Don't worry about multiple DocType nodes, because DocumentFragment
    # can't contain DocType nodes.

    my @nodes = ($node);
    @nodes = @{$node->{C}}
	if $node->getNodeType == DOCUMENT_FRAGMENT_NODE;
    
    my $elem = 0;
    for my $n (@nodes)
    {
	$elem++ if $n->isElementNode;
    }
    
    if ($elem > 0 && defined ($self->getDocumentElement))
    {
	croak new EPrints::DOM::DOMException (HIERARCHY_REQUEST_ERR,
					  "document can have only 1 Element");
    }
    $self->SUPER::insertBefore ($node, $refNode);
}

sub replaceChild
{
    my ($self, $node, $refNode) = @_;

    # Extra check: make sure sure we don't end up with more than 1 Elements.
    # Don't worry about multiple DocType nodes, because DocumentFragment
    # can't contain DocType nodes.

    my @nodes = ($node);
    @nodes = @{$node->{C}}
	if $node->getNodeType == DOCUMENT_FRAGMENT_NODE;
    
    my $elem = 0;
    $elem-- if $refNode->isElementNode;

    for my $n (@nodes)
    {
	$elem++ if $n->isElementNode;
    }
    
    if ($elem > 0 && defined ($self->getDocumentElement))
    {
	croak new EPrints::DOM::DOMException (HIERARCHY_REQUEST_ERR,
					  "document can have only 1 Element");
    }
    $self->SUPER::appendChild ($node, $refNode);
}

#------------------------------------------------------------
# Extra method implementations

sub isReadOnly
{
    0;
}

sub print
{
    my ($self, $FILE) = @_;

    my $xmlDecl = $self->getXMLDecl;
    if (defined $xmlDecl)
    {
	$xmlDecl->print ($FILE);
	$FILE->print ("\x0A");
    }

    for my $node (@{$self->{C}})
    {
	$node->print ($FILE);
	$FILE->print ("\x0A");
    }
}

sub setDoctype
{
    my ($self, $doctype) = @_;
    my $oldDoctype = $self->{Doctype};
    if (defined $oldDoctype)
    {
	$self->replaceChild ($doctype, $oldDoctype);
    }
    else
    {
#?? before root element!
	$self->appendChild ($doctype);
    }
    $_[0]->{Doctype} = $_[1];
}

sub removeDoctype
{
    my $self = shift;
    my $doctype = $self->removeChild ($self->{Doctype});

    delete $self->{Doctype};
    $doctype;
}

sub rejectChild
{
    my $t = $_[1]->getNodeType;
    $t != ELEMENT_NODE
	&& $t != PROCESSING_INSTRUCTION_NODE
	&& $t != COMMENT_NODE
	&& $t != DOCUMENT_TYPE_NODE;
}

sub expandEntity
{
    my ($self, $ent, $param) = @_;
    my $doctype = $self->getDoctype;

    (defined $doctype) ? $doctype->expandEntity ($ent, $param) : undef;
}

sub getDefaultAttrValue
{
    my ($self, $elem, $attr) = @_;
    
    my $doctype = $self->getDoctype;

    (defined $doctype) ? $doctype->getDefaultAttrValue ($elem, $attr) : undef;
}

sub getEntity
{
    my ($self, $entity) = @_;
    
    my $doctype = $self->getDoctype;

    (defined $doctype) ? $doctype->getEntity ($entity) : undef;
}

sub dispose
{
    my $self = shift;

    $self->{XmlDecl}->dispose if defined $self->{XmlDecl};
    delete $self->{XmlDecl};
    delete $self->{Doctype};
    $self->SUPER::dispose;
}

sub setOwnerDocument
{
    # Do nothing, you can't change the owner document!
}

sub getXMLDecl
{
    $_[0]->{XmlDecl};
}

sub setXMLDecl
{
    $_[0]->{XmlDecl} = $_[1];
}

sub createXMLDecl
{
    new EPrints::DOM::XMLDecl (@_);
}

sub createNotation
{
    new EPrints::DOM::Notation (@_);
}

sub createElementDecl
{
    new EPrints::DOM::ElementDecl (@_);
}

sub createAttlistDecl
{
    new EPrints::DOM::AttlistDecl (@_);
}

sub createEntity
{
    new EPrints::DOM::Entity (@_);
}

######################################################################
package EPrints::DOM::Parser;
######################################################################
use vars qw ( @ISA );
@ISA = qw( XML::Parser );

sub new
{
    my ($class, %args) = @_;

    $args{Style} = 'cjgDom';
    $class->SUPER::new (%args);
}

# This method needed to be overriden so we can restore some global 
# variables when an exception is thrown
sub parse
{
    my $self = shift;

    local $XML::Parser::cjgDom::_DP_doc;
    local $XML::Parser::cjgDom::_DP_elem;
    local $XML::Parser::cjgDom::_DP_doctype;
    local $XML::Parser::cjgDom::_DP_in_prolog;
    local $XML::Parser::cjgDom::_DP_end_doc;
    local $XML::Parser::cjgDom::_DP_saw_doctype;
    local $XML::Parser::cjgDom::_DP_in_CDATA;
    local $XML::Parser::cjgDom::_DP_keep_CDATA;
    local $XML::Parser::cjgDom::_DP_last_text;


    # Temporarily disable checks that Expat already does (for performance)
    local $EPrints::DOM::SafeMode = 0;
    # Temporarily disable ReadOnly checks
    local $EPrints::DOM::IgnoreReadOnly = 1;

    my $ret;
    eval {
	$ret = $self->SUPER::parse (@_);
    };
    my $err = $@;

    if ($err)
    {
	my $doc = $XML::Parser::cjgDom::_DP_doc;
	if ($doc)
	{
	    $doc->dispose;
	}
	die $err;
    }

    $ret;
}

######################################################################
package XML::Parser::CjgDom;
######################################################################

use vars qw( $_DP_doc
	     $_DP_elem
	     $_DP_doctype
	     $_DP_in_prolog
	     $_DP_end_doc
	     $_DP_saw_doctype
	     $_DP_in_CDATA
	     $_DP_keep_CDATA
	     $_DP_last_text
	   );

# This adds a new Style to the XML::Parser class.
# From now on you can say: $parser = new XML::Parser ('Style' => 'cjgDom' );
# but that is *NOT* how a regular user should use it!
$XML::Parser::Built_In_Styles{CjgDom} = 1;

sub Init
{
    $_DP_elem = $_DP_doc = new EPrints::DOM::Document();
    $_DP_doctype = new EPrints::DOM::DocumentType ($_DP_doc);
    $_DP_doc->setDoctype ($_DP_doctype);
    $_DP_keep_CDATA = $_[0]->{KeepCDATA};
  
    # Prepare for document prolog
    $_DP_in_prolog = 1;
#    $expat->{DOM_inProlog} = 1;

    # We haven't passed the root element yet
    $_DP_end_doc = 0;

    undef $_DP_last_text;
}

sub Final
{
    unless ($_DP_saw_doctype)
    {
	my $doctype = $_DP_doc->removeDoctype;
	$doctype->dispose;
    }
    $_DP_doc;
}

sub Char
{
    my $str = $_[1];

    if ($_DP_in_CDATA && $_DP_keep_CDATA)
    {
	undef $_DP_last_text;
	# Merge text with previous node if possible
	$_DP_elem->addCDATA ($str);
    }
    else
    {
	# Merge text with previous node if possible
	# Used to be:	$expat->{DOM_Element}->addText ($str);
	if ($_DP_last_text)
	{
	    $_DP_last_text->{Data} .= $str;
	}
	else
	{
	    $_DP_last_text = $_DP_doc->createTextNode ($str);
	    $_DP_last_text->{Parent} = $_DP_elem;
	    push @{$_DP_elem->{C}}, $_DP_last_text;
	}
    }
}

sub Start
{
    my ($expat, $elem, @attr) = @_;
    my $parent = $_DP_elem;
    my $doc = $_DP_doc;
    
    if ($parent == $doc)
    {
	# End of document prolog, i.e. start of first Element
	$_DP_in_prolog = 0;
    }
    
    undef $_DP_last_text;
    my $node = $doc->createElement ($elem);
    $_DP_elem = $node;
    $parent->appendChild ($node);
    
    my $first_default = $expat->specified_attr;
    my $i = 0;
    my $n = @attr;
    while ($i < $n)
    {
	my $specified = $i < $first_default;
	my $name = $attr[$i++];
	undef $_DP_last_text;
	my $attr = $doc->createAttribute ($name, $attr[$i++], $specified);
	$node->setAttributeNode ($attr);
    }
}

sub End
{
    $_DP_elem = $_DP_elem->{Parent};
    undef $_DP_last_text;

    # Check for end of root element
    $_DP_end_doc = 1 if ($_DP_elem == $_DP_doc);
}

# Called at end of file, i.e. whitespace following last closing tag
# Also for Entity references
# May also be called at other times...
sub Default
{
    my ($expat, $str) = @_;

#    shift; deb ("Default", @_);

    if ($_DP_in_prolog)	# still processing Document prolog...
    {
#?? could try to store this text later
#?? I've only seen whitespace here so far
    }
    elsif (!$_DP_end_doc)	# ignore whitespace at end of Document
    {
#	if ($expat->{NoExpand})
#	{
	    $str =~ /^&(.+);$/os;
	    return unless defined ($1);
	    # Got a TextDecl (<?xml ...?>) from an external entity here once

	    $_DP_elem->appendChild (
			$_DP_doc->createEntityReference ($1));
	    undef $_DP_last_text;
#	}
#	else
#	{
#	    $expat->{DOM_Element}->addText ($str);
#	}
    }
}

# XML::Parser 2.19 added support for CdataStart and CdataEnd handlers
# If they are not defined, the Default handler is called instead
# with the text "<![CDATA[" and "]]"
sub CdataStart
{
    $_DP_in_CDATA = 1;
}

sub CdataEnd
{
    $_DP_in_CDATA = 0;
}

sub Comment
{
    undef $_DP_last_text;
    my $comment = $_DP_doc->createComment ($_[1]);
    $_DP_elem->appendChild ($comment);
}

sub deb
{
    return;

    my $name = shift;
    print "$name (" . join(",", map {defined($_)?$_ : "(undef)"} @_) . ")\n";
}

sub Doctype
{
    my $expat = shift;
#    deb ("Doctype", @_);

    $_DP_doctype->setParams (@_);
    $_DP_saw_doctype = 1;
}

sub Attlist
{
    my $expat = shift;
#    deb ("Attlist", @_);

    $_DP_doctype->addAttDef (@_);
}

sub XMLDecl
{
    my $expat = shift;
#    deb ("XMLDecl", @_);

    undef $_DP_last_text;
    $_DP_doc->setXMLDecl (new EPrints::DOM::XMLDecl ($_DP_doc, @_));
}

sub Entity
{
    my $expat = shift;
#    deb ("Entity", @_);
    
    # Parameter Entities names are passed starting with '%'
    my $parameter = 0;
    if ($_[0] =~ /^%(.*)/s)
    {
	$_[0] = $1;
	$parameter = 1;
    }

    undef $_DP_last_text;
    $_DP_doctype->addEntity ($parameter, @_);
}

# Unparsed is called when it encounters e.g:
#
#   <!ENTITY logo SYSTEM "http://server/logo.gif" NDATA gif>
#
sub Unparsed
{
    Entity (@_);	# same as regular ENTITY, as far as DOM is concerned
}

sub Element
{
    shift;
#    deb ("Element", @_);

    undef $_DP_last_text;
    $_DP_doctype->addElementDecl (@_);
}

sub Notation
{
    shift;
#    deb ("Notation", @_);

    undef $_DP_last_text;
    $_DP_doctype->addNotation (@_);
}

sub Proc
{
    shift;
#    deb ("Proc", @_);

    undef $_DP_last_text;
    $_DP_elem->appendChild (new EPrints::DOM::ProcessingInstruction ($_DP_doc, @_));
}

# ExternEnt is called when an external entity, such as:
#
#	<!ENTITY externalEntity PUBLIC "-//Enno//TEXT Enno's description//EN" 
#	                        "http://server/descr.txt">
#
# is referenced in the document, e.g. with: &externalEntity;
# If ExternEnt is not specified, the entity reference is passed to the Default
# handler as e.g. "&externalEntity;", where an EntityReference onbject is added.
#
#sub ExternEnt
#{
#    deb ("ExternEnt", @_);
#}

1; # module return code
