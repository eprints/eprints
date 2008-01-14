####################################################################
#
#    This file was generated using Parse::Yapp version 1.05.
#
#        Don't edit this file, use source file instead.
#
#             ANY CHANGE MADE HERE WILL BE LOST !
#
####################################################################
package Text::BibTeX::Yapp;
use vars qw ( @ISA );
use strict;

@ISA= qw ( Parse::Yapp::Driver );
use Parse::Yapp::Driver;



{
# Utility classes
package Text::BibTeX::Yapp::Value;

use overload '""' => \&value;

sub new
{
	my( $class, $value ) = @_;

	bless \$value, $class;
}

sub value
{
	${$_[0]};
}

sub type
{
	my( $self ) = @_;

	my $type = ref( $self );
	$type =~ s/^.*:://;

	return uc($type);
}

package Text::BibTeX::Yapp::String;
our @ISA = qw( Text::BibTeX::Yapp::Value );

package Text::BibTeX::Yapp::Number;
our @ISA = qw( Text::BibTeX::Yapp::Value );

package Text::BibTeX::Yapp::Name;
our @ISA = qw( Text::BibTeX::Yapp::Value );

}

=pod

=head1 NAME

Text::BibTeX::Yapp - Pure-perl BibTeX parser

=head1 SYNOPSIS

	use Text::BibTeX::Yapp;

	my $p = Text::BibTeX::Yapp->new;

	open(my $fh, "<", "my.bib");
	my $entries = $p->parse_file($fh);
	close($fh);

=head1 DESCRIPTION

This module provides only the bare-bones necessary to read a BibTeX file.
BibTeX entries are read sequentially from a file (ignoring any comments) and
stored in a simple perl data structure.

It doesn't perform any macro expansion or placeholder replacement.

=head1 DATA FORMAT

The parse methods return an array reference to a list of bib entries.

=head2 BibTeX Entry

A normal BibTeX entry (note IDENTIFIER may be undefined):

 [
  TYPE,
  [
   IDENTIFIER,
   {
	FIELD => [ VALUE ],
	FIELD => [ VALUE, VALUE, ... ],
	...
   }
  ]
 ]

=head2 @PREAMBLE

A preamble (i.e. TYPE = 'preamble'):

 [
  TYPE,
  [
   undef,
   [ VALUE, VALUE, ... ]
  ]
 ]

=head2 @STRING

A placeholder (i.e. TYPE = 'string'):

 [
  TYPE,
  [
   undef,
   {
	NAME => [ VALUE ]
   }
  ]
 ]

=head2 Values

Values are represented as objects in one of three types: NAME, STRING or NUMBER. To get the actual value stringify the object.

This is to allow you to perform the appropriate replacement of NAME values that
may have been defined using the @STRING pragma, see
http://artis.imag.fr/~Xavier.Decoret/resources/xdkbibtex/bibtex_summary.html

=head1 METHODS

=over 4

=item $parser = Text::BibTeX::Yapp->new

Create and return a new parser object.

=item $bibs = $parser->parse_file( HANDLE )

Parse bib entries from the file IO handle HANDLE and return them.

=item $bibs = $parser->parse_string( $string )

Parse bib entries from $string and return them.

=back

=head1 NAME

Text::BibTeX::Yapp::Value - Utility class for representing values

=head1 SYNOPSIS

	my $bib = $bibs->[0];
	my( $type, $content ) = @$bib;
	my( $identifier, $fields ) = @$content;

	my( $key, $value ) = each %$fields;

	print "$key is '$value' [".$value->type."]\n";
	print "$key is '".$value->value."'\n";

=head1 METHODS

=over 4

=item $type = $value->type

Returns the type of the value (NAME, STRING or NUMBER).

=item $value = $value->value

Returns the value of the value.

=back

=head1 SEE ALSO

For a complete BibTeX experience use L<Text::BibTeX>.

This parser was generated using L<Parse::Yapp>.


The BibTeX grammar described here is based on btparse:

http://search.cpan.org/~gward/btparse-0.34/doc/bt_language.pod

And from testing against the xampl.bib file:

http://www.ctan.org/tex-archive/biblio/bibtex/distribs/doc/xampl.bib

