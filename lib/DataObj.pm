######################################################################
#
# EPrints Dataset Object Root Class
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

package EPrints::DataObj;

use strict;

# Properties which we assume that all subclasses will set:
#  $self->{data}
#  $self->{session}
#  $self->{dataset}

sub get_value
{
	my( $self, $fieldname, $no_id ) = @_;
	
	my $r = $self->{data}->{$fieldname};

	my $field = $self->{dataset}->get_field( $fieldname );

	if( !defined $field )
	{
		EPrints::Config::abort( "Attempt to get value from not existant field: ".$self->{dataset}->id()."/$fieldname" );
	}

	unless( EPrints::Utils::is_set( $r ) )
	{
		if( $field->get_property( "multiple" ) )
		{
			return [];
		}
		else
		{
			return undef;
		}
	}

	return $r unless( $no_id );

	return $r unless( $field->get_property( "hasid" ) );

	# Ok, we need to strip out the {id} parts. It's easy if
	# this isn't multiple
	return $r->{main} unless( $field->get_property( "multiple" ) );

	# It's a multiple field, then. Strip the ids from each.
	my $r2 = [];
	foreach( @$r ) { push @{$r2}, $_->{main}; }
	return $r2;
}

sub set_value
{
	my( $self , $fieldname, $value ) = @_;

	$self->{data}->{$fieldname} = $value;
}


# return all values of this
# allows config style fieldnames eg author.id/editor.id
sub get_values
{
	my( $self, $fieldnames ) = @_;

	my %values = ();
	foreach my $fieldname ( split( "/" , $fieldnames ) )
	{
		my $field = EPrints::Utils::field_from_config_string( $self->{dataset}, $fieldname );
		my $v = $self->{data}->{$field->get_name()};
		if( $field->get_property( "multiple" ) )
		{
			foreach( @{$v} )
			{
				$values{$field->which_bit( $_ )} = 1;
			}
		}
		else
		{
			$values{$field->which_bit( $v )} = 1;
		}
	}

	return keys %values;
}


sub get_session
{
	my( $self ) = @_;

	return $self->{session};
}

sub get_data
{
	my( $self ) = @_;
	
	return $self->{data};
}

sub get_dataset
{
	my( $self ) = @_;
	
	return $self->{dataset};
}

sub is_set
{
	my( $self, $fieldname ) = @_;

	return EPrints::Utils::is_set( $self->{data}->{$fieldname} );
}

sub get_id
{
	my( $self ) = @_;

	my $keyfield = $self->{dataset}->get_key_field();

	return $self->{data}->{$keyfield->get_name()};
}

sub render_value
{
	my( $self, $fieldname, $showall ) = @_;

	my $field = $self->{dataset}->get_field( $fieldname );	
	
	return $field->render_value( $self->{session}, $self->get_value($fieldname), $showall );
}

sub render_citation
{
	my( $self , $cstyle , $url ) = @_;

	unless( defined $cstyle )
	{
		$cstyle=$self->get_type();
	}

	my $stylespec = $self->{session}->get_citation_spec(
					$self->{dataset},
					$cstyle );

	EPrints::Utils::render_citation( $self , $stylespec , $url );
}

sub render_citation_link
{
	my( $self , $cstyle , $staff ) = @_;

	my $url = $self->get_url( $staff );
	
	my $citation = $self->render_citation( $cstyle, $url );

	return $citation;
}


sub render_description
{
	my( $self ) = @_;


	my $stylespec = $self->{session}->get_citation_spec(
					$self->{dataset} );
				
	return EPrints::Utils::render_citation( $self , $stylespec );
}

sub get_url
{
	my( $self , $staff ) = @_;

	return "EPrints::DataObj::get_url should have been over-ridden.";
}

sub get_type
{
	my( $self , $staff ) = @_;

	return "EPrints::DataObj::get_type should have been over-ridden.";
}


# Things what could maybe go here maybe...

# commit 

# remove

# new

# new_from_data

# validate

# render

sub DESTROY
{
	my( $self ) = @_;

	EPrints::Utils::destroy( $self );
}

1; # for use success
