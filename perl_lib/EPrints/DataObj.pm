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

This module is a base class which is inherited by L<EPrints::DataObj::EPrint>,
L<EPrints::User>, L<EPrints::DataObj::Subject> and
L<EPrints::DataObj::Document> and several other classes.

It is ABSTRACT - its methods should not be called directly.

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

use MIME::Base64 ();

use strict;


######################################################################
=pod

=item $sys_fields = EPrints::DataObj->get_system_field_info

Return an array describing the system metadata of the this 
dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return ();
}

######################################################################
=pod

=item $dataobj = EPrints::DataObj->new( $session, $id [, $dataset] )

Return new data object, created by loading it from the database.

If $dataset is not defined uses the default dataset for this object.

=cut
######################################################################

sub new
{
	my( $class, $session, $id, $dataset ) = @_;

	if( !defined($dataset) )
	{
		$dataset = $session->get_repository->get_dataset( $class->get_dataset_id );
	}

	return $session->get_database->get_single( 
			$dataset,
			$id );
}

######################################################################
=pod

=item $dataobj = EPrints::DataObj->new_from_data( $session, $data [, $dataset ] )

Construct a new EPrints::DataObj object based on the $data hash 
reference of metadata.

Used to create an object from the data retrieved from the database.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $self = { data=>{}, changed=>{}, non_volatile_change=>0 };
	$self->{session} = $session;
	Scalar::Util::weaken($self->{session})
		if defined &Scalar::Util::weaken;
	if( defined( $dataset ) )
	{
		$self->{dataset} = $dataset;
	}
	else
	{
		$self->{dataset} = $session->get_repository->get_dataset( $class->get_dataset_id );
	}
	bless( $self, ref($class) || $class );

	if( defined $data )
	{
		if( $self->{dataset}->confid eq "eprint" )
		{
			$self->set_value( "eprint_status", $data->{"eprint_status"} );
		}
		foreach( keys %{$data} )
		{
			# this will cause an error if the field is unknown
			$self->set_value( $_, $data->{$_} );
		}
	}

	return( $self );
}

sub clone
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $clone = $self->create_from_data( $session, $self->get_data, $self->get_dataset );

	return $clone;
}

######################################################################
#=pod
#
#=item $dataobj = EPrints::DataObj::create( $session, @default_data )
#
#ABSTRACT.
#
#Create a new object of this type in the database. 
#
#The syntax for @default_data depends on the type of data object.
#
#=cut
#######################################################################

sub create
{
	my( $session, @default_data ) = @_;

	Carp::croak( "EPrints::DataObj::create must be overridden" );
}


######################################################################
#=pod
#
#=item $dataobj = EPrints::DataObj->create_from_data( $session, $data, $dataset )
#
#Create a new object of this type in the database. 
#
#$dataset is the dataset it will belong to. 
#
#$data is the data structured as with new_from_data.
#
#This will create sub objects also.
#
#Call this via $dataset->create_object( $session, $data )
#
#=cut
######################################################################

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	$data = EPrints::Utils::clone( $data );
	$dataset ||= $session->get_repository->get_dataset( $class->get_dataset_id );

	# If there is a field which indicates the virtual dataset,
	# set that now, so it's visible to get_defaults.
	my $ds_id_field = $dataset->get_dataset_id_field;
	if( defined $ds_id_field )
	{
		$data->{$ds_id_field} = $dataset->id;
	}

	# get defaults modifies the hash so we must copy it.
	my $defaults = EPrints::Utils::clone( $data );
	$defaults = $class->get_defaults( $session, $defaults, $dataset );
	
	# cache the configuration options in variables
	my $enable_import_ids = $session->get_repository->get_conf(
		"enable_import_ids"
		);
	my $enable_import_datestamps = $session->get_repository->get_conf(
		"enable_import_datestamps"
		);

	foreach my $field ( $dataset->get_fields )
	{
		next if $field->get_property( "import" );

		# This is a bit of a hack. The import script may set 
		# "enable_import_ids" on session This will allow eprintids 
		# and userids to be imported as-is rather than just being 
		# assigned one. 
		if( $enable_import_ids )
		{
			if( $dataset->confid eq "eprint" )
			{
				next if( $field->get_name eq "eprintid" );
			}
			if( $dataset->id eq "user" )
			{
				next if( $field->get_name eq "userid" );
			}
		}

		if( $enable_import_datestamps )
		{
			if( $dataset->confid eq "eprint" )
			{
				next if( $field->get_name eq "datestamp" );
			}
		}

		delete $data->{$field->get_name};
	}


	foreach my $k ( keys %{$defaults} )
	{
		next if defined $data->{$k};
		$data->{$k} = $defaults->{$k};
	}

	my $dataobj = $class->new_from_data( $session, $data, $dataset );
	return undef unless defined $dataobj;

	my $rc = $session->get_database->add_record( $dataset, $dataobj->get_data );
	return undef unless $rc;

	# queue all the fields for indexing.
	$dataobj->queue_all;

	return $dataobj;
}
                                                                                                                  

