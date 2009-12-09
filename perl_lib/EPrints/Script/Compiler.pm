######################################################################
#
# EPrints::Script::Compiler
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::Script::Compiler> - Compiler used by EPrints::Script

=cut 

package EPrints::Script::Compiler;

use strict;

sub new
{
	my( $class ) = @_;

	return bless {}, $class;
}

sub compile
{
	my( $self, $code, $in ) = @_;

	$in = "unknown" unless defined $in;

	$self->{code} = $code;
	$self->{in} = $in;	
	$self->{tokens} = [];

	$self->tokenise;
	
	if( scalar @{$self->{tokens}} == 0 ) 
	{
		#$state->{session}->get_repository->log( "Script in: ".$state->{in}.": Empty script." );
		return [ 0, "BOOLEAN" ];
	}
		
	return $self->compile_expr;
}


sub tokenise
{
	my( $self ) = @_;

	my $code = $self->{code};
	my $len = length $code;

	while( $code ne "" )
	{
		my $pos = $len-length $code;
		if( $code =~ s/^\s+// ) { next; }
		my $newtoken;
		if( $code =~ s/^'([^']*)'// ) { $newtoken= { pos=>$pos, id=>'STRING',value=>$1 }; }
		elsif( $code =~ s/^"([^"]*)"// ) { $newtoken= { pos=>$pos, id=>'STRING',value=>$1 };  }
		elsif( $code =~ s/^\$// ) { $newtoken= { pos=>$pos, id=>'DOLLAR',value=>$1 };  }
		elsif( $code =~ s/^\.// ) { $newtoken= { pos=>$pos, id=>'DOT', value=>$1 };  }
		elsif( $code =~ s/^\(// ) { $newtoken= { pos=>$pos, id=>'OPEN_B' };  }
		elsif( $code =~ s/^\)// ) { $newtoken= { pos=>$pos, id=>'CLOSE_B' };  }
		elsif( $code =~ s/^\{// ) { $newtoken= { pos=>$pos, id=>'OPEN_C' };  }
		elsif( $code =~ s/^\}// ) { $newtoken= { pos=>$pos, id=>'CLOSE_C' };  }
		elsif( $code =~ s/^=// ) { $newtoken= { pos=>$pos, id=>'EQUALS' };  }
		elsif( $code =~ s/^!=// ) { $newtoken= { pos=>$pos, id=>'NOTEQUALS' };  }
		elsif( $code =~ s/^gt\b// ) { $newtoken= { pos=>$pos, id=>'GREATER_THAN' };  }
		elsif( $code =~ s/^lt\b// ) { $newtoken= { pos=>$pos, id=>'LESS_THAN' };  }
		elsif( $code =~ s/^,// ) { $newtoken= { pos=>$pos, id=>'COMMA' };  }
		elsif( $code =~ s/^!// ) { $newtoken= { pos=>$pos, id=>'NOT' };  }
		elsif( $code =~ s/^and\b// ) { $newtoken= { pos=>$pos, id=>'AND' };  }
		elsif( $code =~ s/^or\b// ) { $newtoken= { pos=>$pos, id=>'OR' };  }
		elsif( $code =~ s/^(\-?[0-9]+)// ) { $newtoken= { pos=>$pos, id=>'INTEGER', value=>$1 };  }
		elsif( $code =~ s/^([a-zA-Z][a-zA-Z0-9_-]*)// ) { $newtoken= { pos=>$pos, id=>'IDENT', value=>$1 };  }
		else { $self->compile_error( "Parse error near: ".substr( $code, 0, 20) ); }

		$newtoken->{in} = $self->{in};
		$newtoken->{code} = $self->{code};
		push @{$self->{tokens}}, bless $newtoken, "EPrints::Script::Compiled";
	}
}

sub give_me
{
	my( $self, $want, $err_msg ) = @_;

	my $token = shift @{$self->{tokens}}; # pull off list

	if( !defined $token || $token->{id} ne $want )
	{
		if( !defined $err_msg )
		{
			$err_msg = "Expected $want";
		}	
		if( !defined $token )
		{
			$err_msg.=" (found end of script)";
		}
		else
		{
			$err_msg.=" (found ".$token->{id}.")";
		}
		$self->compile_error( $err_msg );
	}

	return $token;
}

sub next_is
{
	my( $self, $type ) = @_;

	return 0 if !defined $self->{tokens}->[0];

	return( $self->{tokens}->[0]->{id} eq $type );
}

sub compile_expr
{
	my( $self ) = @_;

	my $tree = $self->compile_and_expr;
	
	if( $self->next_is( "OR" ) )
	{
		my $left = $tree;
		my $or = $self->give_me( "OR" );
		my $right = $self->compile_expr;	
		$or->{params} = [ $left, $right ];
		return $or;
	}

	return $tree;

}

sub compile_and_expr
{
	my( $self ) = @_;

	my $tree = $self->compile_test_expr;
	
	if( $self->next_is( "AND" ) )
	{
		my $left = $tree;
		my $and = $self->give_me( "AND" );
		my $right = $self->compile_and_expr;	
		$and->{params} = [ $left, $right ];
		return $and;
	}

	return $tree;
}


sub compile_test_expr
{
	my( $self ) = @_;

	my $tree = $self->compile_not_expr;

	foreach my $test ( qw/ EQUALS NOTEQUALS GREATER_THAN LESS_THAN / )
	{
		next unless( $self->next_is( $test ) );
		my $left = $tree;
		my $eq = $self->give_me( $test );
		my $right = $self->compile_test_expr;	
		$eq->{params} = [ $left, $right ];
		return $eq;
	}

	return $tree;
}

sub compile_not_expr
{
	my( $self ) = @_;

	if( $self->next_is( "NOT" ) )	
	{
		my $not = $self->give_me( "NOT" );
		my $param = $self->compile_not_expr;
		$not->{params} = [ $param ];
		return $not;
	}

	return $self->compile_method_expr;
}

# METH_EXPR = B_EXPR + METH_OR_PROP*
# METH_OR_PROP = "{" + ident + "}"		# property	
#              | "." + ident + "(" + LIST + ")"	# method

sub compile_method_expr
{
	my( $self ) = @_;

	my $tree = $self->compile_b_expr;

	while( $self->next_is( "DOT" ) || $self->next_is( "OPEN_C" ) )
	{	
		# method.
		if( $self->next_is( "DOT" ) )
		{
			$self->give_me( "DOT" );
			
			my $method_on = $tree;

			$tree = $self->give_me( "IDENT", "expected method name after dot" );
			
			$self->give_me( "OPEN_B", "expected opening method bracket" ); 

			$tree->{id} = $tree->{value};
			$tree->{params} = [ $method_on, @{$self->compile_list} ]; # like ( $self, @params ) in Perl

			$self->give_me( "CLOSE_B", "expected closing method bracket" ); 

			next;
		}

		# property.
		if( $self->next_is( "OPEN_C" ) )
		{
			$self->give_me( "OPEN_C", "expected opening curly bracket" ); 
			
			my $prop_on = $tree;

			$tree = $self->give_me( "IDENT", "expected property name after {" );

			$tree->{id} = "PROPERTY";
			$tree->{params} = [ $prop_on ];

			$self->give_me( "CLOSE_C", "expected closing curly bracket" ); 

			next;
		}

		$self->compile_error( "odd error. this code should be unreachable" );
	}

	return $tree;
}

sub compile_b_expr
{
	my( $self ) = @_;

	if( !defined $self->{tokens}->[0] )
	{
		$self->compile_error( "expected '(', string, variable or function" );
	}

	if( $self->next_is( "OPEN_B" ) )
	{
		$self->give_me( "OPEN_B", "expected opening bracket" ); 
		my $tree = $self->compile_expr;
		$self->give_me( "CLOSE_B", "expected closing bracket" ); 
		return $tree;
	}

	return $self->compile_thing;
}

# THING = VAR 
#       | string
#       | ident				# item param shortcut
#       | integer
#       | ident + "(" + LIST + ")"	# function
# VAR   = "\$" + IDENT

sub compile_thing
{
	my( $self ) = @_;

	if( $self->next_is( "INTEGER" ) )
	{
		return $self->give_me( "INTEGER" );
	}
	if( $self->next_is( "STRING" ) )
	{
		return $self->give_me( "STRING" );
	}

	if( $self->next_is( "DOLLAR" ) )
	{
		$self->give_me( "DOLLAR", "Expected dollar" );
		my $var = $self->give_me( "IDENT", "Expected state variable name" );
		$var->{id} = "VAR";
		return $var;
	}

	my $ident = $self->give_me( "IDENT", "Expected function, main-item parameter name, string or state variable" );

	# function
	if( $self->next_is( "OPEN_B" ) )
	{
		$self->give_me( "OPEN_B", "Expected open bracket" );

		$ident->{id} = $ident->{value};
		$ident->{params} = [ @{$self->compile_list} ];

		$self->give_me( "CLOSE_B", "Expected close bracket" );

		return $ident;
	}

	# must be an ident by itself (shortcut for $item{foo}

	$ident->{id} = "MAIN_ITEM_PROPERTY";
	return $ident;
}

sub compile_list
{
	my( $self ) = @_;

	return [] if( $self->next_is( "CLOSE_B" ) );

	my $values = [];
	push @$values, $self->compile_expr;
	while( $self->next_is( "COMMA" ) )
	{
		$self->give_me( "COMMA", "Expected comma" );
		push @$values, $self->compile_expr;
	}
	
	return $values;
}

sub compile_error 
{ 
	my( $self, $msg ) = @_;

	EPrints::Script::error( $msg, $self->{in}, $self->{tokens}->[0]->{pos}, $self->{code} );
}	

1;
