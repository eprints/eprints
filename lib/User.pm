######################################################################
#
# EPrints::User
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

B<EPrints::User> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

#####################################################################j
#
# EPrints User class module
#
#  This module represents a user in the system, and provides utility
#  methods for manipulating users' records.
#
######################################################################
#
#  __LICENSE__
#
######################################################################

##cjg _ verify password is NOT non-ascii!

package EPrints::User;
@ISA = ( 'EPrints::DataObj' );
use EPrints::DataObj;

use EPrints::Database;
use EPrints::MetaField;
use EPrints::Utils;
use EPrints::Subscription;

use strict;


######################################################################
=pod

=item $thing = EPrints::User->get_system_field_info

undocumented

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"userid", type=>"int", required=>1 },

		{ name=>"username", type=>"text", required=>1 },

		{ name=>"password", type=>"secret", 
			fromform=>\&EPrints::Utils::crypt_password },

		{ name=>"usertype", type=>"datatype", required=>1, 
			datasetid=>"user" },
	
		{ name=>"newemail", type=>"email" },
	
		{ name=>"newpassword", type=>"secret", 
			fromform=>\&EPrints::Utils::crypt_password },

		{ name=>"pin", type=>"text" },

		{ name=>"pinsettime", type=>"int" },

		{ name=>"joined", type=>"date", required=>1 },

		{ name=>"email", type=>"email", required=>1 },

		{ name=>"lang", type=>"datatype", required=>0, 
			datasetid=>"arclanguage", input_rows=>1 },

		{ name => "editperms", type => "search", 
			datasetid => "buffer",
			fieldnames => "editpermfields" },

		{ name=>"frequency", type=>"set", 
			options=>["never","daily","weekly","monthly"] },

		{ name=>"mailempty", type=>"boolean", input_style=>"radio" }
	)
};


######################################################################
#
# new( $session, $userid, $dbrow )
#
#  Construct a user object corresponding to the given userid.
#  If $dbrow is undefined, user info is read in from the database.
#  Pre-read data can be passed in (exactly as retrieved from the
#  database) into $dbrow.
#
######################################################################


######################################################################
=pod

=item $thing = EPrints::User->new( $session, $userid )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $session, $userid ) = @_;

	return $session->get_db()->get_single( 
		$session->get_archive()->get_dataset( "user" ),
		$userid );
}


######################################################################
=pod

=item $thing = EPrints::User->new_from_data( $session, $data )

undocumented

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data ) = @_;

	my $self = {};
	bless $self, $class;
	$self->{data} = $data;
	$self->{dataset} = $session->get_archive()->get_dataset( "user" );
	$self->{session} = $session;

	return( $self );
}




######################################################################
#
# $user = create_user( $session, $username_candidate, $email, $access_level )
#
#  Creates a new user with given access priviledges and a randomly
#  generated password.
#
######################################################################


######################################################################
=pod

=item EPrints::User::create_user( $session, $access_level )

undocumented

=cut
######################################################################

sub create_user
{
	my( $session, $access_level ) = @_;
	
	my $user_ds = $session->get_archive()->get_dataset( "user" );
	my $userid = _create_userid( $session );
		
	# And work out the date joined.
	my $date_joined = EPrints::Utils::get_datestamp( time );

	my $data = { 
		"userid"=>$userid,
		"usertype"=>$access_level,
		"joined"=>$date_joined 
	};

	$session->get_archive()->call(
		"set_user_defaults",
		$data,
		$session );

	
	# Add the user to the database...
	$session->get_db()->add_record( $user_ds, $data );
	
	# And return the new user as User object.
	return( EPrints::User->new( $session, $userid ) );
}


######################################################################
#
# $user = user_with_email( $session, $email )
#
#  Find the user with address $email. If no user exists, undef is
#  returned. [STATIC]
#
######################################################################


######################################################################
=pod

=item EPrints::User::user_with_email( $session, $email )

undocumented

=cut
######################################################################

sub user_with_email
{
	my( $session, $email ) = @_;
	
	my $user_ds = $session->get_archive()->get_dataset( "user" );

	my $searchexp = new EPrints::SearchExpression(
		session=>$session,
		dataset=>$user_ds );

	$searchexp->add_field(
		$user_ds->get_field( "email" ),
		$email );

	my $searchid = $searchexp->perform_search;
	my @records = $searchexp->get_records;
	$searchexp->dispose();
	
	return $records[0];
}


######################################################################
=pod

=item EPrints::User::user_with_username( $session, $username )

undocumented

=cut
######################################################################

