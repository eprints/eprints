=head1 NAME

EPrints::Plugin::Export::Grid

=cut

package EPrints::Plugin::Export::Grid;

use EPrints::Plugin::Export;
use Data::Dumper;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

$EPrints::Plugin::Import::DISABLE = 1;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Grid (abstract)";
	
	return $self;
}

sub header_row
{
	my( $plugin, %opts ) = @_;

	my $ds = $opts{list}->get_dataset;
	my $key_field = $ds->get_key_field();
	my @n = ( $key_field->get_name, "rowid" );
	foreach my $field ( $ds->get_fields )
	{
		next if $field->get_name eq $key_field->get_name;
		next if $field->is_type( "compound", "multilang", "subobject" );
		
		if( $field->is_type( "name" ) )
		{	
			foreach my $part ( qw/ family given honourific lineage / )
			{
				push @n, $field->get_name.".".$part;
			}
		}
		else
		{
			push @n, $field->get_name;
		}
	}

	return @n;
}

sub dataobj_to_rows
{
	my( $plugin, $dataobj ) = @_;

	my $ds = $dataobj->get_dataset;
	my $key_field = $ds->get_key_field();
	my $rows = [];
	my $col = 2;
	foreach my $field ( $ds->get_fields )
	{
		next if $field->get_name eq $key_field->get_name;
		next if $field->is_type( "compound", "multilang", "subobject" );

		my $v = $dataobj->get_value( $field->get_name );
		if( EPrints::Utils::is_set( $v ) )
		{
			$v = [$v] if( !$field->get_property( "multiple" ) );
		}
		else
		{
			$v = [];
		}

		my $i = 0;
		foreach my $single_value ( @{$v} )
		{
			if( $field->is_type( "name" ) )
			{	
				$rows->[$i]->[$col+0] = $single_value->{"family"};
				$rows->[$i]->[$col+1] = $single_value->{"given"};
				$rows->[$i]->[$col+2] = $single_value->{"honourific"};
				$rows->[$i]->[$col+3] = $single_value->{"lineage"};
			}
			else
			{
				$rows->[$i]->[$col] = $single_value;
			}
			$i += 1;
		}
		if( $field->is_type( "name" ) )
		{	
			$col += 4;
		}
		else
		{	
			$col += 1
		}
	}

	for( my $row_n=0;$row_n<scalar @{$rows};++$row_n  )
	{
		my $row = $rows->[$row_n];
		$row->[0] = $dataobj->get_value( $key_field->get_name );
		$row->[1] = $dataobj->get_value( $key_field->get_name )."_".$row_n;
	}

	return $rows;
}

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

