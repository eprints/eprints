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

	# [ "Tim", "Brody", ] => "Tim Brody"
	(ref($_) and ($_ = join(' ', @$_))) for @parts;

	bless \@parts, $class;
}

sub first { $_[0]->[0] }
sub von { $_[0]->[1] }
sub last { $_[0]->[2] }
sub jr { $_[0]->[3] }
sub email { $_[0]->[4] }

sub to_string
{
	join(' ', map { defined $_ ? $_ : () } @{$_[0..3]}) .
		(defined($_[4]) ? sprintf(" <%s>", $_[4]) : "");
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
			'parts' => 4,
			'name_email' => 7
		}
	},
	{#State 1
		ACTIONS => {
			'PART' => 3
		},
		GOTOS => {
			'parts' => 8
		}
	},
	{#State 2
		ACTIONS => {
			'' => 9
		}
	},
	{#State 3
		ACTIONS => {
			'PART' => 3
		},
		DEFAULT => -12,
		GOTOS => {
			'parts' => 10
		}
	},
	{#State 4
		ACTIONS => {
			'COMMA' => 12,
			'VON' => 6
		},
		DEFAULT => -6,
		GOTOS => {
			'vons' => 11
		}
	},
	{#State 5
		ACTIONS => {
			'EMAIL' => 13
		},
		DEFAULT => -5
	},
	{#State 6
		ACTIONS => {
			'VON' => 6
		},
		DEFAULT => -14,
		GOTOS => {
			'vons' => 14
		}
	},
	{#State 7
		ACTIONS => {
			'AND' => 15
		},
		DEFAULT => -2
	},
	{#State 8
		ACTIONS => {
			'COMMA' => 16
		}
	},
	{#State 9
		DEFAULT => 0
	},
	{#State 10
		DEFAULT => -13
	},
	{#State 11
		ACTIONS => {
			'PART' => 3
		},
		GOTOS => {
			'parts' => 17
		}
	},
	{#State 12
		ACTIONS => {
			'PART' => 3
		},
		GOTOS => {
			'parts' => 18
		}
	},
	{#State 13
		DEFAULT => -4
	},
	{#State 14
		DEFAULT => -15
	},
	{#State 15
		ACTIONS => {
			'PART' => 3,
			'VON' => 6
		},
		DEFAULT => -1,
		GOTOS => {
			'vons' => 1,
			'names' => 19,
			'name' => 5,
			'parts' => 4,
			'name_email' => 7
		}
	},
	{#State 16
		ACTIONS => {
			'PART' => 3
		},
		GOTOS => {
			'parts' => 20
		}
	},
	{#State 17
		DEFAULT => -8
	},
	{#State 18
		ACTIONS => {
			'COMMA' => 21
		},
		DEFAULT => -7
	},
	{#State 19
		DEFAULT => -3
	},
	{#State 20
		ACTIONS => {
			'COMMA' => 22
		},
		DEFAULT => -9
	},
	{#State 21
		ACTIONS => {
			'PART' => 3
		},
		GOTOS => {
			'parts' => 23
		}
	},
	{#State 22
		ACTIONS => {
			'PART' => 3
		},
		GOTOS => {
			'parts' => 24
		}
	},
	{#State 23
		DEFAULT => -10
	},
	{#State 24
		DEFAULT => -11
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
		 'name_email', 2,
sub { $_[1]->[4] = $_[2]; $_[1] }
	],
	[#Rule 5
		 'name_email', 1, undef
	],
	[#Rule 6
		 'name', 1,
sub { Text::BibTeX::Name->new( $_[1], undef, pop @{$_[1]} ) }
	],
	[#Rule 7
		 'name', 3,
sub { Text::BibTeX::Name->new( $_[3], undef, $_[1] ) }
	],
	[#Rule 8
		 'name', 3,
sub { Text::BibTeX::Name->new( $_[1], $_[2], $_[3] ) }
	],
	[#Rule 9
		 'name', 4,
sub { Text::BibTeX::Name->new( $_[4], $_[1], $_[2] ) }
	],
	[#Rule 10
		 'name', 5,
sub { Text::BibTeX::Name->new( $_[5], undef, $_[1], $_[3] ) }
	],
	[#Rule 11
		 'name', 6,
sub { Text::BibTeX::Name->new( $_[6], $_[1], $_[2], $_[4] ) }
	],
	[#Rule 12
		 'parts', 1,
sub { [ $_[1] ] }
	],
	[#Rule 13
		 'parts', 2,
sub { [ $_[1], @{$_[2]} ] }
	],
	[#Rule 14
		 'vons', 1,
sub { [ $_[1] ] }
	],
	[#Rule 15
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
		s/^<([^>]+)>//
			and return( "EMAIL", $1 );
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
