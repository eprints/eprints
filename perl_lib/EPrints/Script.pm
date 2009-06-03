######################################################################
#
# EPrints::Script
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

B<EPrints::Script> - Mini-scripting language for use in workflow and citations.

=head1 DESCRIPTION

This module processes simple eprints mini-scripts.

 my $result = execute( "$eprint.type = 'article'", { eprint=>$eprint } );

The syntax is

 $var := dataobj or string or datastructure
 "string" := string
 'string' := string
 !boolean := boolean 
 string = string := boolean
 string := string := boolean
 boolean or boolean := boolean
 boolean and boolean := boolean
 dataobj{property} := string or datastructure
 dataobj.is_set( fieldname ) := boolean
 string.one_of( string, string, string... ) := boolean
 string.reverse() := string ( foobar=>raboof ) 
 ?.length() := integer

=cut

package EPrints::Script;

use strict;

sub execute
{
	my( $code, $state ) = @_;

#foreach( keys %{$state} ) { print STDERR "$_: ".$state->{$_}."\n"; }
	$state->{repository} = $state->{session}->get_repository;
	$state->{config} = $state->{session}->get_repository->{config};

	# might be undefined
	$state->{current_user} = $state->{session}->current_user; 
	$state->{current_lang} = [$state->{session}->get_langid, "STRING" ]; 

	my $compiled = EPrints::Script::Compiler->new()->compile( $code, $state->{in} );

#print STDERR $compiled->debug;

	return $compiled->run( $state );
}

sub print
{
	my( $code, $state, $opts ) = @_;

	my $result = execute( $code, $state );	
#	print STDERR  "IFTEST:::".$expr." == $result\n";

	if( $result->[1] eq "XHTML"  )
	{
		return $state->{session}->clone_for_me( $result->[0], 1 );
	}
	if( $result->[1] eq "BOOLEAN"  )
	{
		return $state->{session}->make_text( $result->[0]?"TRUE":"FALSE" );
	}
	if( $result->[1] eq "STRING"  )
	{
		return $state->{session}->make_text( $result->[0] );
	}
	if( $result->[1] eq "DATE"  )
	{
		return $state->{session}->make_text( $result->[0] );
	}
	if( $result->[1] eq "INTEGER"  )
	{
		return $state->{session}->make_text( $result->[0] );
	}

	my $field = $result->[1];

	# apply any render opts
	if( defined $opts && $opts ne "" )
	{
		$field = $field->clone;
		
		foreach my $opt ( split( /;/, $opts ) )
		{
			my( $k, $v ) = split( /=/, $opt );
			$v = 1 unless defined $v;
			$field->set_property( "render_$k", $v );
		}
	}
#print STDERR "(".$result->[0].",".$result->[1].")\n";

	if( !defined $field )
	{
		return $state->{session}->make_text( "[No type for value '$result->[0]' from '$code']" );
	}

	return $field->render_value( $state->{session}, $result->[0], 0, 0, $result->[2] );
}

sub error
{
	my( $msg, $in, $pos, $code ) = @_;
#print STDERR "msg:$msg\n";
#print STDERR "POS:$pos\n";
	
	my $error = "Script in ".(defined $in?$in:"unknown").": ".$msg;
	if( defined $pos ) { $error.= " at character ".$pos; }
	if( defined $code ) { $error .= "\n".$code; }
	if( defined $code && defined $pos ) {  $error .=  "\n".(" "x$pos). "^ here"; }
	EPrints::abort( $error );
}

package EPrints::Script::Compiled;

use Time::Local 'timelocal_nocheck';

sub debug
{
	my( $self, $depth ) = @_;

	$depth = $depth || 0;
	my $r = "";

	$r.= "  "x$depth;
	$r.= $self->{id};
	if( defined $self->{value} ) { $r.= " (".$self->{value}.")"; }
	if( defined $self->{pos} ) { $r.= "   #".$self->{pos}; }
	$r.= "\n";
	foreach( @{$self->{params}} )
	{
		$r.=debug( $_, $depth+1 );
	}
	return $r;
}

sub run
{
	my( $self, $state ) = @_;

	if( !defined $self->{id} ) 
	{
		$self->runtime_error( "No ID in tree node" );
	}

	if( $self->{id} eq "INTEGER" )
	{
		return [ $self->{value}, "INTEGER" ];
	}
	if( $self->{id} eq "STRING" )
	{
		return [ $self->{value}, "STRING" ];
	}

	if( $self->{id} eq "VAR" )
	{
		my $r = $state->{$self->{value}};
		if( !defined $r )
		{
			#runtime_error( "Unknown state variable ".$self->{value} );
		
			return [ 0, "BOOLEAN" ];
		}
		return $r if( ref( $r ) eq "ARRAY" );
		return [ $r ];
	}

	my @params;
	foreach my $param ( @{$self->{params}} ) 
	{ 
		my $p = $param->run( $state ); 
		push @params, $p;
	}

	my $fn = "run_".$self->{id};

        if( !defined $EPrints::Script::Compiled::{$fn} )
        {
		$self->runtime_error( "call to unknown fuction: ".$self->{id} );
                next;
        }

	no strict "refs";
	my $result = $self->$fn( $state, @params );
	use strict "refs";

	return $result;
}

