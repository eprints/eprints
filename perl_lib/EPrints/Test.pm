######################################################################
#
#
######################################################################

=head1 NAME

EPrints::Test - Utility testing tools

=head1 METHODS

=head2 Class Methods

=over 4

=cut

package EPrints::Test;

use EPrints::Test::OnlineSession;

sub init
{
	my( $package ) = @_;

	print STDERR "$package enabled\n";
}

=item $repoid = EPrints::Test::get_test_id()

Returns the first repository id.

=cut

sub get_test_id
{
	my @ids = EPrints::Config::get_repository_ids();

	unless( @ids )
	{
		EPrints::abort "Requires at least one functioning repository";
	}

	return $ids[0];
}

=item $repository = EPrints::Test->repository()

Returns the first repository object.

=cut

sub repository
{
	&get_test_repository;
}
sub get_test_repository
{
	my $repoid = get_test_id();

	my $repository = EPrints::Repository->new( $repoid );

	return $repository;
}

=item $size = EPrints::Test::mem_increase( [ $previous ] )

Returns the change in memory size in bytes since it was $previous bytes. If $previous isn't given uses the memory size the last time mem_increase was called.

=cut

eval "use GTop";
my $MEM_PREVIOUS = 0;
if( $@ )
{
	*mem_increase = sub { -1 };
}
else
{
	*mem_increase = sub {
		$MEM_PREVIOUS = $_[0] if scalar(@_);

		my $diff = GTop->new->proc_mem( $$ )->resident - $MEM_PREVIOUS;

		$MEM_PREVIOUS += $diff;

		return $diff;
	};
}

=item $size = EPrints::Test::human_mem_increase( [ $previous ] )

Same as mem_increase but returns the memory size in human readable form.

=cut

sub human_mem_increase
{
	my $diff = &mem_increase;

	return EPrints::Utils::human_filesize( $diff );
}

=item $doc = EPrints::Test::get_test_document( $session )

Finds and returns the first document in the repository.

=cut

sub get_test_document
{
	my( $session ) = @_;

	my $db = $session->get_database;

	my $sth = $db->prepare_select(
		sprintf("SELECT %s FROM %s ORDER BY %s ASC",
			$db->quote_identifier( "docid" ),
			$db->quote_identifier( "document" ),
			$db->quote_identifier( "docid" )
		),
		limit => 1 );

	$sth->execute;

	my( $id ) = $sth->fetchrow_array;

	return unless defined $id;

	return EPrints::DataObj::Document->new( $session, $id );
}

=item EPrints::Test::get_test_dataobj( $dataset )

Returns the first object from the dataset $dataset.


sub get_test_dataobj
{
	my( $dataset ) = @_;

	my $results = $dataset->search( limit => 1 );

	return $results->item( 0 );
}
=cut

sub get_test_user
{
	my( $repo ) = @_;

	my $ds = $repo->dataset( 'user' );
	return undef if( !$ds );

	return $ds->make_dataobj( {
		username => "_test_user_",
		email => "test\@eprints.org",
		usertype => 'user',
	} );	
}

sub get_test_dataobj
{
	my( $self, $ds ) = @_;

	return $ds->make_dataobj( {
		text => "Bonjour tout le monde",
	} );
}

# creates a fake dataset...
sub get_test_dataset
{
	my( $repo ) = @_;


	my $ds = EPrints::DataSet->new(
			"repository" => $repo,
			"name" => "testds",
			"read-only" => 0,
			"revision" => 1,
			"history" => 0,
			"lastmod" => 1,
			"datestamp" => 1,
			"virtual" => 1,
			"flow" => {
				"default" => "state1",
				"states" => [qw/ state1 state2 state3 /],
				"transitions" => {
					"state1" => [qw/ state2 state3 /],
					"state2" => [qw/ state3 /],
					"state3" => [],
				},
			},
			"core_fields" => [
				{
					"name" => "text",
					"type" => "text",
				},
				{
					"name" => "integer",
					"type" => "int",
				},
				{
					"name" => "float",
					"type" => "float",
				},
				{
					"name" => "url",
					"type" => "url",
				},
				{
					"name" => "email",
					"type" => "email",
				},
				{
					"name" => "set",
					"type" => "set",
					"options" => [qw/ value1 value2 /],
				},
				{
					"name" => "boolean",
					"type" => "boolean",
				},
			],
	);

	return $ds;
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