######################################################################
=pod

=item $defaults = EPrints::User->get_defaults( $session, $data, $dataset )

Return default values for this object based on the starting data.

Should be subclassed.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data, $dataset ) = @_;

	if( !defined $dataset )
	{
		$dataset = $session->get_repository->get_dataset( $class->get_dataset_id );
	}

	# set any values that a field has a default for e.g. counters
	foreach my $field ($dataset->get_fields)
	{
		next if defined $field->get_property( "sub_name" );

		my $value = $field->get_default_value( $session );
		next unless EPrints::Utils::is_set( $value );

		$data->{$field->get_name} = $value;
	}

	return $data;
}

######################################################################
=pod

=item $success = $dataobj->remove

Remove this data object from the database and any sub-objects or related files. 

Return true if successful.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;

	return $self->{session}->get_database->remove(
		$self->{dataset},
		$self->get_id );
}

# $dataobj->set_under_construction( $boolean )
#
# Set a flag to indicate this object is being constructed and 
# any house keeping will be handled by the method constructing it
# so don't do it elsewhere

sub set_under_construction
{
	my( $self, $boolean ) = @_;

	$self->{under_construction} = $boolean;
}

# $boolean = $dataobj->under_construction
# 
# True if this object is part way through being constructed.

sub under_construction
{
	my( $self ) = @_;

	return $self->{under_construction};
}

######################################################################
=pod

=item $dataobj->clear_changed( )

Clear any changed fields, which will result in them not being committed unless
force is used.

This method is used by the Database to avoid unnecessary commits.

=cut
######################################################################

sub clear_changed
{
	my( $self ) = @_;
	
	$self->{non_volatile_change} = 0;
	$self->{changed} = {};
}

######################################################################
=pod

=item $success = $dataobj->commit( [$force] )

Write this object to the database and reset the changed fields.

If $force isn't true then it only actually modifies the database
if one or more fields have been changed.

Commit may also queue indexer jobs or log changes, depending on the object.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;
	
	if( scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}

	# Remove empty slots in multiple fields
	$self->tidy;

	# Write the data to the database
	my $success = $self->{session}->get_database->update(
		$self->{dataset},
		$self->{data} );

	if( !$success )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{session}->get_repository->log( 
			"Error committing ".$self->get_dataset_id.".".
			$self->get_id.": ".$db_error );
		return 0;
	}

	# Queue changes for the indexer (if indexable)
	$self->queue_changes();

	# clear changed fields
	$self->clear_changed();

	return $success;
}




######################################################################
=pod

=item $value = $dataobj->get_value( $fieldname )

Get a the value of a metadata field. If the field is not set then it returns
undef unless the field has the property multiple set, in which case it returns 
[] (a reference to an empty array).

=cut
######################################################################

sub get_value
{
	my( $self, $fieldname ) = @_;
	
	my $field = EPrints::Utils::field_from_config_string( $self->{dataset}, $fieldname );

	if( !defined $field )
	{
		EPrints::abort( "Attempt to get value from not existant field: ".$self->{dataset}->id()."/$fieldname" );
	}

	my $r = $field->get_value( $self );

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

	return $r;
}