sub runtime_error 
{ 
	my( $self, $msg ) = @_;

	EPrints::Script::error( $msg, $self->{in}, $self->{pos}, $self->{code} )
}

sub run_LESS_THAN
{
	my( $self, $state, $left, $right ) = @_;

	if( ref( $left->[1] ) eq "EPrints::MetaField::Date" || ref( $left->[1] ) eq "EPrints::MetaField::Time" || $left->[1] eq "DATE" )
	{
		return [ ($left->[0]||"0000") lt ($right->[0]||"0000"), "BOOLEAN" ];
	}
	
	return [ $left->[0] < $right->[0], "BOOLEAN" ];
}

sub run_GREATER_THAN
{
	my( $self, $state, $left, $right ) = @_;

	if( ref( $left->[1] ) eq "EPrints::MetaField::Date" || ref( $left->[1] ) eq "EPrints::MetaField::Time" || $left->[1] eq "DATE" )
	{
		return [ ($left->[0]||"0000") gt ($right->[0]||"0000"), "BOOLEAN" ];
	}
	
	return [ $left->[0] > $right->[0], "BOOLEAN" ];
}

sub run_EQUALS
{
	my( $self, $state, $left, $right ) = @_;

	if( $right->[1]->isa("EPrints::MetaField") && $right->[1]->{multiple} )
	{
		foreach( @{$right->[0]} )
		{
			return [ 1, "BOOLEAN" ] if( $_ eq $left->[0] );
		}
		return [ 0, "BOOLEAN" ];
	}
	
	if( $left->[1]->isa( "EPrints::MetaField") && $left->[1]->{multiple} )
	{
		foreach( @{$left->[0]} )
		{
			return [ 1, "BOOLEAN" ] if( $_ eq $right->[0] );
		}
		return [ 0, "BOOLEAN" ];
	}
	my $l = $left->[0];
	$l = "" if( !defined $l );
	my $r = $right->[0];
	$r = "" if( !defined $r );
	
	return [ $l eq $r, "BOOLEAN" ];
}

sub run_NOTEQUALS
{
	my( $self, $state, $left, $right ) = @_;

	my $r = $self->run_EQUALS( $state, $left, $right );
	
	return $self->run_NOT( $state, $r );
}

sub run_NOT
{
	my( $self, $state, $left ) = @_;

	return [ !$left->[0], "BOOLEAN" ];
}

sub run_AND
{
	my( $self, $state, $left, $right ) = @_;
	
	return [ $left->[0] && $right->[0], "BOOLEAN" ];
}

sub run_OR
{
	my( $self, $state, $left, $right ) = @_;
	
	return [ $left->[0] || $right->[0], "BOOLEAN" ];
}

sub run_PROPERTY
{
	my( $self, $state, $objvar ) = @_;

	if( !defined $objvar->[0] )
	{
		$self->runtime_error( "can't get a property {".$self->{value}."} from undefined value" );
	}
	my $ref = ref($objvar->[0]);
	if( $ref eq "HASH" )
	{
		my $v = $objvar->[0]->{ $self->{value} };
		my $type = ref( $v );
		$type = "STRING" if( $type eq "" ); 	
		$type = "XHTML" if( $type =~ /^XML::/ );
		return [ $v, $type ];
	}
	if( $ref !~ m/::/ )
	{
		$self->runtime_error( "can't get a property from anything except a hash or object: ".$self->{value}." (it was '$ref')." );
	}
	if( !$objvar->[0]->isa( "EPrints::DataObj" ) )
	{
		$self->runtime_error( "can't get a property from non-dataobj: ".$self->{value} );
	}
	if( !$objvar->[0]->get_dataset->has_field( $self->{value} ) )
	{
		$self->runtime_error( $objvar->[0]->get_dataset->confid . " object does not have a '".$self->{value}."' field" );
	}

	return [ 
		$objvar->[0]->get_value( $self->{value} ),
		$objvar->[0]->get_dataset->get_field( $self->{value} ),
		$objvar->[0] ];
}

sub run_MAIN_ITEM_PROPERTY
{
	my( $self, $state ) = @_;

	return run_PROPERTY( $self, $state, [$state->{item}] );
}

sub run_reverse
{
	my( $self, $state, $string ) = @_;

	return [ reverse $string->[0], "STRING" ];
} 
	