sub user_with_username
{
	my( $session, $username ) = @_;
	
	my $user_ds = $session->get_archive()->get_dataset( "user" );

	my $searchexp = new EPrints::SearchExpression(
		session=>$session,
		dataset=>$user_ds );

	$searchexp->add_field(
		$user_ds->get_field( "username" ),
		$username );

	my $searchid = $searchexp->perform_search;

	my @records = $searchexp->get_records;
	$searchexp->dispose();
	
	return $records[0];
}


######################################################################
#
# $problems = validate()
#  array_ref
#
#  Validate the user - find out if all the required fields are filled
#  out, and that what's been filled in is OK. Returns an array of
#  problem descriptions.
#
######################################################################


######################################################################
=pod

=item $foo = $thing->validate

undocumented

=cut
######################################################################

sub validate
{
	my( $self ) = @_;

	my @all_problems;
	my $user_ds = $self->{session}->get_archive()->get_dataset( "user" );
	my @rfields = $user_ds->get_required_type_fields( $self->get_value( "usertype" ) );
	my @all_fields = $user_ds->get_fields();

	my $field;
	foreach $field ( @rfields )
	{
		# Check that the field is filled in if it is required
		if( !$self->is_set( $field->get_name() ) )
		{
			push @all_problems, 
			  $self->{session}->html_phrase( 
			   "lib/user:missed_field", 
			   field => $self->{session}->make_text( $field->display_name( $self->{session} ) ) );
		}
	}

	# Give the validation module a go
	foreach $field ( @all_fields )
	{
		push @all_problems, $self->{session}->get_archive()->call(
			"validate_field",
			$field,
			$self->get_value( $field->get_name() ),
			$self->{session},
			0 );
	}

	push @all_problems, $self->{session}->get_archive()->call(
			"validate_user",
			$self,
			$self->{session} );

	return( \@all_problems );
}


######################################################################
#
# $success = commit()
#
#  Update the database with any changes that have been made.
#
######################################################################


######################################################################
=pod

=item $foo = $thing->commit

undocumented

=cut
######################################################################

sub commit
{
	my( $self ) = @_;

	$self->{session}->get_archive()->call( 
		"set_user_automatic_fields", 
		$self );
	
	my $user_ds = $self->{session}->get_archive()->get_dataset( "user" );
	my $success = $self->{session}->get_db()->update(
		$user_ds,
		$self->{data} );

	return( $success );
}



######################################################################
#
# $success = remove()
#
#  Removes the user from the archive, together with their EPrints
#  and subscriptions.
#
######################################################################


######################################################################
=pod

=item $foo = $thing->remove

undocumented

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	my $success = 1;

	my $subscription;
	foreach $subscription ( $self->get_subscriptions() )
	{
		$subscription->remove();
	}

	# remove user record
	my $user_ds = $self->{session}->get_archive()->get_dataset( "user" );
	$success = $success && $self->{session}->get_db()->remove(
		$user_ds,
		$self->get_value( "userid" ) );
	
	return( $success );
}


######################################################################
=pod

=item $foo = $thing->has_priv( $resource )

undocumented

=cut
######################################################################

sub has_priv
{
	my( $self, $resource ) = @_;

	my $userprivs = $self->{session}->get_archive()->
		get_conf( "userauth", $self->get_value( "usertype" ), "priv" );

	foreach my $priv ( @{$userprivs} )
	{
		return 1 if( $priv eq $resource );
	}

	return 0;
}


######################################################################
=pod

=item $foo = $thing->get_eprints( $ds )

undocumented

=cut
######################################################################

sub get_eprints
{
	my( $self , $ds ) = @_;

	my $searchexp = new EPrints::SearchExpression(
		session=>$self->{session},
		dataset=>$ds );

	$searchexp->add_field(
		$ds->get_field( "userid" ),
		$self->get_value( "userid" ) );

#cjg set order (it's in the site config)

	my $searchid = $searchexp->perform_search;

	my @records = $searchexp->get_records;
	$searchexp->dispose();
	return @records;
}

# return eprints currently in the submission buffer for which this user is a 
# valid editor.
#cjg not done yet.

######################################################################
=pod

=item $foo = $thing->get_editable_eprints

undocumented

=cut
######################################################################

sub get_editable_eprints
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_archive()->get_dataset( "buffer" );

	my $searchexp = new EPrints::SearchExpression(
		session=>$self->{session},
		allow_blank=>1,
		custom_order=>"-datestamp",
		dataset=>$ds );

#	$searchexp->add_field(
#		$ds->get_field( "userid" ),
#		$self->get_value( "userid" ) );

#cjg set order (it's in the site config)

	my $searchid = $searchexp->perform_search;

	my @records =  $searchexp->get_records;
	$searchexp->dispose();
	return @records;
}

# This is subtley different from just getting all the
# eprints this user deposited. They may 'own' - be allowed
# to edit, request removal etc. of others, for example ones
# on which they are an author. Although this is a problem for
# the site admin, not the core code.

