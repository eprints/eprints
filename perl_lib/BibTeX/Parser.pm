package BibTeX::Parser;
BEGIN {
  $BibTeX::Parser::VERSION = '0.63';
}
# ABSTRACT: A pure perl BibTeX parser
use warnings;
use strict;

use BibTeX::Parser::Entry;


my $re_namechar = qr/[a-zA-Z0-9\!\$\&\*\+\-\.\/\:\;\<\>\?\[\]\^\_\`\|]/o;
my $re_name     = qr/$re_namechar+/o;


sub new {
    my ( $class, $fh ) = @_;

    return bless {
        fh      => $fh,
        strings => {
            jan => "January",
            feb => "February",
            mar => "March",
            apr => "April",
            may => "May",
            jun => "June",
            jul => "July",
            aug => "August",
            sep => "September",
            oct => "October",
            nov => "November",
            dec => "December",

        },
        line   => -1,
        buffer => "",
    }, $class;
}

sub _slurp_close_bracket;

sub _parse_next {
    my $self = shift;

	my $fh = $self->{fh};

    while (1) {    # loop until regular entry is finished
        return 0 if eof($fh);
        local $_ = $self->{buffer};

        until (/@/m) {
            my $line = <$fh>;
            return 0 unless defined $line;
            $_ .= $line;
        }

        my $current_entry = new BibTeX::Parser::Entry;
        if (/@($re_name)/cgo) {
	    my $type = uc $1;
            $current_entry->type( $type );
            my $start_pos = pos($_) - length($type) - 1;

            # read rest of entry (matches braces)
            my $bracelevel = 0;
            $bracelevel += tr/\{/\{/;    #count braces
            $bracelevel -= tr/\}/\}/;
            while ( $bracelevel != 0 ) {
                my $position = pos($_);
                my $line     = <$fh>;
				last unless defined $line;
                $bracelevel =
                  $bracelevel + ( $line =~ tr/\{/\{/ ) - ( $line =~ tr/\}/\}/ );
                $_ .= $line;
                pos($_) = $position;
            }

            # Remember raw bibtex code
            my $raw = substr($_, $start_pos);
            $raw =~ s/^\s+//;
            $raw =~ s/\s+$//;
            $current_entry->raw_bibtex($raw);

            my $pos = pos $_;
            tr/\n/ /;
            pos($_) = $pos;

            if ( $type eq "STRING" ) {
                if (/\G{\s*($re_name)\s*=\s*/cgo) {
                    my $key   = $1;
                    my $value = _parse_string( $self->{strings} );
                    if ( defined $self->{strings}->{$key} ) {
                        warn("Redefining string $key!");
                    }
                    $self->{strings}->{$key} = $value;
                    /\G[\s\n]*\}/cg;
                } else {
                    $current_entry->error("Malformed string!");
					return $current_entry;
                }
            } elsif ( $type eq "COMMENT" or $type eq "PREAMBLE" ) {
                /\G\{./cgo;
                _slurp_close_bracket;
            } else {    # normal entry
                $current_entry->parse_ok(1);

				# parse key
                if (/\G\s*\{(?:\s*($re_name)\s*,[\s\n]*|\s+\r?\s*)/cgo) {
                    $current_entry->key($1);

					# fields
                    while (/\G[\s\n]*($re_name)[\s\n]*=[\s\n]*/cgo) {
                        $current_entry->field(
                                      $1 => _parse_string( $self->{strings} ) );
                        my $idx = index( $_, ',', pos($_) );
                        pos($_) = $idx + 1 if $idx > 0;
                    }

                    return $current_entry;

                } else {

                    $current_entry->error("Malformed entry (key contains illegal characters) at " . substr($_, pos($_) || 0, 20)  . ", ignoring");
                    _slurp_close_bracket;
					return $current_entry;
                }
            }

            $self->{buffer} = substr $_, pos($_);

        } else {
            $current_entry->error("Did not find type at " . substr($_, pos($_) || 0, 20)); 
			return $current_entry;
        }

    }
}


sub next {
    my $self = shift;

    return $self->_parse_next;
}

# slurp everything till the next closing brace. Handels
# nested brackets
sub _slurp_close_bracket {
    my $bracelevel = 0;
  BRACE: {
        /\G[^\}]*\{/cg && do { $bracelevel++; redo BRACE };
        /\G[^\{]*\}/cg
          && do {
            if ( $bracelevel > 0 ) {
                $bracelevel--;
                redo BRACE;
            } else {
                return;
            }
          }
    }
}

# parse bibtex string in $_ and return. A BibTeX string is either enclosed
# in double quotes '"' or matching braces '{}'. The braced form may contain
# nested braces.
sub _parse_string {
    my $strings_ref = shift;

    my $value = "";

  PART: {
        if (/\G(\d+)/cg) {
            $value .= $1;
        } elsif (/\G($re_name)/cgo) {
            warn("Using undefined string $1") unless defined $strings_ref->{$1};
            $value .= $strings_ref->{$1} || "";
        } elsif (/\G"(([^"\\]*(\\.)*[^\\"]*)*)"/cgs)
        {    # quoted string with embedded escapes
            $value .= $1;
        } else {
            my $part = _extract_bracketed( $_ );
            $value .= substr $part, 1, length($part) - 2;    # strip quotes
        }

        if (/\G\s*#\s*/cg) {    # string concatenation by #
            redo PART;
        }
    }
    $value =~ s/[\s\n]+/ /g;
    return $value;
}

sub _extract_bracketed
{
	for($_[0]) # alias to $_
	{
		/\G\s+/cg;
		my $start = pos($_);
		my $depth = 0;
		while(1)
		{
			/\G\\./cg && next;
			/\G\{/cg && (++$depth, next);
			/\G\}/cg && (--$depth > 0 ? next : last);
			/\G([^\\\{\}]+)/cg && next; 
			last; # end of string
		}
		return substr($_, $start, pos($_)-$start);
	}
}

1;    # End of BibTeX::Parser
__END__
=pod

=head1 NAME

BibTeX::Parser - A pure perl BibTeX parser

=head1 VERSION

version 0.63

=head1 SYNOPSIS

Parses BibTeX files.

    use BibTeX::Parser;
	use IO::File;

    my $fh     = IO::File->new("filename");

    # Create parser object ...
    my $parser = BibTeX::Parser->new($fh);
    
    # ... and iterate over entries
    while (my $entry = $parser->next ) {
	    if ($entry->parse_ok) {
		    my $type    = $entry->type;
		    my $title   = $entry->field("title");

		    my @authors = $entry->author;
		    # or:
		    my @editors = $entry->editor;
		    
		    foreach my $author (@authors) {
			    print $author->first . " "
			    	. $author->von . " "
				. $author->last . ", "
				. $author->jr;
		    }
	    } else {
		    warn "Error parsing file: " . $entry->error;
	    }
    }

=for stopwords jr von

=head1 NAME

BibTeX::Parser - A pure perl BibTeX parser

=head1 VERSION

version 0.63

=head1 FUNCTIONS

=head2 new

Creates new parser object. 

Parameters:

	* fh: A filehandle

=head2 next

Returns the next parsed entry or undef.

=head1 AUTHOR

Gerhard Gossen <gerhard.gossen@googlemail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Gerhard Gossen.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