sub run_is_set
{
	my( $self, $state, $param ) = @_;

	return [ EPrints::Utils::is_set( $param->[0] ), "BOOLEAN" ];
} 

sub run_citation_link
{
	my( $self, $state, $object, $citationid ) = @_;

	my $citation = $object->[0]->render_citation_link( $citationid->[0]  );

	return [ $citation, "XHTML" ];
}

sub run_citation
{
	my( $self, $state, $object, $citationid ) = @_;

	my $stylespec = $state->{session}->get_citation_spec( $object->[0]->get_dataset, $citationid->[0] );

	my $citation = EPrints::XML::EPC::process( $stylespec, item=>$object->[0], session=>$state->{session}, in=>"Citation:".$object->[0]->get_dataset.".".$citationid->[0] );

	return [ $citation, "XHTML" ];
}

sub run_yesno
{
	my( $self, $state, $left ) = @_;

	if( $left->[0] )
	{
		return [ "yes", "STRING" ];
	}

	return [ "no", "STRING" ];
}

sub run_one_of
{
	my( $self, $state, $left, @list ) = @_;

	if( !defined $left )
	{
		return [ 0, "BOOLEAN" ];
	}
	if( !defined $left->[0] )
	{
		return [ 0, "BOOLEAN" ];
	}

	foreach( @list )
	{
		my $result = $self->run_EQUALS( $state, $left, $_ );
		return [ 1, "BOOLEAN" ] if( $result->[0] );
	}
	return [ 0, "BOOLEAN" ];
} 

sub run_as_item 
{
	my( $self, $state, $itemref ) = @_;

	if( !$itemref->[1]->isa( "EPrints::MetaField::Itemref" ) )
	{
		$self->runtime_error( "can't call as_item on anything but a value of type itemref" );
	}

	my $object = $itemref->[1]->get_item( $state->{session}, $itemref->[0] );

	return [ $object ];
}

sub run_as_string
{
	my( $self, $state, $value ) = @_;

	return [ $value->[0], "STRING" ];
}

sub run_strlen
{
	my( $self, $state, $value ) = @_;

	if( !EPrints::Utils::is_set( $value->[0] ) )
	{
		return [0,"INTEGER"];
	}

	return [ length( $value->[0] ), "INTEGER" ];
}

sub run_length
{
	my( $self, $state, $value ) = @_;

	if( !EPrints::Utils::is_set( $value->[0] ) )
	{
		return [0,"INTEGER"];
	}
	
	if( !$value->[1]->isa( "EPrints::MetaField" ) )
	{
		return [1,"INTEGER"];
	}

	if( !$value->[1]->get_property( "multiple" ) ) 
	{
		return [1,"INTEGER"];
	}

	return [ scalar @{$value->[0]}, "INTEGER" ];
}

sub run_render_data_row
{
	my( $self, $state, $value ) = @_;

	if( !$value->[1]->isa( "EPrints::MetaField" ) )
	{
		$self->runtime_error( "can't call render_data_row on non-field values." );
	}

	return [ $state->{session}->html_phrase( "data_row", 
			name => $value->[1]->render_name( $state->{session} ),
			value => $value->[1]->render_value( $state->{session}, $value->[0] ) ),
		 "XHTML" ];
}

sub run_today
{
	my( $self, $state ) = @_;

	return [EPrints::Time::get_iso_date, "DATE"];
}

sub run_datemath
{
	my( $self, $state, $date, $alter, $type ) = @_;

	my( $year, $month, $day ) = split( "-", $date->[0] );

	if( $type->[0] eq "day" )
	{
		$day+=$alter->[0];
	}
	elsif( $type->[0] eq "month" )
	{
		$month+=$alter->[0];
		while( $month < 1 )
		{
			$year--;
			$month += 12;
		}
		while( $month > 12 )
		{
			$year++;
			$month -= 12;
		}
		
	}
	elsif( $type->[0] eq "year" )
	{
		$year+=$alter->[0];
	}
	else
	{
		return [ "DATE ERROR: Unknown part '".$type->[0]."'", "STRING" ];
	}

        my $t = timelocal_nocheck( 0,0,0,$day,$month-1,$year-1900 );

	return [ EPrints::Time::get_iso_date( $t ), "DATE" ];
}

sub run_dataset 
{
	my( $self, $state, $object ) = @_;

	if( !$object->[0]->isa( "EPrints::DataObj" ) )
	{
		$self->runtime_error( "can't call dataset on non-data objects." );
	}

	return [ $object->[0]->get_dataset->confid, "STRING" ];
}


