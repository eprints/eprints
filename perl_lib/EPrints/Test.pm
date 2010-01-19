######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
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

=item $repository = EPrints::Test::get_test_repository()

Returns the first repository object.

=cut

sub get_test_repository
{
	my $repoid = get_test_id();

	my $repository = EPrints::Repository->new( $repoid );

	return $repository;
}

=item $session = EPrints::Test::get_test_session( [ $noise ] )

Returns a session to the first repository.

=cut

sub get_test_session
{
	my( $noise ) = @_;

	my $repoid = get_test_id();

	$noise ||= 0;

	my $session = new EPrints::Session( 1 , $repoid , $noise );

	return $session;
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

=cut

sub get_test_dataobj
{
	my( $dataset ) = @_;

	my $results = $dataset->search( limit => 1 );

	return $results->item( 0 );
}

1;
