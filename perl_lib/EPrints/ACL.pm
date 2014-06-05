package EPrints::ACL;

use strict;
use EPrints;

# A collection of util methods to manage privilege mapping/check etc


# generates a list of privs from a given action
sub privs_from_action
{
	my( $action, $dataset, $dataobj, $user ) = @_;

	return [] if( !defined $action );

	my @privs;

	my @ds_scopes = ( $dataset->id );
	
	# image:owner/edit, image:inbox/edit
	my @contexts = @{ $dataset->user_contexts( $dataobj ) };
	foreach my $ctx ( @contexts )
	{
		push @ds_scopes, sprintf "%s:%s", $dataset->id, $ctx;
	}

	if( !$dataset->is_stateless && defined ( my $status = $dataset->state ) )
	{
		push @ds_scopes, sprintf "%s.%s", $dataset->id, $status ;
		foreach my $ctx ( @contexts )
		{
			push @ds_scopes, sprintf "%s.%s:%s", $dataset->id, $status, $ctx;
		}
	}		

	foreach my $priv ( "*", $action )
	{
		foreach my $scope ( @ds_scopes )
		{
			push @privs, sprintf "%s/%s", $scope, $priv;
		}
	}

	if( defined $dataobj )
	{
		# e.g. 'image/destroy/123' (can user destroy image 123?)
		push @privs, sprintf "%s/%s/%s", $dataset->id, $action, $dataobj->id;
		if( !$dataobj->is_stateless && defined ( my $status = $dataobj->state ) )
		{
			# e.g. 'image.inbox/destroy/123'
			push @privs, sprintf "%s.%s/%s", $dataset->id, $status, $action;
		}
	}

	# reversing the array may seem weird but if you look above, the first privs are the "wider" ones (image/*) which
	# only a few users (admins usually) will likely have.
	# so it makes sense to start with the "narrower" privs (image.live/view) that user (or "public") are more likely to have
	# this allows to, on average, do fewer "if" tests
	@privs = reverse @privs;
	return \@privs;
}

1;
