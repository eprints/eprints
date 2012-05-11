######################################################################
#
# EPrints::DataObj::Import
#
######################################################################
#
#
######################################################################


=head1 NAME

EPrints::DataObj::Import - caching import session

=head1 DESCRIPTION

Inherits from L<EPrints::DataObj::Cachemap>.

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

use base EPrints::DataObj;

use strict;

=back

=head2 Class Methods

=over 4

=cut

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

		{ name=>"datestamp", type=>"timestamp", required=>1, },

		{ name=>"userid", type=>"itemref", required=>0, datasetid => "user" },

		{ name=>"pluginid", type=>"id", },

		{ name=>"query", type=>"longtext", },

		{ name=>"count", type=>"int", },

		{ name=>"cache", type=>"subobject", datasetid=>"import_cache", dataset_fieldname=>"", dataobj_fieldname=>"importid", },
	);
}

=item $dataset = EPrints::DataObj::Import->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut

sub get_dataset_id
{
	return "import";
}

sub cleanup
{
	my( $class, $repo ) = @_;

	my $dataset = $repo->dataset( $class->get_dataset_id );

	my $cache_maxlife = $repo->config( "cache_maxlife" );

	my $expired_time = EPrints::Time::iso_datetime( time() - $cache_maxlife * 3600 );

	$dataset->search(filters => [
		{ meta_fields => [qw( datestamp )], value => "..$expired_time" }
	])->map(sub {
		$_[2]->remove();
	});
}

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	# if we're online delay clean-up until Apache cleanup, which will prevent
	# the request blocking
	if( $session->get_online )
	{
		$session->get_request->pool->cleanup_register(sub {
				__PACKAGE__->cleanup( $session )
			}, $session );
	}
	else
	{
		$class->cleanup( $session );
	}

	return $class->SUPER::create_from_data( $session, $data, $dataset );
}

######################################################################

=head2 Object Methods

=cut

######################################################################

sub touch
{
	my( $self ) = @_;

	$self->set_value( "datestamp", EPrints::Time::iso_datetime() );
	$self->commit;
}

sub remove
{
	my( $self ) = @_;

	my $repo = $self->{session};

	$self->{session}->get_database->delete_from(
			$self->{session}->dataset( "import_cache" )->get_sql_table_name,
			["importid"],
			[$self->id],
		);

	$self->SUPER::remove();
}

sub plugin
{
	my( $self, @params ) = @_;

	return $self->{session}->plugin( "Import::" . $self->value( "pluginid" ), @params );
}

sub count
{
	my( $self ) = @_;

	return $self->value( "count" );
}

sub item
{
	my( $self, $pos ) = @_;

	my $item = $self->{session}->dataset( "import_cache" )->search(filters => [
				{ meta_fields => ["importid"], value => $self->id, },
				{ meta_fields => ["pos"], value => $pos, },
			],
		)->item( 0 );
	return undef if !defined $item;

	my $dataset = $self->{session}->dataset( $item->value( "datasetid" ) );
	$item = $dataset->make_dataobj( $item->value( "epdata" ) );

	return $item;
}

*get_records = \&slice;
sub slice
{
	my( $self, $left, $count ) = @_;

	my $repo = $self->{session};

	$left ||= 0;

	my $right;
	if( !defined $count || $left + $count > $self->count )
	{
		$right = $self->count;
	}
	else
	{
		$right = $left + $count;
	}
	++$left;

	my $dataset = $self->{session}->dataset( "import_cache" );
	my @records = $dataset->search(filters => [
				{ meta_fields => ["importid"], value => $self->id, },
				{ meta_fields => ["pos"], value => "$left..$right", match => "EQ", },
			],
			custom_order => "pos",
		)->slice;

	return @records;
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

