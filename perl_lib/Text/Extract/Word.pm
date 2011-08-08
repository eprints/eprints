package Text::Extract::Word;

use strict;
use warnings;

our $VERSION = 0.02;

use base qw(Exporter);

our @EXPORT_OK = qw(get_all_text);

#use Smart::Comments;

use Carp;
use Encode;
use POSIX;
use OLE::Storage_Lite;
use IO::File;
use Scalar::Util;

sub new {
    my ($this, @options) = @_;
    my $class = ref($this) || $this;
    
    my $self = { };
    bless $self, $class;
    _initialize($self, @options);
    return $self;
}

sub _initialize {
    my ($self, @options) = @_;
    my $value = shift(@options);
    if (@options) {
        carp("Ignored additional parameters to constructor");   
    }
    if (Scalar::Util::openhandle($value)) {
        $self->{_fh} = $value;
    } elsif (-e $value) {
        my $oIo = IO::File->new();
        $oIo->open($value, "<") or croak("Can't open $value: $!");
        binmode($oIo);
        $self->{_fh} = $oIo;
    } else {
        croak("Invalid parameter to constructor: $value should be a file handle or file name");
    }
    _extract_stream($self);
}

sub _compare_ranges {
    my ($range1, $range2) = @_;
    return ($range1->[0] <=> $range2->[0]);
}

sub _extract_stream {
    my ($self) = @_;
    
    my $fh = $self->{_fh};
    my $ofs = OLE::Storage_Lite->new($fh);
    my $name = encode("UCS-2LE", "WordDocument");
    my @pps = $ofs->getPpsSearch([$name], 1, 1);
    croak("This does not seem to be a Word document") unless (@pps);
    
    # OK, at this stage, we have the word stream. Now we need to start reading from it.
    my $data = $pps[0]->{Data};
    $self->{_data} = $data;
    
    my $magic = unpack("v", substr($data, 0x0000, 2));
    croak(sprintf("This does not seem to be a Word document, but it is pretending to be one: %x", $magic)) unless ($magic == 0xa5ec);
    
    my $flags = unpack("v", substr($data, 0x000A, 2));
    my $table = ($flags & 0x0200) ? "1Table" : "0Table";
    $table = encode("UCS-2LE", $table);
    
    @pps = $ofs->getPpsSearch([$table], 1, 1);
    confess("Internal error: could not locate table stream") unless (@pps);
    
    $table = $pps[0]->{Data};
    $self->{_table} = $table;
    
    my $fcMin = unpack("V", substr($data, 0x0018, 4));
    my $ccpText = unpack("V", substr($data, 0x004c, 4));
    my $ccpFtn = unpack("V", substr($data, 0x0050, 4));
    my $ccpHdd = unpack("V", substr($data, 0x0054, 4));
    my $ccpAtn = unpack("V", substr($data, 0x005c, 4));
    
    $self->{_fcMin} = $fcMin;
    $self->{_ccpText} = $ccpText;
    $self->{_ccpFtn} = $ccpFtn;
    $self->{_ccpHdd} = $ccpHdd;
    $self->{_ccpAtn} = $ccpAtn;
    
    my $charPLC = unpack("V", substr($data, 0x00fa, 4));
    my $charPlcSize = unpack("V", substr($data, 0x00fe, 4));
    my $parPLC = unpack("V", substr($data, 0x0102, 4));
    my $parPlcSize = unpack("V", substr($data, 0x0106, 4));

    # get the location of the piece table
    my $complexOffset = unpack("V", substr($data, 0x01a2, 4));

### fcMin:   $fcMin
### ccpText: $ccpText
### ccpFtn:  $ccpFtn
### ccpHdd:  $ccpHdd
### ccpAtn:  $ccpAtn
### end:     $ccpText + $ccpFtn + $ccpHdd + $ccpAtn

    # Read character positioning data positions
    my $fcPlcfBteChpx = unpack("V", substr($data, 0x0fa, 4));
    my $lcbPlcfBteChpx = unpack("V", substr($data, 0x0fe, 4));
    $self->{_fcPlcfBteChpx} = $fcPlcfBteChpx;
    $self->{_lcbPlcfBteChpx} = $lcbPlcfBteChpx;

    _get_bookmarks($self);

    my @pieces = _find_text(\$table, $complexOffset);
    @pieces = sort { $a->{start} <=> $b->{start} } @pieces;
    
    _get_text(\$data, \@pieces);
    
    $self->{_pieces} = \@pieces;
}