sub run_related_objects
{
	my( $self, $state, $object, @required ) = @_;

	if( !defined $object->[0] || ref($object->[0])!~m/^EPrints::DataObj::/ )
	{
		$self->runtime_error( "can't call dataset on non-data objects." );
	}

	my @r = ();
	foreach( @required ) { push @r, $_->[0]; }
	
	return [ $object->[0]->get_related_objects( @r ) ];
}

sub run_url
{
	my( $self, $state, $object ) = @_;

	if( !defined $object->[0] || ref($object->[0])!~m/^EPrints::DataObj::/ )
	{
		$self->runtime_error( "can't call url() on non-data objects." );
	}

	return [ $object->[0]->get_url, "STRING" ];
}

sub run_doc_size
{
	my( $self, $state, $doc ) = @_;

	if( !defined $doc->[0] || ref($doc->[0]) ne "EPrints::DataObj::Document" )
	{
		$self->runtime_error( "Can only call document_size() on document objects not ".
			ref($doc->[0]) );
	}

	my %files = $doc->[0]->files;

	return $files{$doc->[0]->get_main} || 0;
}

sub run_is_public
{
	my( $self, $state, $doc ) = @_;

	if( !defined $doc->[0] || ref($doc->[0]) ne "EPrints::DataObj::Document" )
	{
		$self->runtime_error( "Can only call document_size() on document objects not ".
			ref($doc->[0]) );
	}

	return [ $doc->[0]->is_public, "BOOLEAN" ];
}

sub run_thumbnail_url
{
	my( $self, $state, $doc, $size ) = @_;

	if( !defined $doc->[0] || ref($doc->[0]) ne "EPrints::DataObj::Document" )
	{
		$self->runtime_error( "Can only call thumbnail_url() on document objects not ".
			ref($doc->[0]) );
	}

	return [ $doc->[0]->thumbnail_url( $size->[0] ), "STRING" ];
}

sub run_preview_link
{
	my( $self, $state, $doc, $caption, $set ) = @_;

	if( !defined $doc->[0] || ref($doc->[0]) ne "EPrints::DataObj::Document" )
	{
		$self->runtime_error( "Can only call thumbnail_url() on document objects not ".
			ref($doc->[0]) );
	}

	return [ $doc->[0]->render_preview_link( caption=>$caption->[0], set=>$set->[0] ), "XHTML" ];
}

sub run_icon
{
	my( $self, $state, $doc, $preview, $new_window ) = @_;

	if( !defined $doc->[0] || ref($doc->[0]) ne "EPrints::DataObj::Document" )
	{
		$self->runtime_error( "Can only call thumbnail_url() on document objects not ".
			ref($doc->[0]) );
	}

	return [ $doc->[0]->render_icon_link( preview=>$preview->[0], new_window=>$new_window->[0] ), "XHTML" ];
}


sub run_human_filesize
{
	my( $self, $state, $size_in_bytes ) = @_;

	return [ EPrints::Utils::human_filesize( $size_in_bytes || 0 ), "INTEGER" ];
}

sub run_control_url
{
	my( $self, $state, $eprint ) = @_;

	if( !defined $eprint->[0] || ref($eprint->[0]) ne "EPrints::DataObj::EPrint" )
	{
		$self->runtime_error( "Can only call control_url() on eprint objects not ".
			ref($eprint->[0]) );
	}

	return [ $eprint->[0]->get_control_url(), "STRING" ];
}

sub run_contact_email
{
	my( $self, $state, $eprint ) = @_;

	if( !defined $eprint->[0] || ref($eprint->[0]) ne "EPrints::DataObj::EPrint" )
	{
		$self->runtime_error( "Can only call contact_email() on eprint objects not ".
			ref($eprint->[0]) );
	}

	if( !$state->{session}->get_repository->can_call( "email_for_doc_request" ) )
	{
		return [ undef, "STRING" ];
	}

	return [ $state->{session}->get_repository->call( "email_for_doc_request", $state->{session}, $eprint->[0] ), "STRING" ]; 
}


########################################################


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

my $x=<<__;
EXPR = AND_EXPR + ( "or" + EXPR)?
AND_EXPR = OR_EXPR + ( "and" + AND_EXPR )?
OR_EXPR = TEST_EXPR + ( "or" + OR_EXPR )?
TEST_EXPR = NOT_EXPR + ( TESTOP + TEST_EXPR )?
TEST_OP = "=" 
        | "!=" 
NOT_EXPR = ("!")? + METH_EXPR
METH_EXPR = B_EXPR + METH_OR_PROP*
METH_OR_PROP = "{" + ident + "}"		# property	
             | "." + ident + "(" + LIST + ")"	# method
B_EXPR = THING 
       | "(" + EXPR + ")"
THING = VAR 
      | string
      | ident				# item param shortcut
      | ident + "(" + LIST + ")"	# function
VAR = "\$" + IDENT

LIST = "" 
     | EXPR + ( "," + EXPR )*

__



