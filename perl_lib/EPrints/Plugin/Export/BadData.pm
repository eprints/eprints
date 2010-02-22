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