sub _get_bookmarks {
    my ($self) = @_;
    
    # Now to look for bookmark information
    my $fcSttbfBkmk = unpack("V", substr($self->{_data}, 0x0142, 4));
    my $lcbSttbfBkmk = unpack("V", substr($self->{_data}, 0x0146, 4));
    my $fcPlcfBkf = unpack("V", substr($self->{_data}, 0x014a, 4));
    my $lcbPlcfBkf = unpack("V", substr($self->{_data}, 0x014e, 4));
    my $fcPlcfBkl = unpack("V", substr($self->{_data}, 0x0152, 4));
    my $lcbPlcfBkl = unpack("V", substr($self->{_data}, 0x0156, 4));
### fcSttbfBkmk:  $fcSttbfBkmk
### lcbSttbfBkmk: $lcbSttbfBkmk
### fcPlcfBkf:    $fcPlcfBkf
### lcbPlcfBkf:   $lcbPlcfBkf
### fcPlcfBkl:    $fcPlcfBkl
### lcbPlcfBkl:   $lcbPlcfBkl

    return if ($lcbSttbfBkmk == 0);

    # Read the bookmark name block
    my $sttbfBkmk = substr($self->{_table}, $fcSttbfBkmk, $lcbSttbfBkmk);
    my $plcfBkf = substr($self->{_table}, $fcPlcfBkf, $lcbPlcfBkf);
    my $plcfBkl = substr($self->{_table}, $fcPlcfBkl, $lcbPlcfBkl);

    # Now we can read the bookmark names

    my $fcExtend = unpack("v", substr($sttbfBkmk, 0, 2));
    my $cData = unpack("v", substr($sttbfBkmk, 2, 2));
    my $cbExtra = unpack("v", substr($sttbfBkmk, 4, 2));
    confess("Internal error: unexpected single-byte bookmark data") unless ($fcExtend == 0xffff);
    
    my $offset = 6;
    my $index = 0;
    my %bookmarks = ();
    while($offset < $lcbSttbfBkmk) {
        my $length = unpack("v", substr($sttbfBkmk, $offset, 2));
        $length = $length * 2;
        my $string = substr($sttbfBkmk, $offset + 2, $length);
        my $cpStart = unpack("V", substr($plcfBkf, $index * 4, 4));
        my $cpEnd = unpack("V", substr($plcfBkl, $index * 4, 4));
        $string = Encode::decode("UCS-2LE", $string);
### field name: $string
### position:   $cpStart
### position:   $cpEnd
        $bookmarks{$string} = {start => $cpStart, end => $cpEnd};
        $offset += $length + 2;
        $index++;
    }
    
    $self->{_bookmarks} = \%bookmarks;       
}

sub _get_piece {
    my ($dataref, $piece) = @_;
    
    my $pstart = $piece->{start};
    my $ptotLength = $piece->{totLength};
    my $pfilePos = $piece->{filePos};
    my $punicode = $piece->{unicode};
    
    my $pend = $pstart + $ptotLength;
    my $textStart = $pfilePos;
    my $textEnd = $textStart + ($pend - $pstart);
    
    if ($punicode) {
        ### Adding ucs2 text...
        ### Start: $textStart
        ### End: $textEnd
        ### Length: $textEnd - $textStart
        ### Bytes: $ptotLength
        $piece->{text} = _add_unicode_text($textStart, $textEnd, $dataref);
        return;
    } else {
        ### Adding iso8869 text...
        ### Start: $textStart
        ### End: $textEnd
        ### Length: $textEnd - $textStart
        ### Bytes: $ptotLength
        $piece->{text} = _add_text($textStart, $textEnd, $dataref);
        return;
    }  
}

