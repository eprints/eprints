package EPrints::DataObj::OAuth;

@ISA = qw( EPrints::DataObj );

use strict;

sub get_dataset_id { "oauth" }

sub get_system_field_info
{
	my( $self ) = @_;

	return (
		{ name => "oauthid", type => "counter", sql_counter => "oauthid" },
		{ name => "expires", type => "int", sql_index => 1 },
		{ name => "userid", type => "itemref", datasetid => "user",
			sql_index => 1 },
		{ name => "service", type => "id", sql_index => 1 },
		{ name => "oauth_token", type => "id", sql_index => 0 },
		{ name => "oauth_request_secret", type => "id", sql_index => 0 },
		{ name => "oauth_token_secret", type => "id", sql_index => 0 },
	);
}

sub new_by_service_userid
{
	my( $class, $repo, $service, $userid ) = @_;

	return $repo->dataset( $class->get_dataset_id )->search(filters => [
		{ meta_fields => [qw( service )], value => $service },
		{ meta_fields => [qw( userid )], value => $userid, },
	])->item( 0 );
}

=item EPrints::DataObj::OAuth->cleanup()

=cut

sub cleanup
{
	my( $class, $repo ) = @_;

	my $now = time();

	$repo->dataset( $class->get_dataset_id )->search(
		filters => [{ meta_fields => [qw( expires )], value => "-$now" }]
	)->map(sub { $_[2]->remove });
}


1;
