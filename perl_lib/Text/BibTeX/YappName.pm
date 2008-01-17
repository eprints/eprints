####################################################################
#
#    This file was generated using Parse::Yapp version 1.05.
#
#        Don't edit this file, use source file instead.
#
#             ANY CHANGE MADE HERE WILL BE LOST !
#
####################################################################
package Text::BibTeX::YappName;
use vars qw ( @ISA );
use strict;

@ISA= qw ( Parse::Yapp::Driver );
use Parse::Yapp::Driver;



=head1 NAME

Text::BibTeX::YappName - Parse BibTeX names

=head1 SYNOPSIS

	use Text::BibTeX::YappName;

	my $parser = Text::BibTeX::YappName->new;

	my $names = $parser->parse_string( "John Smith" );

	my $name = $names->[0];

	printf("%s, %s\n", $name->last, $name->first);
	# $name->von, $name->jr

=head1 SEE ALSO

L<Text::BibTeX::Yapp>

=cut

{
package Text::BibTeX::Name;

use overload '""' => \&to_string;

sub new
{
	my( $class, @parts ) = @_;

	(ref($_) and ($_ = join(' ', @$_))) for @parts;

	bless \@parts, $class;
}

sub first { $_[0]->[0] }
sub von { $_[0]->[1] }
sub last { $_[0]->[2] }
sub jr { $_[0]->[3] }

sub to_string
{
	join ' ', map { defined $_ ? $_ : () } @{$_[0]};
}
}

use Carp;

our $REGEXP_VON = qr/[a-z][^ ,]*/;



sub new {
        my($class)=shift;
        ref($class)
    and $class=ref($class);

    my($self)=$class->SUPER::new( yyversion => '1.05',
                                  yystates =>
[
	{#State 0
		ACTIONS => {
			'PART' => 3,
			'VON' => 6
		},
		DEFAULT => -1,
		GOTOS => {
			'vons' => 1,
			'names' => 2,
			'name' => 5,
			'parts' => 4
		}
	},
	{#State 1
		ACTIONS => {
			'PART' => 3
		},
		GOTOS => {
			'parts' => 7
		}
	},
	{#State 2
		ACTIONS => {
			'' => 8
		}
	},
	{#State 3
		ACTIONS => {
			'PART' => 3
		},
		DEFAULT => -10,
		GOTOS => {
			'parts' => 9
		}
	},
	{#State 4
		ACTIONS => {
			'COMMA' => 11,
			'VON' => 6
		},
		DEFAULT => -4,
		GOTOS => {
			'vons' => 10
		}
	},
	{#State 5
		ACTIONS => {
			'AND' => 12
		},
		DEFAULT => -2
	},
	{#State 6
		ACTIONS => {
			'VON' => 6
		},
		DEFAULT => -12,
		GOTOS => {
			'vons' => 13
		}
	},
	{#State 7
		ACTIONS => {
			'COMMA' => 14
		}
	},
	{#State 8
		DEFAULT => 0
	},
	{#State 9
		DEFAULT => -11
	},
	{#State 10
		ACTIONS => {
			'PART' => 3
		},
		GOTOS => {
			'parts' => 15
		}
	},
	{#State 11
		ACTIONS => {
			'PART' => 3
		},
		GOTOS => {
			'parts' => 16
		}
	},
	{#State 12
		ACTIONS => {
			'PART' => 3,
			'VON' => 6
		},
		DEFAULT => -1,
		GOTOS => {
			'vons' => 1,
			'names' => 17,
			'name' => 5,
			'parts' => 4
		}
	},
	{#State 13
		DEFAULT => -13
	},
	{#State 14
		ACTIONS => {
			'PART' => 3
		},
		GOTOS => {
			'parts' => 18
		}
	},
	{#State 15
		DEFAULT => -6
	},
	{#State 16
		ACTIONS => {
			'COMMA' => 19
		},
		DEFAULT => -5
	},
	{#State 17
		DEFAULT => -3
	},
	{#State 18
		ACTIONS => {
			'COMMA' => 20
		},
		DEFAULT => -7
	},
	{#State 19
		ACTIONS => {
			'PART' => 3
		},
		GOTOS => {
			'parts' => 21
		}
	},
	{#State 20
		ACTIONS => {
			'PART' => 3
		},
		GOTOS => {
			'parts' => 22
		}
	},
	{#State 21
		DEFAULT => -8
	},
	{#State 22
		DEFAULT => -9
	}
],
                                  yyrules  =>
[
	[#Rule 0
		 '$start', 2, undef
	],
	[#Rule 1
		 'names', 0, undef
	],
	[#Rule 2
		 'names', 1,
sub { [ $_[1] ] }
	],
	[#Rule 3
		 'names', 3,
sub { [ $_[1], @{$_[3]} ] }
	],
	[#Rule 4
		 'name', 1,
sub { Text::BibTeX::Name->new( $_[1], undef, pop @{$_[1]} ) }
	],
	[#Rule 5
		 'name', 3,
sub { Text::BibTeX::Name->new( $_[3], undef, $_[1] ) }
	],
	[#Rule 6
		 'name', 3,
sub { Text::BibTeX::Name->new( $_[1], $_[2], $_[3] ) }
	],
	[#Rule 7
		 'name', 4,
sub { Text::BibTeX::Name->new( $_[4], $_[1], $_[2] ) }
	],
	[#Rule 8
		 'name', 5,
sub { Text::BibTeX::Name->new( $_[5], undef, $_[1], $_[3] ) }
	],
	[#Rule 9
		 'name', 6,
sub { Text::BibTeX::Name->new( $_[6], $_[1], $_[2], $_[4] ) }
	],
	[#Rule 10
		 'parts', 1,
sub { [ $_[1] ] }
	],
	[#Rule 11
		 'parts', 2,
sub { [ $_[1], @{$_[2]} ] }
	],
	[#Rule 12
		 'vons', 1,
sub { [ $_[1] ] }
	],
	[#Rule 13
		 'vons', 2,
sub { [ $_[1], @{$_[2]} ] }
	]
],
                                  @_);
    bless($self,$class);
}