sub _get_text {
    my ($dataref, $piecesref) = @_;
    
    my @pieces = @$piecesref;
    my @result = ();
    my $index = 1;
    my $position = 0;
    
    foreach my $piece (@pieces) {

        ### piece: $index++
        ### position: $position
        $piece->{position} = $position;

        _get_piece($dataref, $piece);
        my $segment = $piece->{text};
        push @result, $segment;
        my $length = length($segment);
        $piece->{length} = $length;
        $piece->{endPosition} = $position + $length;
        
        $position += $length;
    }

    ### End position: $position
    return;
}

sub _add_unicode_text {
    my ($textStart, $textEnd, $dataref) = @_;

    my $string = substr($$dataref, $textStart, 2*($textEnd - $textStart));

    my $perl_string = Encode::decode("UCS-2LE", $string);
    return $perl_string;
}

sub _add_text {
    my ($textStart, $textEnd, $dataref) = @_;
    
    my $string = substr($$dataref, $textStart, $textEnd - $textStart);
    
    my $perl_string = Encode::decode("iso-8859-1", $string);
    
    # See the conversion table for FcCompressed structures. Note that these
    # should not affect positions, as these are characters now, not bytes
    $perl_string =~ tr[\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9f][\x{201A}\x{0192}\x{201E}\x{2026}\x{2020}\x{2021}\x{02C6}\x{2030}\x{0160}\x{2039}\x{0152}\x{2018}\x{2019}\x{201C}\x{201D}\x{2022}\x{2013}\x{2014}\x{02DC}\x{2122}\x{0161}\x{203A}\x{0153}\x{0178}];

    return $perl_string;
}

sub _get_chunks {
    my ($start, $length, $piecesref) = @_;
    my @result = ();
    my $end = $start + $length;
    
    foreach my $piece (@$piecesref) {
        my ($pstart, $ptotLength, $pfilePos, $punicode) = @$piece;
        my $pend = $pstart + $ptotLength;
        if ($pstart < $end) {
            if ($start < $pend) {
                push @result, $piece;
            }
        } else {
            last;
        }
    }
    
    return @result;
}

sub _find_text {
    my ($tableref, $pos) = @_;
    
    my @pieces = ();
    
    while(unpack("C", substr($$tableref, $pos, 1)) == 1) {
        $pos++;
        my $skip = unpack("v", substr($$tableref, $pos, 2));
#        print STDERR sprintf("Skipping %d\n", $skip);
        $pos += 2 + $skip;
    }
    
    if (unpack("C", substr($$tableref, $pos, 1)) != 2) {
         confess("Internal error: ccorrupted Word file");
    } else {
        my $pieceTableSize = unpack("V", substr($$tableref, ++$pos, 4));
#        print STDERR sprintf("pieceTableSize: %d\n", $pieceTableSize);
        
        $pos += 4;
        my $pieces = ($pieceTableSize - 4) / 12;
#        print STDERR sprintf("pieces: %d\n", $pieces);
        my $start = 0;
        
        for (my $x = 0; $x < $pieces; $x++) {
            my $filePos = unpack("V", substr($$tableref, $pos + (($pieces + 1) * 4) + ($x * 8) + 2, 4));
            my $unicode = 0;
            if (($filePos & 0x40000000) == 0) {
                $unicode = 1;
            } else {
                $unicode = 0;
                $filePos &= ~(0x40000000); #gives me FC in doc stream
                $filePos /= 2;
            }
#            print STDERR sprintf("filePos: %x\n", $filePos);
            my $lStart = unpack("V", substr($$tableref, $pos + ($x * 4), 4));
            my $lEnd = unpack("V", substr($$tableref, $pos + (($x + 1) * 4), 4));
            my $totLength = $lEnd - $lStart;
            
#            print STDERR "lStart: $lStart; lEnd: $lEnd\n";
            
#            print STDERR ("Piece: " . (1 + $x) . ", start=" . $start
#                            . ", len=" . $totLength . ", phys=" . $filePos
#                            . ", uni=" .$unicode . "\n");
                            
            # TextPiece piece = new TextPiece(start, totLength, filePos, unicode);
            # start = start + totLength;
            # text.add(piece);
            
            push @pieces, {start => $start,
                           totLength => $totLength,
                           filePos => $filePos,
                           unicode => $unicode};
            $start = $start + (($unicode) ? $totLength/2 : $totLength);
        }
    }
    return @pieces;
}