More info on BibTeX:

http://www.ecst.csuchico.edu/~jacobsd/bib/formats/bibtex.html

=head1 AUTHOR

Copyright 2008 Tim Brody <tdb01r@ecs.soton.ac.uk>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut

use Carp;

our $REGEXP_NAME = qr/[a-zA-Z0-9\!\$\&\*\+\-\.\/\:\;\<\>\?\[\]\^\_\`\|]+/;



sub new {
        my($class)=shift;
        ref($class)
    and $class=ref($class);

    my($self)=$class->SUPER::new( yyversion => '1.05',
                                  yystates =>
[
	{#State 0
		DEFAULT => -1,
		GOTOS => {
			'bibfile' => 1
		}
	},
	{#State 1
		ACTIONS => {
			'' => 2,
			'AT' => 4
		},
		GOTOS => {
			'entry' => 3
		}
	},
	{#State 2
		DEFAULT => 0
	},
	{#State 3
		DEFAULT => -2
	},
	{#State 4
		DEFAULT => -3,
		GOTOS => {
			'@1-1' => 5
		}
	},
	{#State 5
		ACTIONS => {
			'NAME' => 6
		}
	},
	{#State 6
		ACTIONS => {
			'LBRACE' => 7,
			'LPAREN' => 9,
			'STRING' => 10
		},
		GOTOS => {
			'body' => 8
		}
	},
	{#State 7
		ACTIONS => {
			'NUM' => 15,
			'NAME' => 11,
			'STRING' => 14
		},
		GOTOS => {
			'simple_value' => 17,
			'fields' => 16,
			'value' => 12,
			'contents' => 13,
			'field' => 18
		}
	},
	{#State 8
		DEFAULT => -4
	},
	{#State 9
		ACTIONS => {
			'NUM' => 15,
			'NAME' => 11,
			'STRING' => 14
		},
		GOTOS => {
			'fields' => 16,
			'simple_value' => 17,
			'value' => 12,
			'contents' => 19,
			'field' => 18
		}
	},
	{#State 10
		DEFAULT => -5
	},
	{#State 11
		ACTIONS => {
			'EQUALS' => 21,
			'COMMA' => 20
		},
		DEFAULT => -21
	},
	{#State 12
		DEFAULT => -11
	},
	{#State 13
		ACTIONS => {
			'RBRACE' => 22
		}
	},
	{#State 14
		DEFAULT => -19
	},
	{#State 15
		ACTIONS => {
			'COMMA' => 23
		},
		DEFAULT => -20
	},
	{#State 16
		DEFAULT => -10
	},
	{#State 17
		ACTIONS => {
			'HASH' => 24
		},
		DEFAULT => -17
	},
	{#State 18
		ACTIONS => {
			'COMMA' => 25
		},
		DEFAULT => -12
	},
	{#State 19
		ACTIONS => {
			'RPAREN' => 26
		}
	},
	{#State 20
		ACTIONS => {
			'NAME' => 27
		},
		GOTOS => {
			'fields' => 28,
			'field' => 18
		}
	},
	{#State 21
		DEFAULT => -15,
		GOTOS => {
			'@2-2' => 29
		}
	},
	{#State 22
		DEFAULT => -6
	},
	{#State 23
		ACTIONS => {
			'NAME' => 27
		},
		GOTOS => {
			'fields' => 30,
			'field' => 18
		}
	},
	{#State 24
		ACTIONS => {
			'NUM' => 33,
			'NAME' => 31,
			'STRING' => 14
		},
		GOTOS => {
			'simple_value' => 17,
			'value' => 32
		}
	},
	{#State 25
		ACTIONS => {
			'NAME' => 27
		},
		DEFAULT => -13,
		GOTOS => {
			'fields' => 34,
			'field' => 18
		}
	},
	{#State 26
		DEFAULT => -7
	},
	{#State 27
		ACTIONS => {
			'EQUALS' => 21
		}
	},
	{#State 28
		DEFAULT => -8
	},
	{#State 29
		ACTIONS => {
			'NUM' => 33,
			'NAME' => 31,
			'STRING' => 14
		},
		GOTOS => {
			'simple_value' => 17,
			'value' => 35
		}
	},
	{#State 30
		DEFAULT => -9
	},
	{#State 31
		DEFAULT => -21
	},
	{#State 32
		DEFAULT => -18
	},
	{#State 33
		DEFAULT => -20
	},
	{#State 34
		DEFAULT => -14
	},
	{#State 35
		DEFAULT => -16
	}
],
                                  yyrules  =>
[
	[#Rule 0
		 '$start', 2, undef
	],
	[#Rule 1
		 'bibfile', 0, undef
	],
	[#Rule 2
		 'bibfile', 2,
sub { return [ @{$_[1]||[]}, $_[2] ] }
	],
	[#Rule 3
		 '@1-1', 0,
sub { _level($_[0],2) }
	],
	[#Rule 4
		 'entry', 4,
sub { _level($_[0],1); return [ $_[3], $_[4] ] }
	],
	[#Rule 5
		 'body', 1, undef
	],
	[#Rule 6
		 'body', 3,
sub { $_[2] }
	],
	[#Rule 7
		 'body', 3,
sub { $_[2] }
	],
	[#Rule 8
		 'contents', 3,
sub { return [ $_[1], $_[3] ] }
	],
	[#Rule 9
		 'contents', 3,
sub { return [ $_[1], $_[3] ] }
	],
	[#Rule 10
		 'contents', 1,
sub { return [ undef, $_[1] ] }
	],
	[#Rule 11
		 'contents', 1,
sub { return [ undef, $_[1] ] }
	],
	[#Rule 12
		 'fields', 1, undef
	],
	[#Rule 13
		 'fields', 2, undef
	],
	[#Rule 14
		 'fields', 3,
sub { return { %{$_[1]}, %{$_[3]} } }
	],
	[#Rule 15
		 '@2-2', 0,
sub { _level($_[0],3) }
	],
	[#Rule 16
		 'field', 4,
sub { _level($_[0],2); return { $_[1] => $_[4] } }
	],
	[#Rule 17
		 'value', 1,
sub { [ $_[1] ] }
	],
	[#Rule 18
		 'value', 3,
sub { return [ $_[1], @{$_[3]} ] }
	],
	[#Rule 19
		 'simple_value', 1,
sub { Text::BibTeX::Yapp::String->new( $_[1] ) }
	],
	[#Rule 20
		 'simple_value', 1,
sub { Text::BibTeX::Yapp::Number->new( $_[1] ) }
	],
	[#Rule 21
		 'simple_value', 1,
sub { Text::BibTeX::Yapp::Name->new( $_[1] ) }
	]
],
                                  @_);
    bless($self,$class);
}


# footer

sub _Error
{
	my( $self ) = @_;

	$self->YYData->{ERR} = 1;
	$self->YYData->{ERRMSG} = "Unrecognised input near line " . $self->YYData->{LINE};
}

sub _Lexer
{
	my( $self ) = @_;

#warn "$LEVEL<<< ".$self->YYData->{INPUT}." >>>\n";

	my( $token, $value ) = _Lexer_real( @_ );

#warn(("\t" x $LEVEL) . "$token [$value]\n");

	return( $token, $value );
}

sub _level
{
	my( $self, $level ) = @_;

	$self->YYData->{LEVEL} = $level;
}

sub _Lexer_real
{
	my( $self ) = @_;

	my $level = $self->YYData->{LEVEL};

	REREAD:

	$self->_read_input or return( "", undef );

	$self->YYData->{INPUT} =~ s/^[ \r\t]+//;
	$self->YYData->{INPUT} =~ s/[ \r\n\t]+$//;

	length($self->YYData->{INPUT}) == 0
		and goto REREAD;

# top-level
	if( $level == 1 )
	{
	for( $self->YYData->{INPUT} )
	{
		s/^(\@)//
			and return( 'AT', $1 );
		s/^%([^\n]*)\n?//
			and goto REREAD;
		s/^([^\@]+)\n?//
			and goto REREAD;
	}
	die "Lexer failure in level $level: '".$self->YYData->{INPUT}."'\n";
	}

# in-entry
	if( $level == 2 )
	{
	for( $self->YYData->{INPUT} )
	{
		s/^(\d+)//
			and return( 'NUM', $1 );
		s/^(\{)//
			and return( 'LBRACE', $1 );
		s/^(\})//
			and return( 'RBRACE', $1 );
		s/^(\()//
			and return( 'LPAREN', $1 );
		s/^(\))//
			and return( 'RPAREN', $1 );
		s/^(#)//
			and return( 'HASH', $1 );
		s/^(=)//
			and return( 'EQUALS', $1 );
		s/^(,)//
			and return( 'COMMA', $1 );
		s/^($REGEXP_NAME)//o
			and return( 'NAME', $1 );
		s/^"//
			and return( 'STRING', _Lexer_string_quote( $self ));
	}
	die "Lexer failure in level $level: '".$self->YYData->{INPUT}."'\n";
	}

# strings
	if( $level == 3 )
	{
	for( $self->YYData->{INPUT} )
	{
		s/^(#)//
			and return( 'HASH', $1 );
		s/^(\d+)//
			and return( 'NUM', $1 );
		s/^"//
			and return( 'STRING', _Lexer_string_quote( $self ));
		s/^($REGEXP_NAME)//o
			and return( 'NAME', $1 );
		s/^{//
			and return( 'STRING', _Lexer_string_brace( $self ));
	}
		$level = 2;
		goto REREAD;
	}

	die "Lexer failure, unknown level '$level'\n";
}

sub _Lexer_string_brace
{
	my( $self ) = @_;

	my $level = 1;
	my $buffer = "";

	while($level > 0)
	{
		$self->_read_input or last;

		for( $self->YYData->{INPUT} )
		{
			s/^(\{)// and ++$level and $buffer .= "{";
			s/^([^\{\}]+)// and $buffer .= $1;
			s/^(\})// and --$level and $buffer .= "}";
		}
	}

	return $buffer;
}

sub _Lexer_string_quote
{
	my( $self ) = @_;

	my $buffer = "";

	while(1)
	{
		$self->_read_input or last;

		for( $self->YYData->{INPUT} )
		{
			s/^(\\.)// and $buffer .= $1;
			s/^([^\\"]+)// and $buffer .= $1;
			s/^"// and return $buffer;
		}
	}

	return $buffer;
}

sub _read_input
{
	my( $self ) = @_;

	my $r = 0;

	$r ||= length($self->YYData->{INPUT});

	if( !$r and defined $self->YYData->{FH})
	{
		my $fh = $self->YYData->{FH};
		$r ||= defined($self->YYData->{INPUT} = <$fh>);
		++$self->YYData->{LINE};
	}

	return $r;
}

sub _parse
{
	my( $self ) = @_;

	my $r;

	$self->_level( 1 );
	$self->YYData->{LINE} = 0;
	$self->YYData->{ERR} = 0;
	$self->YYData->{ERRMSG} = "";

	$r = $self->YYParse( yylex => \&_Lexer, yyerror => \&_Error );

	return $r;
}

sub parse_fh
{
	my( $self, $file ) = @_;

	my $r;

	$self->YYData->{INPUT} = "";

	$self->YYData->{FH} = $file;
	$r = $self->_parse;

	if( $self->YYData->{ERR} )
	{
		Carp::croak "An error occurred while parsing BibTeX: " . ($self->YYData->{ERRMSG} || 'Unknown error?');
	}

	return $r;
}

sub parse_file
{
	my( $self, $file ) = @_;

	my $r;

	$self->YYData->{INPUT} = "";

	if( ref( $file ) )
	{
		$self->YYData->{FH} = $file;
		$r = $self->_parse;
	}
	else
	{
		open(my $fh, "<", $file)
			or Carp::croak "Unable to open $file for reading: $!";
		$self->YYData->{FH} = $fh;
		$r = $self->_parse;
		close($fh);
	}

	if( $self->YYData->{ERR} )
	{
		Carp::croak "An error occurred while parsing BibTeX: " . ($self->YYData->{ERRMSG} || 'Unknown error?');
	}

	return $r;
}

sub parse_string
{
	my( $self, $data ) = @_;

	my $r;

	$self->YYData->{INPUT} = $data;
	$r = $self->_parse;

	return $r;
}

# End of the grammar

1;
