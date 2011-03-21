=head1 NAME

EPrints::Plugin::Export::BadData

=cut

package EPrints::Plugin::Export::BadData;

use EPrints::Plugin::Export::TextFile;
@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Bad data records";
	$self->{accept} = [ 'list/*' ];
	$self->{visible} = "staff";
	$self->{advertise} = 0;
	$self->{arguments}->{fixup} = 0;
	
	return $self;
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	my %fieldnames;

	foreach my $field ($dataobj->{dataset}->fields)
	{
		next if $field->is_virtual;
		next if !$dataobj->is_set( $field->name );
		my $value = $field->get_value( $dataobj );
		$value = [$value] if ref($value) ne "ARRAY";
		$value = EPrints::Utils::clone( $value );
		if( $field->isa( "EPrints::MetaField::Name" ) )
		{
			foreach my $v (@$value)
			{
				foreach my $part (values %$v)
				{
					if( $part =~ s/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]/\x{fffd}/g )
					{
						$fieldnames{$field->name} = 1;
					}
				}
			}
		}
		elsif( $field->isa( "EPrints::MetaField::Text" ) )
		{
			foreach my $v (@$value)
			{
				if( $v =~ s/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]/\x{fffd}/g )
				{
					$fieldnames{$field->name} = 1;
				}
			}
		}
		if( $fieldnames{$field->name} )
		{
			if( $field->get_property( "multiple" ) )
			{
				$field->set_value( $dataobj, $value );
			}
			else
			{
				$field->set_value( $dataobj, $value->[0] );
			}
		}
	}

	if( keys %fieldnames )
	{
		if( $opts{fixup} )
		{
			$dataobj->commit;
			return "+".$dataobj->id.": ".join(',',sort keys %fieldnames)."\n";
		}
		else
		{
			return $dataobj->id.": ".join(',',sort keys %fieldnames)."\n";
		}
	}

	return "";
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