sub _get_piece_index {
    my ($self, $position) = @_;
    confess("Internal error: invalid position") if (! defined($position));
    my $index = 0;
    foreach my $piece (@{$self->{_pieces}}) {
        return $index if ($position <= $piece->{endPosition});
        $index++;
    }
}

sub _get_text_range {
    my ($self, $start, $end) = @_;
    
    my $pieces = $self->{_pieces};
    my $start_piece = _get_piece_index($self, $start);
    my $end_piece = _get_piece_index($self, $end);
    my @result = ();
    for(my $i = $start_piece; $i <= $end_piece; $i++) {
        my $piece = $pieces->[$i];
        my $xstart = ($i == $start_piece) ? $start - $piece->{position} : 0;
        my $xend = ($i == $end_piece) ? $end - $piece->{position} : $piece->{endPosition};
        push @result, substr($piece->{text}, $xstart, $xend - $xstart);
    }
     
    return join("", @result); 
}

sub get_bookmarks {
    my ($self, $filter) = @_;
    my $bookmarks = $self->{_bookmarks};
    my @bookmark_names = sort keys %$bookmarks;
    foreach my $name (@bookmark_names) {
        my $bookmark = $bookmarks->{$name};
        next if (exists($bookmark->{value}));
        my $start = $bookmark->{start};
        my $end = $bookmark->{end};
        my $value = _get_text_range($self, $start - 1, $end);
        if (substr($value, 0, 1) ne chr(19)) {
            $value = substr($value, 1);   
        }
        $bookmark->{value} = $value;
        ### name: $name
        ### value: $value
    }
    
    return { map { ($_ => _filter($bookmarks->{$_}->{value}, $filter) ) } @bookmark_names };
}

sub get_body {
    my ($self, $filter) = @_;
    my $start = 0;
    return _filter(_get_text_range($self, $start, $start + $self->{_ccpText}), $filter);
}

sub get_footnotes {
    my ($self, $filter) = @_;
    my $start = $self->{_ccpText};
    return _filter(_get_text_range($self, $start, $start + $self->{_ccpFtn}), $filter);
}

sub get_headers {
    my ($self, $filter) = @_;
    my $start = $self->{_ccpText} + $self->{_ccpFtn};
    return _filter(_get_text_range($self, $start, $start + $self->{_ccpHdd}), $filter);
}

sub get_annotations {
    my ($self, $filter) = @_;
    my $start = $self->{_ccpText} + $self->{_ccpFtn} + $self->{_ccpHdd};
    return _filter(_get_text_range($self, $start, $start + $self->{_ccpAtn}), $filter);
}

sub get_text {
    my ($self, $filter) = @_;
    return $self->get_body($filter) .
           $self->get_footnotes($filter) .
           $self->get_headers($filter) .
           $self->get_annotations($filter);
}

sub _filter {
    my ($text, $filter) = @_;
    if (! defined($filter)) {
        $text =~ tr/\x02\x05\x08//d;
        $text =~ tr/\x{2018}\x{2019}\x{201c}\x{201d}\x{0007}\x{000d}\x{2002}\x{2003}\x{2012}\x{2013}\x{2014}/''""\t\n  \-\-\-/;
        $text =~ s{\cS(?:[^\cT]*\cT)([^\cU]*)\cU}{$1}g;
        $text =~ s{\cS(?:[^\cU]*\cU)}{}g;
        $text =~ s{[\cJ\cM]}{\n}g;
    } elsif ($filter eq ':raw') {
        # Do nothing
    } else {
        croak("Invalid filter type: $filter");   
    }
    return $text;
}

