=head1 NAME

EPrints::Plugin::Export::Grid

=cut

package EPrints::Plugin::Export::Grid;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

$EPrints::Plugin::Import::DISABLE = 1;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Grid (abstract)";
	$self->{accept} = [ 'dataobj/*', 'list/*', ];
	$self->{visible} = "none";	
	$self->{advertise} = 0;	
	return $self;
}

sub fields
{
	my( $self, $dataset ) = @_;

	# skip compound, subobjects
	return grep { !$_->is_virtual } $dataset->fields;
}

sub header_row
{
	my( $self, %opts ) = @_;

	my $fields = $opts{fields} ||= [$self->fields($opts{list}->{dataset})];

	my @names;
	foreach my $field (@$fields)
	{
		if ($field->isa("EPrints::MetaField::Multipart"))
		{
			my $name = $field->name;
			push @names, map {
					$name . '.' . $_->{sub_name}
				} @{$field->property("fields_cache")};
		}
		else
		{
			push @names, $field->name;
		}
	}

	return @names;
}

sub output_dataobj
{
        my( $plugin, $dataobj ) = @_;	

	# this has to be sub classed in order to be a valid export plugin but is unused

	return;
}

sub dataobj_to_rows
{
	my( $self, $dataobj, %opts ) = @_;

	my $fields = $opts{fields} || [$self->fields($dataobj->{dataset})];

	my @rows = ([]);
	foreach my $field (@$fields)
	{
		my $i = @{$rows[0]};

		my $_rows = $self->value_to_rows($field, $field->get_value( $dataobj ));
		foreach my $j (0..$#$_rows)
		{
			foreach my $_i (0..$#{$_rows->[$j]})
			{
				$rows[$j][$i+$_i] = $_rows->[$j][$_i];
			}
		}
	}

	# generate complete rows
	for(@rows) {
		$_->[0] = $rows[0][0];
		$_->[$#{$rows[0]}] ||= undef;
	}

	return \@rows;
}

sub value_to_rows
{
	my ($self, $field, $value) = @_;

	my @rows;

	if (ref($value) eq "ARRAY")
	{
		$value = [$field->empty_value] if !@$value;
		@rows = map { $self->value_to_rows($field, $_)->[0] } @$value;
	}
	elsif ($field->isa("EPrints::MetaField::Multipart"))
	{
		push @rows, [map { $value->{$_->{sub_name}} } @{$field->property("fields_cache")}];
	}
	else
	{
		push @rows, [$value];
	}

	return \@rows;
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

