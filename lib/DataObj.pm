# cjg comment me

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

	return undef unless( EPrints::Utils::is_set( $r ) );

	return $r unless( $no_id );

	my $field = $self->{dataset}->get_field( $fieldname );

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




# Things what could go here maybe...

# commit 

# render_citation (_link)

# remove

# new

# new_from_data

# validate

# render

1; # for use success
