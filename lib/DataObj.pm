######################################################################
#
# EPrints::Dataset 
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

B<EPrints::DataObj> - Base class for records in EPrints.

=head1 DESCRIPTION

This module is a base class which is inherited by EPrints::EPrint, 
EPrints::User, EPrints::Subject and EPrints::Document.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{data}
#     A reference to a hash containing the metadata of this
#     record.
#
#  $self->{session}
#     The current EPrints::Session
#
#  $self->{dataset}
#     The EPrints::DataSet to which this record belongs.
#
######################################################################

package EPrints::DataObj;
use strict;


######################################################################
=pod

=item $value = $dataobj->get_value( $fieldname, [$no_id] )

Get a the value of a metadata field. If the field is not set then it returns
undef unless the field has the property multiple set, in which case it returns 
[] (a reference to an empty array).

If $no_id is true and the field has an ID part then only the main part is
returned.

=cut
######################################################################

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


######################################################################
=pod

=item $dataobj->set_value( $fieldname, $value )

Set the value of the named metadata field in this record.

=cut 
######################################################################

sub set_value
{
	my( $self , $fieldname, $value ) = @_;

	$self->{data}->{$fieldname} = $value;
}


######################################################################
=pod

=item @values = $dataobj->get_values( $fieldnames )

Returns a list of all the values in this record of all the fields specified
by $fieldnames. $fieldnames should be in the format used by browse views - slash
seperated fieldnames with an optional .id suffix to indicate the id part rather
than the main part. 

For example "author.id/editor.id" would return a list of all author and editor
ids from this record.

=cut 
######################################################################

sub get_values
{
	my( $self, $fieldnames ) = @_;

	my %values = ();
	foreach my $fieldname ( split( "/" , $fieldnames ) )
	{
		my $field = EPrints::Utils::field_from_config_string( 
					$self->{dataset}, $fieldname );
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


######################################################################
=pod

=item $session = $dataobj->get_session

Returns the EPrints::Session object to which this record belongs.

=cut
######################################################################

sub get_session
{
	my( $self ) = @_;

	return $self->{session};
}


######################################################################
=pod

=item $data = $dataobj->get_data

Returns a reference to the hash table of all the metadata for this record keyed 
by fieldname.

=cut
######################################################################

sub get_data
{
	my( $self ) = @_;
	
	return $self->{data};
}


######################################################################
=pod

=item $dataset = $dataobj->get_dataset

Returns the EPrints::DataSet object to which this record belongs.

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;
	
	return $self->{dataset};
}


######################################################################
=pod 

=item $bool = $dataobj->is_set( $fieldname )

Returns true if the named field is set in this record, otherwise false.

=cut
######################################################################

sub is_set
{
	my( $self, $fieldname ) = @_;

	return EPrints::Utils::is_set( $self->{data}->{$fieldname} );
}


######################################################################
=pod

=item $id = $dataobj->get_id

Returns the value of the primary key of this record.

=cut
######################################################################

sub get_id
{
	my( $self ) = @_;

	my $keyfield = $self->{dataset}->get_key_field();

	return $self->{data}->{$keyfield->get_name()};
}

######################################################################
=pod


=item $xhtml = $dataobj->render_value( $fieldname, [$showall] )

Returns the rendered version of the value of the given field, as appropriate
for the current session. If $showall is true then all values are rendered - 
this is usually used for staff viewing data.

=cut
######################################################################

sub render_value
{
	my( $self, $fieldname, $showall ) = @_;

	my $field = $self->{dataset}->get_field( $fieldname );	
	
	return $field->render_value( $self->{session}, $self->get_value($fieldname), $showall );
}


######################################################################
=pod

=item $xhtml = $dataobj->render_citation( [$style], [$url] )

Renders the record as a citation. If $style is set then it uses that citation
style from the citations config file. Otherwise $style defaults to the type
of this record. If $url is set then the citiation will link to the specified
URL.

=cut
######################################################################

sub render_citation
{
	my( $self , $style , $url ) = @_;

	unless( defined $style )
	{
		$style=$self->get_type();
	}

	my $stylespec = $self->{session}->get_citation_spec(
					$self->{dataset},
					$style );

	EPrints::Utils::render_citation( $self , $stylespec , $url );
}


######################################################################
=pod

=item $xhtml = $dataobj->render_citation_link( [$style], [$staff] )

Renders a citation (as above) but as a link to the URL for this item. For
example - the abstract page of an eprint. If $staff is true then the 
citation links to the staff URL - which will provide more a full staff view 
of this record.

=cut
######################################################################

sub render_citation_link
{
	my( $self , $style , $staff ) = @_;

	my $url = $self->get_url( $staff );
	
	my $citation = $self->render_citation( $style, $url );

	return $citation;
}


######################################################################
=pod

=item $xhtml = $dataobj->render_description

Returns a short description of this object using the default citation style
for this dataset.

=cut
######################################################################

sub render_description
{
	my( $self ) = @_;

	my $stylespec = $self->{session}->get_citation_spec(
					$self->{dataset} );
				
	my $r =  EPrints::Utils::render_citation( $self , $stylespec );

	return $r;
}


######################################################################
=pod

=item $url = $dataobj->get_url( [$staff] )

Returns the URL for this record, for example the URL of the abstract page
of an eprint. If $staff is true then this returns the URL to the staff 
page for this item, which will show the full record and offer staff edit
options.

=cut
######################################################################

sub get_url
{
	my( $self , $staff ) = @_;

	return "EPrints::DataObj::get_url should have been over-ridden.";
}


######################################################################
=pod

=item $type = $dataobj->get_type

Returns the type of this record - type of user, type of eprint etc.

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;

	return "EPrints::DataObj::get_type should have been over-ridden.";
}

######################################################################
=pod

=back

=cut
######################################################################

# Things what could maybe go here maybe...

# commit 

# remove

# new

# new_from_data

# validate

# render

1; # for use success