#footer

sub _Lexer_debug
{
	my( $self ) = @_;

	my( $token, $value ) = _Lexer( $self );

	print "$token => [".($value||'')."]\n";

	return( $token, $value );
}

sub _Lexer
{
	my( $self ) = @_;

	$self->YYData->{INPUT} =~ s/\n/ /g;
	$self->YYData->{INPUT} =~ s/^[ \t\r]+//;

	length($self->YYData->{INPUT})
	or return ('', undef);

	for($self->YYData->{INPUT})
	{
		s/^and //
			and return( "AND" );
		s/^,//
			and return( "COMMA" );
		s/^($REGEXP_VON)//
			and return( "VON", $1 );
		my $buffer = "";
		while( s/^(\{|[^ ,])// )
		{
			if( $1 eq '{' )
			{
				$buffer .= _Lexer_brace( $self );
			}
			else
			{
				$buffer .= $1;
			}
		}
		return( "PART", $buffer );
	}
}

sub _Lexer_brace
{
	my( $self ) = @_;

	my $buffer = "{";
	my $level = 1;

	while($level > 0)
	{
		length($self->YYData->{INPUT})
		or last;

		for($self->YYData->{INPUT})
		{
			s/^([^\{\}]+)// and $buffer .= $1;
			s/^(\{)// and ++$level and $buffer .= $1;
			s/^(\})// and $level-- and $buffer .= $1;
		}
	}

	return $buffer;
}

sub _Error
{
	my( $self ) = @_;

	$self->YYData->{ERR} = 1;
	$self->YYData->{ERRMSG} = "Unrecognised input near line " . $self->YYData->{LINE};
}

sub parse_string
{
	my( $self, $data ) = @_;

	$self->YYData->{INPUT} = $data;

	my $r = $self->YYParse( yylex => \&_Lexer, yyerror => \&_Error );

	if( $self->YYData->{ERR} )
	{
		Carp::croak "An error occurred while parsing BibTeX: " . ($self->YYData->{ERRMSG} || 'Unknown error?');
	}

	return $r;
}

# End of Grammar

1;