# cjg not done- where is it needed?

######################################################################
=pod

=item $foo = $thing->get_owned_eprints

undocumented

=cut
######################################################################

sub get_owned_eprints
{
	my( $self ) = @_;

	#cheap hack for now#cjg
	my $ds = $self->{session}->get_archive()->get_dataset( "archive" );	
	return $self->get_eprints( $ds );
}

# Is the given eprint in the set of eprints which would be returned by 
# get_owned_eprints?
# cjg not done
#cjg means can this user request removal, and submit later versions of this item?
# cjg could be ICK and just use get_owned_eprints...

######################################################################
=pod

=item $foo = $thing->is_owner( $eprint )

undocumented

=cut
######################################################################

sub is_owner
{
	my( $self, $eprint ) = @_;

	#cjg hack
	if( $eprint->get_value( "userid" ) eq $self->get_value( "userid" ) )
	{
		return 1;
	}
	return 0;
}



######################################################################
=pod

=item $foo = $thing->mail( $subjectid, $message, $replyto, $email )

undocumented

=cut
######################################################################

sub mail
{
	my( $self,   $subjectid, $message, $replyto,  $email ) = @_;
	#   User   , string,     DOM,      User/undef Other Email

	# Mail the admin in the default language
	my $langid = $self->get_value( "lang" );
	my $lang = $self->{session}->get_archive()->get_language( $langid );

	my $remail;
	my $rname;
	if( defined $replyto )
	{
		$remail = $replyto->get_value( "email" );
		$rname = EPrints::Utils::tree_to_utf8( $replyto->render_description() );
	}
	if( !defined $email )
	{
		$email = $self->get_value( "email" );
	}

	return EPrints::Utils::send_mail(
		$self->{session}->get_archive(),
		$langid,
		EPrints::Utils::tree_to_utf8( EPrints::Utils::render_name( $self->{session}, $self->get_value( "name" ), 1 ) ),
		$email,
		EPrints::Utils::tree_to_utf8( $lang->phrase( $subjectid, {}, $self->{session} ) ),
		$message,
		$lang->phrase( "mail_sig", {}, $self->{session} ),
		$remail,
		$rname ); 
}



######################################################################
# 
# EPrints::User::_create_userid( $session )
#
# undocumented
#
######################################################################

sub _create_userid
{
	my( $session ) = @_;
	
	my $new_id = $session->get_db()->counter_next( "userid" );

	return( $new_id );
}


######################################################################
=pod

=item $foo = $thing->render

undocumented

=cut
######################################################################

sub render
{
        my( $self ) = @_;

        my( $dom, $title ) = $self->{session}->get_archive()->call( "user_render", $self, $self->{session} );

	if( !defined $title )
	{
		$title = $self->render_description;
	}

        return( $dom, $title );
}

# This should include all the info, not just that presented to the public.

######################################################################
=pod

=item $foo = $thing->render_full

undocumented

=cut
######################################################################

sub render_full
{
        my( $self ) = @_;

        my( $dom, $title ) = $self->{session}->get_archive()->call( "user_render_full", $self, $self->{session} );

	if( !defined $title )
	{
		$title = $self->render_description;
	}

print STDERR "\nRF($dom)($title)\n";	
        return( $dom, $title );
}


######################################################################
=pod

=item $foo = $thing->get_url( $staff )

undocumented

=cut
######################################################################

sub get_url
{
	my( $self , $staff ) = @_;

	if( defined $staff && $staff )
	{
		return $self->{session}->get_archive()->get_conf( "perl_url" )."/users/staff/view_user?userid=".$self->get_value( "userid" );

	}

	return $self->{session}->get_archive()->get_conf( "perl_url" )."/user?userid=".$self->get_value( "userid" );
}


######################################################################
=pod

=item $foo = $thing->get_type

undocumented

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;

	return $self->get_value( "usertype" );
}


######################################################################
=pod

=item @subscriptions = $eprint->get_subscriptions

Return an array of all EPrint::Subscription objects associated with this
user.

=cut
######################################################################

sub get_subscriptions
{
	my( $self ) = @_;

	my $subs_ds = $self->{session}->get_archive()->get_dataset( 
		"subscription" );

	my $searchexp = EPrints::SearchExpression->new(
		session=>$self->{session},
		dataset=>$subs_ds,
		custom_order=>"subid" );

	$searchexp->add_field(
		$subs_ds->get_field( "userid" ),
		$self->get_value( "userid" ) );

	my $searchid = $searchexp->perform_search();
	my @subs = $searchexp->get_records();
	$searchexp->dispose();

	return( @subs );
}


1;

######################################################################
=pod

=back

=cut