sub get_value_raw
{
	my( $self, $fieldname ) = @_;

	EPrints::abort( "\$fieldname undefined in get_value_raw" ) unless defined $fieldname;

	return $self->{data}->{$fieldname};
}

######################################################################
=pod

=item $dataobj->set_value( $fieldname, $value )

Set the value of the named metadata field in this record.

=cut 
######################################################################

sub set_value
{
	my( $self, $fieldname, $value ) = @_;

	if( !$self->{dataset}->has_field( $fieldname ) )
	{
		if( $self->{session}->get_noise > 0 )
		{
			$self->{session}->get_repository->log( "Attempt to set value on not existant field: ".$self->{dataset}->id()."/$fieldname" );
		}
		return;
	}
	my $field = $self->{dataset}->get_field( $fieldname );

	$field->set_value( $self, $value );
}

sub set_value_raw
{
	my( $self , $fieldname, $value ) = @_;

	if( !defined $self->{changed}->{$fieldname} )
	{
		# if it's already changed once then we don't
		# want to fiddle with it again

		if( !_equal( $self->{data}->{$fieldname}, $value ) )
		{
			$self->{changed}->{$fieldname} = $self->{data}->{$fieldname};
			my $field = $self->{dataset}->get_field( $fieldname );
			if( $field->get_property( "volatile" ) == 0 )
			{
				$self->{non_volatile_change} = 1;
			}
		}
	}

	$self->{data}->{$fieldname} = $value;
}

# internal function
# used to see if two data-structures are the same.

sub _equal
{
	my( $a, $b ) = @_;

	# both undef is equal
	if( !EPrints::Utils::is_set($a) && !EPrints::Utils::is_set($b) )
	{
		return 1;
	}

	# one xor other undef is not equal
	if( !EPrints::Utils::is_set($a) || !EPrints::Utils::is_set($b) )
	{
		return 0;
	}

	# simple value
	if( ref($a) eq "" )
	{
		return( $a eq $b );
	}

	if( ref($a) eq "ARRAY" )
	{
		# different lengths?
		return 0 if( scalar @{$a} != scalar @{$b} );
		for(my $i=0; $i<scalar @{$a}; ++$i )
		{
			return 0 unless _equal( $a->[$i], $b->[$i] );
		}
		return 1;
	}

	if( ref($a) eq "HASH" )
	{
		my @akeys = sort keys %{$a};
		my @bkeys = sort keys %{$b};

		# different sizes?
		# return 0 if( scalar @akeys != scalar @bkeys );
		# not testing as one might skip a value, the other define it as
		# undef.

		my %testk = ();
		foreach my $k ( @akeys, @bkeys ) { $testk{$k} = 1; }

		foreach my $k ( keys %testk )
		{	
			return 0 unless _equal( $a->{$k}, $b->{$k} );
		}
		return 1;
	}

	print STDERR "Warning: can't compare $a and $b\n";
	return 0;
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
				$values{$_} = 1;
			}
		}
		else
		{
			$values{$v} = 1
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

	# update compound fields

	foreach my $field ( $self->{dataset}->get_fields )
	{
		next unless $field->is_type( "compound", "multilang" );
		my $name = $field->get_name;
		$self->{data}->{$name} = $self->get_value( $name );
	}
	
	return $self->{data};
}

######################################################################
=pod

=item $dataset = EPrints::DataObj->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	my( $class ) = @_;

	Carp::croak( "get_dataset_id must be overridden by $class" );
}


######################################################################
=pod

=item $dataset = $dataobj->get_dataset

Returns the L<EPrints::DataSet> object to which this record belongs.

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

Warns if the field does not exist.

=cut
######################################################################

sub is_set
{
	my( $self, $fieldname ) = @_;

	if( !$self->{dataset}->has_field( $fieldname ) )
	{
		$self->{session}->get_repository->log(
			 "is_set( $fieldname ): Unknown field" );
	}

	my $value = $self->get_value( $fieldname );

	return EPrints::Utils::is_set( $value );
}