sub get_all_text {
    my ($file) = @_;
    
    my $instance = __PACKAGE__->new($file);
    
    $instance->get_bookmarks();
    return _get_text_range($instance, 0, $instance->{_ccpText} + 
                                         $instance->{_ccpFtn} + 
                                         $instance->{_ccpHdd} + 
                                         $instance->{_ccpAtn});
}

1;

=head1 NAME

Text::Extract::Word - Extract text from Word files

=head1 SYNOPSIS

 # object-based interface
 use Text::Extract::Word;
 my $file = Text::Extract::Word->new("test1.doc");
 my $text = $file->get_text();
 my $body = $file->get_body();
 my $footnotes = $file->get_footnotes();
 my $headers = $file->get_headers();
 my $annotations = $file->get_annotations();
 my $bookmarks = $file->get_bookmarks();
 
 # specify :raw if you don't want the text cleaned
 my $raw = $file->get_text(':raw');

 # legacy interface
 use Text::Extract::Word qw(get_all_text);
 my $text = get_all_text("test1.doc");

=head1 DESCRIPTION

This simple module allows the textual contents to be extracted from a Word file. 
The code was ported from Java code, originally part of the Apache POE project, but
extensive code changes were made internally. 

=head1 OBJECT-BASED INTERFACE

=head2 Text::Extract::Word->new($input);

Passed either a file name or an open file handle, this constructor returns an
instance that can be used to query the file contents. 

=head1 METHODS

All the query methods accept an optional filter argument that can take the value 
':raw' -- if this is passed the original Word file contents will be returned without
any attempt to clean the text. 

The default filter attempts to remove Word internal characters used to identify
fields (including field instructions), and translate common Unicode 'fancy' quotes
into more conventional ISO-8859-1 equivalents, for ease of processing. Table cell
markers are also translated into tabs, and paragraph marks into Perl newlines. 

=head2 get_body([$filter]) 

Returns the text for the main body of the Word document. This excludes headers,
footers, and annotations. 

=head2 get_headers([$filter]) 

Returns the header and footer texts for the Word document, as a single scalar 
string.

=head2 get_footnotes([$filter]) 

Returns the footnote and endnode texts for the Word document, as a single scalar 
string.

=head2 get_annotations([$filter]) 

Returns the annotation texts for the Word document, as a single scalar 
string.

=head2 get_text([$filter]) 

Returns the concatenated text from the body, headers, footnotes, and annotations
of the the Word document, as a single scalar string.

=head2 get_bookmarks([$filter]) 

Returns the bookmark texts for the Word document, as a hash reference. The keys
in the hash are the bookmark names (Word requires that these are unique) and
the values are the filtered bookmark texts.

This method can be used to get Word form text data out of a Word file. All text fields
in a Word form will normally be labelled as bookmarks, and will be returned by this
method. Non-textual form fields (including drop-downs) will not be returned, as these
are not labelled as bookmarks. 

=head1 FUNCTIONS

=head2 get_all_text($filename)

The only function exportable by this module, when called on a file name, returns the
raw text contents of the Word file. The contents are returned as UTF-8 encoded text. 
This is unfiltered, for compatibility with previous versions of the module. 

=head1 TODO

=over 4

=item *

handle non-textual form fields

=back

=head1 BUGS

=over 4 

=item *

support for legacy Word - the module does not extract text from Word version 6 or earlier 

=back

=head1 SEE ALSO

L<OLE::Storage> also has a script C<lhalw> (Let's Have a Look at Word) which extracts
text from Word files. This is simply a much smaller module with lighter dependencies,
using L<OLE::Storage_Lite> for its storage management. 

=head1 AUTHOR

Stuart Watt, stuart@morungos.com

=head1 COPYRIGHT

Copyright (c) 2010 Stuart Watt. All rights reserved.

=cut

