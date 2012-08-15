=head1 NAME

EPrints::DataObj::CacheDataobjMap

=head1 DESCRIPTION

=head1 INSTANCE VARIABLES

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::CacheDataobjMap;

use base qw( EPrints::DataObj EPrints::List::Cache );

use strict;

=back

=head2 Class Methods

=over 4

=cut

=item $thing = EPrints::DataObj::CacheDataobjMap->get_system_field_info

Core fields.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"cache_dataobj_map_id", type=>"counter", required=>1, can_clone=>0,
			sql_counter=>"cache_dataobj_map_id" },

		# UNIX time this cache should be expired
		{ name=>"expires", type=>"bigint", required=>1, },

		# user who created this record
		{ name=>"userid", type=>"itemref", required=>0, datasetid => "user" },

		# serialised search expression
		{ name=>"searchexp", type=>"longtext", },

		# total matching records
		{ name=>"count", type=>"int", },

		# total records cached (from the start of the result set)
		{ name=>"available", type=>"int", },

		# dataset that actually stores the epdata
		{ name=>"dataobjs", type=>"subobject", datasetid=>"cache_dataobj", dataset_fieldname=>"", dataobj_fieldname=>"cache_dataobj_map_id", },
	);
}

=item $dataset = EPrints::DataObj::Import->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut

sub get_dataset_id
{
	return "cache_dataobj_map";
}

sub get_defaults
{
	my( $class, $repo, $data, $dataset ) = @_;

	$class->SUPER::get_defaults( $repo, $data, $dataset );

	my $cache_maxlife = $repo->config( "cache_maxlife" );

	$data->{expires} = time() + $cache_maxlife * 3600;

	return $data;
}

sub cleanup
{
	my( $class, $repo ) = @_;

	my $dataset = $repo->dataset( $class->get_dataset_id );

	my $expired_time = time();

	$dataset->search(filters => [
		{ meta_fields => [qw( expires )], value => "..$expired_time" }
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

	my $cache_maxlife = $self->repository->config( "cache_maxlife" );

	$self->set_value( "expires", time() + $cache_maxlife * 3600 );
	$self->commit;
}

sub remove
{
	my( $self ) = @_;

	my $repo = $self->{session};

	$repo->get_database->delete_from(
			$repo->dataset( "cache_dataobj" )->get_sql_table_name,
			["cache_dataobj_map_id"],
			[$self->id],
		);

	$self->SUPER::remove();
}

sub count { shift->value( "count" ) }

sub slice
{
	my( $self, $left, $count ) = @_;

	my $repo = $self->{session};

	my $value;
	if( defined $left && defined $count )
	{
		$value = ($left + 1)."..".($left + $count);
	}
	elsif( defined $left )
	{
		$value = ($left + 1)."..";
	}
	elsif( defined $count )
	{
		$value = "..$count";
	}

	my @dataobjs;

	my $dataset = $self->{session}->dataset( "cache_dataobj" );
	$dataset->search(filters => [
				{ meta_fields => ["cache_dataobj_map_id"], value => $self->id, },
				{ meta_fields => ["pos"], value => $value, match => "EQ", },
			],
			custom_order => "pos",
	)->map(sub {
		(undef, undef, my $cache) = @_;

		my $dataset = $repo->dataset( $cache->value( "datasetid" ) );
		push @dataobjs, $dataset->make_dataobj( $cache->value( "epdata" ) );
	});

	return @dataobjs;
}

sub cache {}
sub cache_id { shift->id }

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

