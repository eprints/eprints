######################################################################
#
# EPrints::DataObj::Cachemap
#
######################################################################
#
#
######################################################################


=head1 NAME

B<EPrints::DataObj::Cachemap> - cache tables

=head1 DESCRIPTION

This is an internal class that shouldn't be used outside L<EPrints::Database>.

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::Cachemap;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;

sub create_from_data
{
	my( $class, $repository, $data, $dataset ) = @_;

	# if we're online delay clean-up until Apache cleanup, which will prevent
	# the request blocking
	if( $repository->get_online )
	{
		$repository->get_request->pool->cleanup_register(sub {
				__PACKAGE__->cleanup( $repository )
			}, $repository );
	}
	else
	{
		$class->cleanup( $repository );
	}

	return $class->SUPER::create_from_data( $repository, $data, $dataset );
}

=item $thing = EPrints::DataObj::Access->get_system_field_info

Core fields.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"cachemapid", type=>"counter", required=>1, can_clone=>0,
			sql_counter=>"cachemapid" },

		{ name=>"created", type=>"int", required=>1, text_index=>0 },

		{ name=>"lastused", type=>"int", required=>0, text_index=>0 },

		{ name=>"userid", type=>"itemref", datasetid=>"user", required=>0, text_index=>0 },

		{ name=>"searchexp", type=>"longtext", required=>0, text_index=>0 },

		{ name=>"oneshot", type=>"boolean", required=>0, text_index=>0 },
	);
}

######################################################################

=back

=head2 Class Methods

=cut

######################################################################

######################################################################
=pod

=item $dataset = EPrints::DataObj::Cachemap->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "cachemap";
}

######################################################################

=item $defaults = EPrints::DataObj::Cachemap->get_defaults( $repository, $data )

Return default values for this object based on the starting data.

=cut

######################################################################

sub get_defaults
{
	my( $class, $repository, $data, $dataset ) = @_;
	
	$class->SUPER::get_defaults( $repository, $data, $dataset );

	$data->{created} = time();

	return $data;
}

=item $dropped = EPrints::DataObj::Cachemap->cleanup( $repository )

Clean up old caches. Returns the number of caches dropped.

=cut

sub cleanup
{
	my( $class, $repo ) = @_;

	my $dropped = 0;

	my $dataset = $repo->dataset( $class->get_dataset_id );
	my $cache_maxlife = $repo->config( "cache_maxlife" );
	my $cache_max = $repo->config( "cache_max" );

	my $expired_time = time() - $cache_maxlife * 3600;

	# cleanup expired cachemaps
	my $list = $dataset->search(
		filters => [
			{ meta_fields => [qw( created )], value => "..$expired_time" },
		] );
	$list->map( sub {
		my( undef, undef, $cachemap ) = @_;

		$dropped++ if $cachemap->remove();
	} );

	# enforce a limit on the maximum number of cachemaps to allow
	if( defined $cache_max && $cache_max > 0)
	{
		my $count = $repo->database->count_table( $dataset->get_sql_table_name );
		if( $count >= $cache_max )
		{
			my $list = $dataset->search(
				custom_order => "created", # oldest first
				limit => ($count - ($cache_max-1))
			);
			$list->map( sub {
				my( undef, undef, $cachemap ) = @_;

				if( $count-- >= $cache_max ) # LIMIT might fail!
				{
					$dropped++ if $cachemap->remove();
				}
			} );
		}
	}

	return $dropped;
}

######################################################################

=head2 Object Methods

=cut

######################################################################

=item $foo = $thing->remove()

Remove this record from the data set (see L<EPrints::Database>).

=cut

sub remove
{
	my( $self ) = @_;
	
	my $rc = 1;
	
	my $database = $self->{repository}->get_database;

	$rc &&= $database->remove(
		$self->{dataset},
		$self->get_id );

	my $table = $self->get_sql_table_name;

	# cachemap table might not exist
	$database->drop_table( $table );

	return $rc;
}

sub get_sql_table_name
{
	my( $self ) = @_;

	return "cache" . $self->get_id;
}

=item $ok = $cachemap->create_sql_table( $dataset )

Create the cachemap database table that can store ids from $dataset.

=cut

sub create_sql_table
{
	my( $self, $dataset ) = @_;

	my $cache_table = $self->get_sql_table_name;
	my $key_field = $dataset->get_key_field;
	my $database = $self->{repository}->get_database;

	my $rc = $database->_create_table( $cache_table, ["pos"], [
			$database->get_column_type( "pos", EPrints::Database::SQL_INTEGER, EPrints::Database::SQL_NOT_NULL ),
			$key_field->get_sql_type( $self->{repository} ),
			]);

	return $rc;
}

1;

__END__

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

