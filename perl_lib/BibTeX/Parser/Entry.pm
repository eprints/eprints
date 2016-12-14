package BibTeX::Parser::Entry;
BEGIN {
  $BibTeX::Parser::Entry::VERSION = '0.63';
}

use warnings;
use strict;

use BibTeX::Parser::Author;



sub new {
	my ($class, $type, $key, $parse_ok, $fieldsref) = @_;

	my %fields = defined $fieldsref ? %$fieldsref : ();
	if (defined $type) {
		$fields{_type}     = uc($type);
	}
	$fields{_key}      = $key;
	$fields{_parse_ok} = $parse_ok;
        $fields{_raw}      = '';
	return bless \%fields, $class;
}



sub parse_ok {
	my $self = shift;
	if (@_) {
		$self->{_parse_ok} = shift;
	}
	$self->{_parse_ok};
}


sub error {
	my $self = shift;
	if (@_) {
		$self->{_error} = shift;
		$self->parse_ok(0);
	}
	return $self->parse_ok ? undef : $self->{_error};
}


sub type {
	if (scalar @_ == 1) {
		# get
		my $self = shift;
		return $self->{_type};
	} else {
		# set
		my ($self, $newval) = @_;
		$self->{_type} = uc($newval);
	}
}


sub key {
	if (scalar @_ == 1) {
		# get
		my $self = shift;
		return $self->{_key};
	} else {
		# set
		my ($self, $newval) = @_;
		$self->{_key} = $newval;
	}

}


sub field {
	if (scalar @_ == 2) {
		# get
		my ($self, $field) = @_;
		return $self->{ lc( $field ) };
	} else {
		my ($self, $key, $value) = @_;
		$self->{ lc( $key ) } = $value; #_sanitize_field($value);
	}

}

sub _handle_author_editor {
	my $type = shift;
	my $self = shift;
	if (@_) {
		if (@_ == 1) { #single string
			# my @names = split /\s+and\s+/i, $_[0];
			my @names = _split_author_field( $_[0] );
			$self->{"_$type"} = [map {new BibTeX::Parser::Author $_} @names];
			$self->field($type, join " and ", @{$self->{"_$type"}});
		} else {
			$self->{"_$type"} = [];
			foreach my $param (@_) {
				if (ref $param eq "BibTeX::Author") {
					push @{$self->{"_$type"}}, $param;
				} else {
					push @{$self->{"_$type"}}, new BibTeX::Parser::Author $param;
				}

				$self->field($type, join " and ", @{$self->{"_$type"}});
			}
		}
	} else {
		unless ( defined $self->{"_$type"} ) {
			#my @names = split /\s+and\s+/i, $self->{$type} || "";
			my @names = _split_author_field( $self->{$type} || "" );
			$self->{"_$type"} = [map {new BibTeX::Parser::Author $_} @names];
		}
		return @{$self->{"_$type"}};
	}
}

# _split_author_field($field)
#
# Split an author field into different author names.
# Handles quoted names ({name}).
sub _split_author_field {
    my $field = shift;

    return () if !defined $field || $field eq '';

    my @names;

    my $buffer;
    while (!defined pos $field || pos $field < length $field) {
	if ( $field =~ /\G ( .*? ) ( \{ | \s+ and \s+ )/xcgi ) {
	    my $match = $1;
	    if ( $2 =~ /and/i ) {
		$buffer .= $match;
		push @names, $buffer;
		$buffer = "";
	    } elsif ( $2 =~ /\{/ ) {
		$buffer .= $match . "{";
		if ( $field =~ /\G (.* \}?)/cgx ) {
		    $buffer .= $1;
		} else {
		    die "Missing closing brace at " . substr( $field, pos $field, 10 );
		}
	    } else {
		$buffer .= $match;
	    }
	} else {
	   #print "# $field " . (pos ($field) || 0) . "\n";
	   $buffer .= substr $field, (pos $field || 0);
	   last;
	}
    }
    push @names, $buffer if $buffer;
    return @names;
}


sub author {
	_handle_author_editor('author', @_);
}


sub editor {
	_handle_author_editor('editor', @_);
}


sub fieldlist {
	my $self = shift;
	
	return grep {!/^_/} keys %$self;	
}


sub has {
	my ($self, $field) = @_;

	return defined $self->{$field};
}

sub _sanitize_field {
	my $value = shift;	
	for ($value) {
		tr/\{\}//d;
		s/\\(?!=[ \\])//g;
		s/\\\\/\\/g;
	}
	return $value;
}



sub raw_bibtex {
	my $self = shift;
	if (@_) {
		$self->{_raw} = shift;
	}
	return $self->{_raw};
}

1; # End of BibTeX::Entry
__END__
=pod

=head1 NAME

BibTeX::Parser::Entry

=head1 VERSION

version 0.63

=head1 SYNOPSIS

This class ist a wrapper for a single BibTeX entry. It is usually created
by a BibTeX::Parser.

    use BibTeX::Parser::Entry;

    my $entry = BibTeX::Parser::Entry->new($type, $key, $parse_ok, \%fields);
    
    if ($entry->parse_ok) {
	    my $type    = $entry->type;
	    my $key     = $enty->key;
	    print $entry->field("title");
	    my @authors = $entry->author;
	    my @editors = $entry->editor;

	    ...
    }

=head1 NAME

BibTeX::Entry - Contains a single entry of a BibTeX document.

=head1 VERSION

version 0.63

=head1 FUNCTIONS

=head2 new

Create new entry.

=head2 parse_ok

If the entry was correctly parsed, this method returns a true value, false otherwise.

=head2 error

Return the error message, if the entry could not be parsed or undef otherwise.

=head2 type

Get or set the type of the entry, eg. 'ARTICLE' or 'BOOK'. Return value is 
always uppercase.

=head2 key

Get or set the reference key of the entry.

=head2 field($name [, $value])

Get or set the contents of a field. The first parameter is the name of the
field, the second (optional) value is the new value.

=head2 cleaned_field($name)

Retrieve the contents of a field in a format that is cleaned of TeX markup.

=head2 cleaned_author

Get an array of L<BibTeX::Parser::Author> objects for the authors of this
entry. Each name has been cleaned of accents and braces.

=head2 cleaned_editor

Get an array of L<BibTeX::Parser::Author> objects for the editors of this
entry. Each name has been cleaned of accents and braces.

=head2 author([@authors])

Get or set the authors. Returns an array of L<BibTeX::Author|BibTeX::Author> 
objects. The parameters can either be L<BibTeX::Author|BibTeX::Author> objects
or strings.

Note: You can also change the authors with $entry->field('author', $authors_string)

=head2 editor([@editors])

Get or set the editors. Returns an array of L<BibTeX::Author|BibTeX::Author> 
objects. The parameters can either be L<BibTeX::Author|BibTeX::Author> objects
or strings.

Note: You can also change the authors with $entry->field('editor', $editors_string)

=head2 fieldlist()

Returns a list of all the fields used in this entry.

=head2 has($fieldname)

Returns a true value if this entry has a value for $fieldname.

=head2 raw_bibtex

Return raw BibTeX entry (if available).

=head1 AUTHOR

Gerhard Gossen <gerhard.gossen@googlemail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Gerhard Gossen.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

