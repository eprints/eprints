######################################################################
#
# EPrints::MetaField::Name;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Name> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Name;

use EPrints::MetaField::Multipart;

@ISA = qw( EPrints::MetaField::Multipart );

use strict;

sub new
{
	my ($class, %params) = @_;

	my $self = $class->SUPER::new(%params);

	# override field input_cols
	if (defined(my $cols = $self->property('input_name_cols')))
	{
		foreach my $name (keys %$cols)
		{
			my $field = $self->{fields_index}->{$name};
			$field->set_property('input_cols', $cols->{$name});
		}
	}

	return $self;
}

# index the family part only...
sub get_sql_index
{
	my( $self ) = @_;

	return () unless( $self->get_property( "sql_index" ) );

	return ($self->get_name()."_family");
}

# fix undefined parts which causes uniqueness problems :-(
sub sql_row_from_value
{
	my( $self, $session, $value ) = @_;

	my @row = $self->SUPER::sql_row_from_value( $session, $value );

	for(@row)
	{
		$_ = "" if !defined $_;
	}

	return @row;
}

sub render_single_value
{
	my( $self, $session, $value ) = @_;

	my $order = $self->{render_order};
	
	# If the render opt "order" is set to "gf" then we order
	# the name with given name first. 

	return $session->render_name( 
			$value, 
			defined $order && $order eq "gf" );
}

sub get_input_bits
{
	my( $self ) = @_;

	my @namebits;
	unless( $self->get_property( "hide_honourific" ) )
	{
		push @namebits, "honourific";
	}
	if( $self->get_property( "family_first" ) )
	{
		push @namebits, "family", "given";
	}
	else
	{
		push @namebits, "given", "family";
	}
	unless( $self->get_property( "hide_lineage" ) )
	{
		push @namebits, "lineage";
	}

	return @namebits;
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $object ) = @_;

	my $grid_row = [];

	foreach my $alias ($self->get_input_bits)
	{
		my $field = $self->{fields_index}->{$alias};
		my $part_grid = $field->get_basic_input_elements( 
					$session, 
					$value->{$alias}, 
					$basename."_".$alias, 
					$staff, 
					$object );
		my $top_row = $part_grid->[0];
		push @{$grid_row}, @{$top_row};
	}

	return [ $grid_row ];
}

sub get_basic_input_ids
{
	my( $self, $session, $basename, $staff, $obj ) = @_;

	return map {
		join('_', $basename, $_)
	} $self->get_input_bits;
}

sub get_input_col_titles
{
	my( $self, $session, $staff ) = @_;

	my @r = ();
	foreach my $bit ( $self->get_input_bits() )
	{
		# deal with some legacy in the phrase id's
		$bit = "given_names" if( $bit eq "given" );
		$bit = "family_names" if( $bit eq "family" );
		push @r, $session->html_phrase(	"lib/metafield:".$bit );
	}
	return \@r;
}

sub split_search_value
{
	my( $self, $session, $value ) = @_;

	# should use archive whitespaces
	# remove spaces around commas to make them single names
	$value =~ s/\s*,\s*/,/g; 

	# things in double quotes are treated as a single name
	# eg. "Harris Smith" or "Smith, J K"
	my @bits = ();
	while( $value =~ s/"([^"]+)"// )
	{
		push @bits, $1;
	}

	# if there is anything left, split it on whitespace
	if( $value !~ m/^\s+$/ )
	{
		push @bits, split /\s+/ , $value;
	}
	return @bits;
}

sub render_search_value
{
        my( $self, $session, $value ) = @_;

	# bit of a hack but fixes the dodgey name rendering in RSS titles etc.
	# probably need to be removed when the code is rationalised.
	if( ref( $value ) eq "HASH" )
	{
		my $text = "\"".$value->{family}.", ".$value->{given}."\"";		
		return $session->make_text( $text );
	}

	my @bits = $self->split_search_value( $session, $value );
        return $session->make_text( '"'.join( '", "', @bits).'"' );
}