######################################################################
=pod 

=item $bool = $dataobj->exists_and_set( $fieldname )

Returns true if the named field is set in this record, otherwise false.

If the field does not exist, just return false.

This method is useful for plugins which may operate on multiple 
repositories, and the fact a field does not exist is not an issue.

=cut
######################################################################

sub exists_and_set
{
	my( $self, $fieldname ) = @_;

	if( !$self->{dataset}->has_field( $fieldname ) )
	{	
		return 0;
	}

	return $self->is_set( $fieldname );
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

=item $id = $dataobj->get_gid

DEPRECATED (see uri())

Returns the globally referential fully-qualified identifier for this object or
undef if this object can not be externally referenced.

=cut
######################################################################

sub get_gid
{
	my( $self ) = @_;

	return $self->uri;
}

=item $datestamp = $dataobj->get_datestamp

Returns the datestamp of this object in "YYYY-MM-DD hh:mm:ss" format.

=cut

sub get_datestamp
{
	my( $self ) = @_;

	my $dataset = $self->get_dataset;

	my $field = $dataset->get_datestamp_field;
	return unless $field;

	return $field->get_value( $self );
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
	
	return $field->render_value( $self->{session}, $self->get_value($fieldname), $showall, undef,$self );
}


######################################################################
=pod

=item $xhtml = $dataobj->render_citation( [$style], [%params] )

Renders the record as a citation. If $style is set then it uses that citation
style from the citations config file. Otherwise $style defaults to the type
of this record. If $params{url} is set then the citiation will link to the specified
URL.

=cut
######################################################################

sub render_citation
{
	my( $self , $style , %params ) = @_;

	unless( defined $style )
	{
		$style = 'default';
	}

	my $stylespec = $self->{session}->get_citation_spec(
					$self->{dataset},
					$style );

	return EPrints::Utils::render_citation( $stylespec, 
			item=>$self, 
			in=>"citation ".$self->{dataset}->confid."/".$style, 
			session=>$self->{session},
			%params );
}


######################################################################
=pod

=item $xhtml = $dataobj->render_citation_link( [$style], %params )

Renders a citation (as above) but as a link to the URL for this item. For
example - the abstract page of an eprint. 

=cut
######################################################################

sub render_citation_link
{
	my( $self , $style , %params ) = @_;

	$params{url} = $self->get_url;
	
	return $self->render_citation( $style, %params );
}

sub render_citation_link_staff
{
	my( $self , $style , %params ) = @_;

	$params{url} = $self->get_control_url;
	
	return $self->render_citation( $style, %params );
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
	my( $self, %params ) = @_;

	return $self->render_citation( "brief", %params );
}

######################################################################
=pod

=item ($xhtml, $title ) = $dataobj->render

Return a chunk of XHTML DOM describing this object in the normal way.
This is the public view of the record, not the staff view.

=cut
######################################################################

sub render
{
	my( $self ) = @_;

	return( $self->render_description, $self->render_description );
}

######################################################################
=pod

=item ($xhtml, $title ) = $dataobj->render_full

Return an XHTML table in DOM describing this record. All values of
all fields are listed. This is the staff view.

=cut
######################################################################

sub render_full
{
	my( $self ) = @_;

	my $unspec_fields = $self->{session}->make_doc_fragment;
	my $unspec_first = 1;

	# Show all the fields
	my $table = $self->{session}->make_element( "table",
					border=>"0",
					cellpadding=>"3" );

	my @fields = $self->get_dataset->get_fields;
	foreach my $field ( @fields )
	{
		next unless( $field->get_property( "show_in_html" ) );
		next if( $field->is_type( "subobject" ) );

		my $name = $field->get_name();
		if( $self->is_set( $name ) )
		{
			$table->appendChild( $self->{session}->render_row(
				$field->render_name( $self->{session} ),	
				$self->render_value( $field->get_name(), 1 ) ) );
			next;
		}

		# unspecified value, add it to the list
		if( $unspec_first )
		{
			$unspec_first = 0;
		}
		else
		{
			$unspec_fields->appendChild( 
				$self->{session}->make_text( ", " ) );
		}
		$unspec_fields->appendChild( 
			$field->render_name( $self->{session} ) );


	}

	$table->appendChild( $self->{session}->render_row(
			$self->{session}->html_phrase( "lib/dataobj:unspecified" ),
			$unspec_fields ) );

	return $table;
}




######################################################################
=pod

=item $url = $dataobj->uri

Returns a unique URI for this object. Not certain to resolve as a 
URL.

If $c->{dataobj_uri}->{eprint} is a function, call that to work it out.

=cut
######################################################################

sub uri
{
	my( $self ) = @_;

	my $ds_id = $self->get_dataset->confid;
	if( $self->get_session->get_repository->can_call( "dataobj_uri", $ds_id ) )
	{
		return $self->get_session->get_repository->call( [ "dataobj_uri", $ds_id ], $self );
	}
			
	return $self->get_session->get_repository->get_conf( "base_url" ).$self->internal_uri;
}

=item $uri = $dataobj->internal_uri()

Return an internal URI for this object (independent of repository hostname).

To retrieve an object by internal URI use L<EPrints::DataSet>::get_object_from_uri().

=cut

sub internal_uri
{
	my( $self ) = @_;

	return sprintf("/id/%s/%s",
		URI::Escape::uri_escape($self->get_dataset_id),
		URI::Escape::uri_escape($self->get_id)
		);
}

######################################################################
=pod

=item $url = $dataobj->get_url

Returns the URL for this record, for example the URL of the abstract page
of an eprint.

=cut
######################################################################

sub get_url
{
	my( $self ) = @_;

	return;
}

######################################################################
=pod

=item $url = $dataobj->get_control_url

Returns the URL for the control page for this object. 

=cut
######################################################################

sub get_control_url
{
	my( $self , $staff ) = @_;

	return "EPrints::DataObj::get_control_url should have been over-ridden.";
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

=item $xmlfragment = $dataobj->to_xml( %opts )

Convert this object into an XML fragment. 

%opts are:

no_xmlns=>1 : do not include a xmlns attribute in the 
outer element. (This assumes this chunk appears in a larger tree 
where the xmlns is already set correctly.

showempty=>1 : fields with no value are shown.

version=>"code" : pick what version of the EPrints XML format
to use "1" or "2"

embed=>1 : include the data of a file, not just it's URL.

=cut
######################################################################

sub to_xml
{
	my( $self, %opts ) = @_;

	$opts{version} = "2" unless defined $opts{version};

	my %attrs = ();
	my $ns = EPrints::XML::namespace( 'data', $opts{version} );
	if( !defined $ns )
	{
		$self->{session}->get_repository->log(
			 "to_xml: unknown version: ".$opts{version} );
		#error
		return;
	}

	if( !$opts{no_xmlns} )
	{
		$attrs{'xmlns'} = $ns;
	}
	$opts{no_xmlns} = 1;

	my $tl = "record";
	if( $opts{version} == 2 ) { 
		$tl = $self->{dataset}->confid; 
		$attrs{'id'} = $self->uri;
	}	
	my $r = $self->{session}->make_element( $tl, %attrs );
	$r->appendChild( $self->{session}->make_text( "\n" ) );
	foreach my $field ( $self->{dataset}->get_fields() )
	{
		next unless( $field->get_property( "export_as_xml" ) );

		if( $opts{version} eq "2" )
		{
			$r->appendChild( $field->to_xml( 
				$self->{session}, 
				$self->get_value( $field->get_name() ),
				$self->{dataset},
				%opts ) );
		}
		if( $opts{version} eq "1" )
		{
			unless( $opts{show_empty} )
			{
				next unless( $self->is_set( $field->get_name() ) );
			}

			$r->appendChild( $field->to_xml_old( 
				$self->{session}, 
				$self->get_value( $field->get_name() ),
				2 ) ); # no xmlns on inner elements
		}
	}

	return $r;
}

=item $epdata = EPrints::DataObj->xml_to_epdata( $session, $xml, %opts )

Populates $epdata based on $xml. This is the inverse of to_xml() but doesn't create a new object.

=cut

sub xml_to_epdata
{
	my( $class, $session, $xml, %opts ) = @_;

	my $epdata = {};

	my $dataset = $session->get_repository->get_dataset( $class->get_dataset_id );

	my @fields = $dataset->get_fields;
	my @field_names = sort { $a cmp $b } map { $_->get_name } @fields;
	my %fields_map = map { $_->get_name => $_ } @fields;

	my %seen = ();
	foreach my $node ($xml->childNodes)
	{
		next unless EPrints::XML::is_dom( $node, "Element" );
		my $nodeName = $node->nodeName;
		if( $seen{$nodeName} )
		{
			if( defined $opts{Handler} )
			{
				$opts{Handler}->message( "warning", $session->phrase( "Plugin/Import/XML:dup_element", name => $session->make_text( $nodeName ) ) );
			}
			next;
		}
		$seen{$nodeName} = 1;
		my $field = $fields_map{$nodeName};
		if( !defined $field )
		{
			if( defined $opts{Handler} )
			{
				$opts{Handler}->message( "warning", $session->html_phrase( "Plugin/Import/XML:unexpected_element", name => $session->make_text( $nodeName ) ) );
				$opts{Handler}->message( "warning", $session->html_phrase( "Plugin/Import/XML:expected", elements => $session->make_text( "<".join("> <", @field_names).">" ) ) );
			}
			next;
		}
		my $value = $field->xml_to_epdata( $session, $node, %opts );
		if( EPrints::Utils::is_set( $value ) )
		{
			$epdata->{$nodeName} = $value;
		}
	}

	return $epdata;
}

######################################################################
=pod

=item $plugin_output = $detaobj->export( $plugin_id, %params )

Apply an output plugin to this items. Return the results.

=cut
######################################################################

sub export
{
	my( $self, $out_plugin_id, %params ) = @_;

	my $plugin_id = "Export::".$out_plugin_id;
	my $plugin = $self->{session}->plugin( $plugin_id );

	unless( defined $plugin )
	{
		EPrints::abort( "Could not find plugin $plugin_id" );
	}

	my $req_plugin_type = "dataobj/".$self->{dataset}->confid;

	unless( $plugin->can_accept( $req_plugin_type ) )
	{
		EPrints::abort( 
"Plugin $plugin_id can't process $req_plugin_type data." );
	}
	
	
	return $plugin->output_dataobj( $self, %params );
}

######################################################################
=pod

=item $dataobj->queue_changes

Add all the changed fields into the indexers todo queue.

=cut
######################################################################

sub queue_changes
{
	my( $self ) = @_;

	return unless $self->{dataset}->indexable;

	my @fields;

	foreach my $fieldname ( keys %{$self->{changed}} )
	{
		my $field = $self->{dataset}->get_field( $fieldname );

		next unless( $field->get_property( "text_index" ) );

		push @fields, $fieldname;
	}	

	return unless scalar @fields;

	my $event_queue = $self->{session}->get_repository->get_dataset( "event_queue" );

	$event_queue->create_object( $self->{session}, {
			pluginid => "Indexer",
			action => "index",
			params => [$self->internal_uri, @fields],
		});
}

######################################################################
=pod

=item $dataobj->queue_all

Add all the fields into the indexers todo queue.

=cut
######################################################################

sub queue_all
{
	my( $self ) = @_;

	return unless $self->{dataset}->indexable;

	my $event_queue = $self->{session}->get_repository->get_dataset( "event_queue" );

	$event_queue->create_object( $self->{session}, {
			pluginid => "Indexer",
			action => "index_all",
			params => [$self->internal_uri],
		});
}

######################################################################
=pod

=item $dataobj->queue_fulltext

Add a fulltext index into the indexers todo queue.

=cut
######################################################################

sub queue_fulltext
{
	my( $self ) = @_;

	return unless $self->{dataset}->indexable;

	my $event_queue = $self->{session}->get_repository->get_dataset( "event_queue" );

	$event_queue->create_object( $self->{session}, {
			pluginid => "Indexer",
			action => "index_fulltext",
			params => [$self->internal_uri],
		});
}

######################################################################
=pod

=item $boolean = $dataobj->has_owner( $user )

Return true if $user owns this record. Normally this means they 
created it, but a group of users could count as owners of the same
record if you wanted.

It's false on most dataobjs, except those which override this method.

=cut
######################################################################

sub has_owner
{
	my( $self, $user ) = @_;

	return 0;
}

######################################################################
=pod

=item $boolean = $dataobj->in_editorial_scope_of( $user )

As for has_owner, but if the user is identified as someone with an
editorial scope which includes this record.

Defaults to true. Which doesn't mean that they have the right to 
edit it, just that their scope matches. You also need editor rights
to use this. It's currently used just to filter eprint editors so
that only ones with a scope AND a priv can edit.

=cut
######################################################################

sub in_editorial_scope_of
{
	my( $self, $user ) = @_;

	return 1;
}

=item $problems = $dataobj->validate( [ $for_archive ], $workflow_id )

Return a reference to an array of XHTML DOM objects describing
validation problems with the entire $dataobj based on $workflow_id.

If $workflow_id is undefined defaults to "default".

A reference to an empty array indicates no problems.

=cut

sub validate { [] }

=item $warnings = $dataobj->get_warnings( )

Return a reference to an array of XHTML DOM objects describing
problems with the entire $dataobj.

A reference to an empty array indicates no problems.

=cut

sub get_warnings { [] }

# check if a field is valid. Return an array of XHTML problems.

sub validate_field
{
	my( $self, $fieldname ) = @_;

	my $field = $self->{dataset}->get_field( $fieldname );
	
	return $field->validate( $self->{session}, $self->get_value( $fieldname ), $self );
}


# Clean up any multiple fields with gaps in.
sub tidy
{
	my( $self ) = @_;

	foreach my $field ( $self->{dataset}->get_fields )
	{
		next unless $field->get_property( "multiple" );
		
		# squash compound fields as one.
		next if( $field->get_property( "parent_name" ) );
		my @list = ();
		my $set = 0;
		foreach my $item ( @{$self->get_value($field->get_name)} )
		{
			if( !EPrints::Utils::is_set( $item ) )
			{
				$set = 1;
				next;
			}
			push @list, $item;
		}

		# set if there was a blank line
		if( $set )
		{
			$self->set_value( $field->get_name, \@list );
		}

		# directly add this to the data if it's a compound field
		# this is so that the ordervalues code can see it.
		if( $field->isa( "EPrints::MetaField::Compound" ) )
		{
			$self->{data}->{$field->get_name} = \@list;	
		}
	}
}

######################################################################
=pod

=item $file = $dataobj->add_stored_file( $filename, $filehandle [, $filesize ] )

Convenience method to add the file record for $filename to this object. Reads data from $filehandle. If $filesize is defined it may used to determine where the file should be stored.

Returns the file object or undef if the storage failed.

=cut
######################################################################

sub add_stored_file
{
	my( $self, $filename, $filehandle, $filesize ) = @_;

	my $file = $self->get_stored_file( $filename );

	if( defined($file) )
	{
		$file->remove();
	}

	$file = EPrints::DataObj::File->create_from_data( $self->{session}, {
		_parent => $self,
		_content => $filehandle,
		filename => $filename,
		filesize => $filesize,
	}, $self->{session}->get_repository->get_dataset( "file" ) );

	return $file;
}

######################################################################
=pod

=item $file = $dataobj->get_stored_file( $filename )

Get the file object for $filename.

Returns the file object or undef if the file doesn't exist.

=cut
######################################################################

sub get_stored_file
{
	my( $self, $filename ) = @_;

	my $file = EPrints::DataObj::File->new_from_filename(
		$self->{session},
		$self,
		$filename
	);

	if( defined $file )
	{
		$file->set_parent( $self );
	}

	return $file;
}

=head2 Related Objects

=item $dataobj->add_object_relations( $target, $has => $is [, $has => $is ] )

Add a relation between this object and $target of type $has. If $is is defined will also add the reciprocal relationship $is from $target to this object. May be repeated to add multiple relationships.

You must commit $target after calling this method.

=cut

sub add_object_relations
{
	my( $self, $target, %relations ) = @_;

	my $uri = $target->internal_uri;

	my @types = grep { defined $_ } keys %relations;

	my $relations = $self->get_value( "relation" );
	push @$relations, map { {
		type => $_,
		uri => $uri,
	} } @types;
	$self->set_value( "relation", $relations );

	my @reciprocal = grep { defined $_ } values %relations;
	if( scalar @reciprocal )
	{
		$target->add_object_relations( $self, map { $_ => undef } @reciprocal );
	}
}

sub _get_related_uris
{
	my( $self, @required ) = @_;

	my $relations = $self->get_value( "relation" );

	# create a look-up table
	my %haystack;
	foreach my $relation (@$relations)
	{
		next unless defined $relation->{"uri"};
		next unless defined $relation->{"type"};
		$haystack{$relation->{"uri"}}->{$relation->{"type"}} = undef;
	}

	# remove any relations that don't satisfy our @required types
	foreach my $type (@required)
	{
		foreach my $uri (keys %haystack)
		{
			if( !exists( $haystack{$uri}->{$type} ) )
			{
				delete $haystack{$uri};
			}
		}
	}

	return keys %haystack;
}

=item $bool = $dataobj->has_object_relations( $target, @types )

Returns true if this object is related to $target by all @types.

If @types is empty will return true if any relationships exist.

=cut

sub has_object_relations
{
	my( $self, $target, @required ) = @_;

	my $match = $target->internal_uri;

	my @uris = $self->_get_related_uris( @required );

	foreach my $uri (@uris)
	{
		if( $uri eq $match )
		{
			return 1;
		}
	}

	return 0;
}

=item $bool = $dataobj->has_related_objects( @types )

Returns true if get_related_objects() would return some objects, but without actually retrieving the related objects from the database.

=cut

sub has_related_objects
{
	my( $self, @required ) = @_;

	my @uris = $self->_get_related_uris( @required );

	return scalar @uris > 0;
}

=item $dataobjs = $dataobj->get_related_objects( @types )

Returns a list of objects related to this object by @types.

=cut

sub get_related_objects
{
	my( $self, @required ) = @_;

	my @uris = $self->_get_related_uris( @required );

	# Translate matching uris into real objects
	my @matches;
	foreach my $uri (@uris)
	{
		my $dataobj = EPrints::DataSet->get_object_from_uri( $self->{session}, $uri );
		next unless defined $dataobj;

		if(
			$dataobj->isa( "EPrints::DataObj::SubObject" ) &&
			$dataobj->get_parent_dataset_id eq $self->get_parent_dataset_id &&
			$dataobj->get_parent_id eq $self->get_parent_id
		  )
		{
			$dataobj->set_parent( $self->get_parent );
		}

		push @matches, $dataobj;
	}

	return \@matches;
}

=item $dataobj->remove_object_relations( $target [, $has => $is [, $has => $is ] )

Remove relations between this object and $target. If $has => $is pairs are defined will only remove those relationships given.

You must commit $target after calling this method.

=cut

sub remove_object_relations
{
	my( $self, $target, %relations ) = @_;

	my $uri = $target->internal_uri;

	my @relations;
	foreach my $relation (@{($self->get_value( "relation" ))})
	{
		# doesn't match $target
		if( $relation->{"uri"} ne $uri )
		{
			push @relations, $relation;
		}
		# we're removing specific relations, and this one isn't given
		elsif( scalar(%relations) && !exists($relations{$relation->{"type"}}) )
		{
			push @relations, $relation;
		}
	}
	$self->set_value( "relation", \@relations );

	my @reciprocal = grep { defined $_ } values %relations;
	if( scalar @reciprocal )
	{
		$target->remove_object_relations( $self, map { $_ => undef } @reciprocal );
	}
}

######################################################################
=pod

=back

=cut
######################################################################

1; # for use success
