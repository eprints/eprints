######################################################################
#
# User Roles
#
#  Here you can configure which different types of user are 
#  parts of the system they are allowed to use.
#
######################################################################

# Use this to set public privilages. 
$c->define_role( 'public-general', [qw{
	+subject/rest/get
        +subject/view
        +subject/export
}] );

$c->define_role( 'admin-user', [qw{
	+user/*
}] );

# from Repository::$PUBLIC_PRIVS
#$c->define_role( 'legacy_hardcoded_public_roles'. [qw{
#        +eprint_search
#        +eprint/archive/view
#        +eprint/archive/export
#        +saved_search/public_saved_search/export
#        +saved_search/public_saved_search/view
#}] );

$c->add_public_roles( 'public-general' );

$c->define_role( 'user-general', [qw{
	+user/view:owner
	+user/edit:owner
	+user:own-record/edit
}] );

$c->define_role( 'acl-create', [qw{
	+acl/create
}] );

$c->define_role( 'admin-acl', [qw{
	+acl/*
}] );

$c->{roles_by_user} = sub {
	
	my $user = $_[0] or return;

	my @roles;
	if( $user->value( 'usertype' ) eq 'user' )
	{
		push @roles, qw[ general ];
	}
	elsif( $user->value( 'usertype' ) eq 'admin' )
	{
		push @roles, qw[ general admin-acl ];
	}

	# an example
	#if( $user->value( 'username' ) eq 'admin' )
	#{
	#	push @roles, qw[ acl-create admin-image admin-ui admin-user ];
	#}

	return \@roles;
};

# also possible:
# $c->add_public_privs( 'priv1', ... );