sub get_search_conditions
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

	if( $match eq "SET" )
	{
		return $self->SUPER::get_search_conditions( @_[1..$#_] );
	}

	if( $match eq "EX" )
	{
		# not correct yet. Only used for browse-by-name
		return EPrints::Search::Condition->new( 
			'name_match', 
			$dataset,
			$self, 
			$search_value );
	}

	my $v2 = EPrints::Index::apply_mapping( 
			$session,
			$search_value );

	my $indexmode = "index";

	if( $session->config( "match_start_of_name" ) )
	{
		$indexmode = "index_start";
	}

	# name searches are case sensitive
	$v2 = "\L$v2";

	if( $search_mode eq "simple" )
	{
		return EPrints::Search::Condition->new( 
			$indexmode,
			$dataset,
			$self, 
			$v2 );
	}


	# split up initials
	$v2 =~ s/([A-Z])/ $1/g;

	# remove not a-z characters (except , and ')
	$v2 =~ s/[^a-z,']/ /ig;

	my( $family, $given ) = split /\s*,\s*/, $v2;
	my @freetexts = ();
	foreach my $fpart ( split /\s+/, $family )
	{
		next unless EPrints::Utils::is_set( $fpart );
		push @freetexts, EPrints::Search::Condition->new( 
						$indexmode, 
						$dataset,
						$self, 
						$fpart );
	}

	
	# 2 family parts or one given part make it worth
	# doing the name crop. A single family part will 
	# obviously match.
	my $noskip = 0; 

	# grep only accepts "%" and "?" as special chars
	my $list = [ '%' ];
	foreach my $fpart ( split /\s+/, $family )
	{
		next unless EPrints::Utils::is_set( $fpart );
		if( $indexmode eq "index_start" )
		{
			$list->[0] .= '['.$fpart.'%';
		}
		else
		{
			$list->[0] .= '['.$fpart.']%';
		}
		++$noskip; # need at least 2 family parts to be worth cropping
	}

	$list->[0] .= '-%';
	$given = "" unless( defined $given );
	foreach my $gpart ( split /\s+/, $given )
	{
		next unless EPrints::Utils::is_set( $gpart );
		$noskip = 2;
		if( length $gpart == 1 )
		{
			# initial
			foreach my $l ( @{$list} )
			{
				$l .= '['.$gpart.'%';
			}
			next;
		}
		# a full given name
		my $nlist = [];
		foreach my $l ( @{$list} )
		{
			push @{$nlist}, $l.'['.$gpart.']%';
			$gpart =~ m/^(.)/;
			push @{$nlist}, $l.'['.$1.']%';
		}
		$list = $nlist;
	}

	if( $noskip >= 2 )
	{
		# it IS worth cropping 
		push @freetexts, EPrints::Search::Condition->new( 
						'grep', 
						$dataset,
						$self, 
						@{$list} );
	}

	return EPrints::Search::Condition->new( 'AND', @freetexts );
}

# INHERRITS get_search_conditions_not_ex, but it's not called.

sub get_search_group { return 'name'; } 

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{fields} = [
		{ sub_name => "family", type => "text", maxlength => 64, input_cols => 25, },
		{ sub_name => "given", type => "text", maxlength => 64, input_cols => 25, },
		{ sub_name => "lineage", type => "text", maxlength => 10, },
		{ sub_name => "honourific", type => "text", maxlength => 10, },
	];
	$defaults{input_name_cols} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{hide_honourific} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{hide_lineage} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{family_first} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{render_order} = "fg";
	$defaults{text_index} = 1;
	return %defaults;
}

my $x=<<END;
			Glaser	Hugh/Glaser	H/Glaser	Hugh B/Glaser	Hugh Bob/Glaser	Smith Glaser
H/Glaser		X	X		X						
H/Glaser-Smith		X	X		X						.
H/Smith-Glaser		X	X		X						X
Hugh/Glaser		X	X		X						
Hugh K/Glaser		X	X		X						
Hugh-Bob/Glaser		X	X		X		X		X		
Hugh Bob/Glaser		X	X		X		X		X		
Hugh B/Glaser		X	X		X		X		X	
Hugh Bill/Glaser	X	X		X		X		 	
H B/Glaser		X	X		X		X		X 	
HB/Glaser		X	X		X		X		X 	
H P/Glaser		X	X		X						
H/Smith											
Herbert/Glaser		X			X						
Herbert/Smith					X						
Q Hugh/Glaser		X	X								
Q H/Glaser		X									

			Glaser	Hugh/Glaser	H/Glaser	Hugh B/Glaser	Hugh Bob/Glaser	Smith Glaser
H/Glaser		X	X		X						
H/Glaser-Smith		X	X		X						X
H/Smith-Glaser		X	X		X						X
Hugh/Glaser		X	X		X						
Hugh K/Glaser		X	X		X						
Hugh-Bob/Glaser		X	X		X		X		X		
Hugh Bob/Glaser		X	X		X		X		X		
Hugh B/Glaser		X	X		X		X		X	
Hugh Bill/Glaser	X	X		X		X		 	
H B/Glaser		X	X		X		X		X 	
HB/Glaser		X	X		X		X		X 	
H P/Glaser		X	X		X						
H/Smith											
Herbert/Glaser		X			X						
Herbert/Smith					X						
Q Hugh/Glaser		X	X								
Q H/Glaser		X									

		
Smith Glaser		Whole word in family IS glaser AND Whole word in family IS smith 	

Glaser			Whole word in family IS glaser	

Hugh/Glaser		Glaser + (Whole word in given is Hugh OR first initial in given is "H")

H/Glaser		Glaser + (first initial in given is "H" OR first word in given starts with "H")

Hugh B/Glaser		Glaser + (first initial in given is "H" OR first word in given is "Hugh" ) +
				(second initial in given is "B" OR second word in given starts with "B")

Hugh Bob/Glaser		Glaser + (first initial in given is "H" OR first word in given is "Hugh" ) +
				(second iniital in given is "B" or second word in given is "Bob")

Names:


BQF
*B-*Q-*F-*

Ben Quantum Fierdash				[B][Q][Fierdash]
*(Ben|B)*(Quantum|Q)*(Fierdash|F)*
%[B]%[Q]%[F]%
%[B]%[Q]%[Fierdash]%
%[B]%[Quantum]%[F]%
%[B]%[Quantum]%[Fierdash]%
%[Ben]%[Q]%[F]%
%[Ben]%[Q]%[Fierdash]%
%[Ben]%[Quantum]%[F]%
%[Ben]%[Quantum]%[Fierdash]%

[Geddes][Harris]|[B][Q][Fierdash]

Ben F
*(Ben|B)*(F-)*

Ben
*(Ben|B)*

Quantum
*(Quantum|Q)*

Q
*(Q-)*



[John][Mike][H]-[Smith][Jones]

*[J*[M*-*[Jones]*

*[J]*-*[Smith]* AND *[John]*-*[Smith]*


END


sub get_index_codes_basic
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	my $f = &EPrints::Index::apply_mapping( $session, $value->{family} );
	my $g = &EPrints::Index::apply_mapping( $session, $value->{given} );

	# Add a space before all capitals to break
	# up initials. Will screw up names with capital
	# letters in the middle of words. But that's
	# pretty rare.
	$g =~ s/([[:upper:]])/ $1/g;

	my $code = '';
	my @r = ();
	foreach( EPrints::Index::split_words( $session, $f ) )
	{
		next if( $_ eq "" );
		push @r, "\L$_";
		$code.= "[\L$_]";
	}
	$code.= "-";
	foreach( EPrints::Index::split_words( $session, $g ) )
	{
		next if( $_ eq "" );
		push @r, "\L$_";
		$code.= "[\L$_]";
	}
	return( \@r, [$code], [] );
}	

# override Multipart
sub get_xml_schema_type
{
	my ($self) = @_;

	return $self->{type};
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	my $type = $session->make_element( "xs:complexType", name => $self->get_xml_schema_type );

	my $all = $session->make_element( "xs:all" );
	$type->appendChild( $all );
	foreach my $field (@{$self->{fields_cache}})
	{
		my $element = $session->make_element( "xs:element", name => $field->{sub_name}, minOccurs => 0 );
		$all->appendChild( $element );

		my $simpleType = $session->make_element( "xs:simpleType" );
		$element->appendChild( $simpleType );

		my $restriction = $session->make_element( "xs:restriction", base => "xs:string" );
		$simpleType->appendChild( $restriction );

		my $maxLength = $session->make_element( "xs:maxLength", value => $field->{maxlength} );
		$restriction->appendChild( $maxLength );
	}

	return $type;
}

######################################################################
1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

