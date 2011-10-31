package BibTeX::Parser::Author;
BEGIN {
  $BibTeX::Parser::Author::VERSION = '0.63';
}

use warnings;
use strict;

use overload
	'""' => \&to_string;



sub new {
	my $class = shift;

	if (@_) {
		my $self = [ $class->split(@_) ];
		return bless $self, $class;
	} else {
		return bless [], $class;
	}
}

sub _get_or_set_field {
	my ($self, $field, $value) = @_;
	if (defined $value) {
		$self->[$field] = $value;
	} else {
		return $self->[$field];
	}
}


sub first {
	shift->_get_or_set_field(0, @_);
}


sub von {
	shift->_get_or_set_field(1, @_);
}


sub last {
	shift->_get_or_set_field(2, @_);
}


sub jr {
	shift->_get_or_set_field(3, @_);
}


sub split {
	my ($self_or_class, $name) = @_;

	# remove whitespace at start and end of string
	$name =~ s/^\s*(.*)\s*$/$1/s;

	if ( $name =~ /^\{\s*(.*)\s*\}$/ ) {
	    return (undef, undef, $1, undef);
	}

        if ( $name =~ /\{/ ) {
            my @tokens;
            my $cur_token = '';
            while ( scalar( $name =~ /\G \s* ( [^,\{]*? ) ( \s* , \s* | \{ | \s* $ ) /xgc ) ) {
                $cur_token .= $1 if $1;
                if ( $2 =~ /\{/ ) {
                    if ( scalar( $name =~ /\G([^\}]*)\}/gc ) ) {
                        $cur_token .= "{$1}";
                    } else {
                        die "Unmatched brace in name '$name'";
                    }
                } else {
                    $cur_token =~ s/\s*$//;
                    push @tokens, $cur_token if $cur_token;
                    $cur_token = '';
                }
            }
            push @tokens, $cur_token if $cur_token;
            return _get_single_author_from_tokens( @tokens );
        } else {
            my @tokens = split /\s*,\s*/, $name;

            return _get_single_author_from_tokens( @tokens );
        }
}

sub _split_name_parts {
    my $name = shift;

    if ( $name !~ /\{/ ) {
        return split /\s+/, $name;
    } else {
        my @parts;
        my $cur_token = '';
        while ( scalar( $name =~ /\G ( [^\s\{]* ) ( \s+ | \{ | \s* $ ) /xgc ) ) {
            $cur_token .= $1;
            if ( $2 =~ /\{/ ) {
                if ( scalar( $name =~ /\G([^\}]*)\}/gc ) ) {
                    $cur_token .= "{$1}";
                } else {
                    die "Unmatched brace in name '$name'";
                }
            } else {
                if ( $cur_token =~ /^{(.*)}$/ ) {
                    $cur_token = $1;
                }
                push @parts, $cur_token;
                $cur_token = '';
            }
        }
        return @parts;
    }

}


sub _get_single_author_from_tokens {
    my (@tokens) = @_;
    if (@tokens == 0) {
        return (undef, undef, undef, undef);
    } elsif (@tokens == 1) {	# name without comma
        if ( $tokens[0] =~ /(^|\s)[[:lower:]]/) { # name has von part or has only lowercase names
            my @name_parts = _split_name_parts $tokens[0];

            my $first;
            while (@name_parts && ucfirst($name_parts[0]) eq $name_parts[0] ) {
                $first .= $first ? ' ' . shift @name_parts : shift @name_parts;
            }

            my $von;
            # von part are lowercase words
            while ( @name_parts && lc($name_parts[0]) eq $name_parts[0] ) {
                $von .= $von ? ' ' . shift @name_parts : shift @name_parts;
            }

            if (@name_parts) {
                return ($first, $von, join(" ", @name_parts), undef);
            } else {
                return (undef, undef, $tokens[0], undef);
            }
        } else {
            if ( $tokens[0] !~ /\{/ && $tokens[0] =~ /^((.*)\s+)?\b(\S+)$/) {
                return ($2, undef, $3, undef);
            } else {
                my @name_parts = _split_name_parts $tokens[0];
                return ($name_parts[0], undef, $name_parts[1], undef);
            }
        }

    } elsif (@tokens == 2) {
        my @von_last_parts = _split_name_parts $tokens[0];
        my $von;
        # von part are lowercase words
        while ( @von_last_parts && lc($von_last_parts[0]) eq $von_last_parts[0] ) {
            $von .= $von ? ' ' . shift @von_last_parts : shift @von_last_parts;
        }
        return ($tokens[1], $von, join(" ", @von_last_parts), undef);
    } else {
        my @von_last_parts = _split_name_parts $tokens[0];
        my $von;
        # von part are lowercase words
        while ( @von_last_parts && lc($von_last_parts[0]) eq $von_last_parts[0] ) {
            $von .= $von ? ' ' . shift @von_last_parts : shift @von_last_parts;
        }
        return ($tokens[2], $von, join(" ", @von_last_parts), $tokens[1]);
    }

}


sub to_string {
	my $self = shift;

	if ($self->jr) {
		return $self->von . " " . $self->last . ", " . $self->jr . ", " . $self->first;
	} else {
		return ($self->von ? $self->von . " " : '') . $self->last . ($self->first ? ", " . $self->first : '');
	}
}

1; # End of BibTeX::Entry
__END__
=pod

=head1 NAME

BibTeX::Parser::Author

=head1 VERSION

version 0.63

=head1 SYNOPSIS

This class ist a wrapper for a single BibTeX author. It is usually created
by a BibTeX::Parser.

    use BibTeX::Parser::Author;

    my $entry = BibTeX::Parser::Author->new($full_name);
    
    my $firstname = $author->first;
    my $von	  = $author->von;
    my $last      = $author->last;
    my $jr	  = $author->jr;

    # or ...
    
    my ($first, $von, $last, $jr) = BibTeX::Author->split($fullname);

=head1 NAME

BibTeX::Author - Contains a single author for a BibTeX document.

=head1 VERSION

version 0.63

=head1 FUNCTIONS

=head2 new

Create new author object. Expects full name as parameter.

=head2 first

Set or get first name(s).

=head2 von

Set or get 'von' part of name.

=head2 last

Set or get last name(s).

=head2 jr

Set or get 'jr' part of name.

=head2 split

Split name into (firstname, von part, last name, jr part). Returns array
with four strings, some of them possibly empty.

=head2 to_string

Return string representation of the name.

=head1 AUTHOR

Gerhard Gossen <gerhard.gossen@googlemail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Gerhard Gossen.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

