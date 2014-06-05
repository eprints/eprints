######################################################################
#
# EPrints::DataObj::Import
#
######################################################################
#
#
######################################################################


=head1 NAME

B<EPrints::DataObj::Import> - bulk imports logging

=head1 DESCRIPTION

Inherits from L<EPrints::DataObj>.

=head1 INSTANCE VARIABLES

=over 4

=item $obj->{ "data" }

=item $obj->{ "dataset" }

=item $obj->{ "session" }

=back

=head1 CORE FIELDS

=over 4

=item importid

Unique id for the import.

=item datestamp

Time import record was created.

=item userid

Id of the user responsible for causing the import.

=item source_repository

Source entity from which this import came.

=item url

Location of the imported content (e.g. the file name).

=item description

Human-readable description of the import.

=item last_run

Time the import was last started.

=item last_success

Time the import was last successfully completed.

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::Import;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;

=item $thing = EPrints::DataObj::Import->get_system_field_info

Core fields contained in a Web import.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"importid", type=>"counter", required=>1, can_clone=>0,
			sql_counter=>"importid" },

		{ name=>"userid", type=>"itemref", required=>0, datasetid => "user" },

		{ name=>"source_repository", type=>"text", required=>0, },

		{ name=>"url", type=>"longtext", required=>0, },

		{ name=>"description", type=>"longtext", required=>0, },

		{ name=>"last_run", type=>"time", required=>0, },

		{ name=>"last_success", type=>"time", required=>0, },

#sf2
		# total number of items available in that import
		{ name => "total", type => "int" },

		# number of dataobjs created so far
		{ name => "created", type => "int" },
		# status.. or could this be a flow? looks a lot like an eventqueue dataobj?
		{ name => "status", type => "set", options => [qw/ waiting inprogress failed completed /] }

	);
}

######################################################################

=back

=head2 Class Methods

=cut

######################################################################
=pod

=item $dataset = EPrints::DataObj::Import->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "import";
}

######################################################################

=head2 Object Methods

=cut

######################################################################

=item $list = $import->run( $processor )

Run this bulk import. Returns a list of EPrints created. $processor is used for reporting errors.

=cut

sub run
{
	my( $self, $processor ) = @_;

	$self->set_value( "last_run", EPrints::Time::get_iso_timestamp() );
	$self->commit();

	my $session = $self->{session};

	my $url = $self->get_value( "url" );

	if( !EPrints::Utils::is_set( $url ) )
	{
		$processor->add_message( "error", $session->make_text( "Can't run import that doesn't contain a URL" ) );
		return;
	}

	my $file = File::Temp->new;

	my $ua = LWP::UserAgent->new;
	my $r = $ua->get( $url, ":content_file" => "$file" );

	if( !$r->is_success )
	{
		my $err = $session->make_doc_fragment;
		$err->appendChild( $session->make_text( "Error requesting " ) );
		$err->appendChild( $session->render_link( $url ) );
		$err->appendChild( $session->make_text( ": ".$r->status_line ) );
		$processor->add_message( "error", $err );
		return;
	}

	my $plugin = EPrints::DataObj::Import::XML->new(
			session => $session,
			import => $self,
		);

	my $list = $plugin->input_file(
			filename => "$file",
			dataset => $session->dataset( "eprint" ),
		);

	$self->set_value( "last_success", EPrints::Time::get_iso_timestamp() );
	$self->commit();

	return $list;
}

=item $import->map( $fn, $info )

Maps the function $fn onto every eprint in this import.

=cut

sub map
{
	my( $self, $fn, $info ) = @_;

	my $list = $self->get_list();

	$list->map($fn, $info );

	$list->dispose;
}

=item $import->clear()

Clear the contents of this bulk import.

=cut

sub clear
{
	my( $self ) = @_;

	$self->map(sub {
		my( $session, $dataset, $eprint ) = @_;

		$eprint->remove();
	});
}

=item $list = $import->get_list()

Returns a list of the items in this import.

=cut

sub get_list
{
	my( $self ) = @_;

	my $dataset = $self->{session}->get_repository->get_dataset( "eprint" );

	my $searchexp = EPrints::Search->new(
		session => $self->{session},
		dataset => $dataset,
	);

	$searchexp->add_field( $dataset->get_field( "importid" ), $self->get_id );

	my $list = $searchexp->perform_search;

	$searchexp->dispose;

	return $list;
}

=item $eprint = $import->get_from_source( $sourceid )

Get the $eprint that is from this import set and identified by $sourceid.

=cut

sub get_from_source
{
	my( $self, $sourceid ) = @_;

	return undef if !defined $sourceid;

	my $dataset = $self->{session}->dataset( "eprint" );

	my $results = $dataset->search(
		filters => [
			{
				meta_fields => [qw( importid )], value => $self->id,
			},
			{
				meta_fields => [qw( source )], value => $sourceid,
			}
		]);

	return $results->item( 0 );
}

=item $dataobj = $import->epdata_to_dataobj( $dataset, $epdata )

Convert $epdata to a $dataobj. If an existing object exists in this import that has the same identifier that object will be used instead of creating a new object.

Also calls "set_eprint_import_automatic_fields" on the object before writing it to the database.

=cut

# hack to make import work with oversized field values
sub _cleanup_data
{
	my( $self, $field, $value ) = @_;

	if( EPrints::Utils::is_set($value) && $field->isa( "EPrints::MetaField::Text" ) )
	{
		if( $field->get_property( "multiple" ) )
		{
			for(@$value)
			{
				$_ = substr($_,0,$field->get_property( "maxlength" ));
			}
		}
		else
		{
			$value = substr($value,0,$field->get_property( "maxlength"));
		}
	}

	return $value;
}

sub epdata_to_dataobj
{
	my( $self, $dataset, $imdata ) = @_;

	my $epdata = {};

	my $keyfield = $dataset->get_key_field();

	foreach my $fieldname (keys %$imdata)
	{
		next if $fieldname eq $keyfield->get_name();
		next if $fieldname eq "rev_number";
		my $field = $dataset->get_field( $fieldname );
		next if $field->get_property( "volatile" );
		next unless $field->get_property( "import" ); # includes datestamp

		my $value = $self->_cleanup_data( $field, $imdata->{$fieldname} );
		$epdata->{$fieldname} = $value;
	}

	# the source is the eprintid
	$epdata->{"source"} = $imdata->{$keyfield->get_name()};

	# importid will always be us
	$epdata->{"importid"} = $self->get_id();

	# any objects created by this import must be owned by our owner
	$epdata->{"userid"} = $self->get_value( "userid" );

	my $dataobj = $self->get_from_source( $epdata->{"source"} );

	if( defined $dataobj )
	{
		foreach my $fieldname (keys %$epdata)
		{
			$dataobj->set_value( $fieldname, $epdata->{$fieldname} );
		}
	}
	else
	{
		$dataobj = $dataset->create_object( $self->{session}, $epdata );
	}

	return undef unless defined $dataobj;

	$self->update_triggers();

	$dataobj->commit();

	return $dataobj;
}

1;

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut


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

