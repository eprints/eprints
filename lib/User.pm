#####################################################################j
#
# EPrints User class module
#
#  This module represents a user in the system, and provides utility
#  methods for manipulating users' records.
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

package EPrints::User;

use EPrints::Database;
use EPrints::MetaField;
use EPrints::Mailer;
use EPrints::Subscription;

use strict;

## WP1: BAD
sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"username", type=>"text", required=>1, editable=>0 },

		{ name=>"passwd", type=>"text", required=>1, editable=>0 },

		{ name=>"usertype", type=>"datatype", required=>1, editable=>0, datasetid=>"user" },

		{ name=>"joined", type=>"date", required=>1, editable=>0 },

		{ name=>"email", type=>"email", required=>1, editable=>1 } 
	);
};


######################################################################
#
# new( $session, $username, $dbrow )
#
#  Construct a user object corresponding to the given username.
#  If $dbrow is undefined, user info is read in from the database.
#  Pre-read data can be passed in (exactly as retrieved from the
#  database) into $dbrow.
#
######################################################################

## WP1: BAD
sub new
{
	my( $class, $session, $username, $known ) = @_;

	if( !defined $known )
	{
		return $session->get_db()->get_single( 
			$session->get_archive()->get_data_set( "user" ),
			$username );
	} 

	my $self = {};
	bless $self, $class;
	$self->{data} = $known;
	$self->{session} = $session;

	return( $self );
}

######################################################################
#
# $user = create_user_email( $session, $email, $access_level )
#
#  Creates a new user with the given email address. A username is
#  automatically generated from the email address.
#
######################################################################

## WP1: BAD
sub create_user_email
{
	my( $session, $email, $access_level ) = @_;
	
	# Work out the username by removing the domain. Hopefully this will
	# give the user their home system's username that they're used to.
	my $username = $email;
	$username =~ s/\@.*//;

	if( $username eq "" )
	{
		# Fail! Not a valid email address...
		return( undef );
	}
	
	return( EPrints::User::create_user( $session,
	                                    $username,
	                                    $email,
	                                    $access_level ) );
}


######################################################################
#
# $user = create_user( $session, $username_candidate, $email, $access_level )
#
#  Creates a new user with given access priviledges and a randomly
#  generated password.
#
######################################################################

## WP1: BAD
sub create_user
{
	my( $session, $username_candidate, $email, $access_level ) = @_;
	
	my $found = 0;
	my $used_count = 0;
	my $candidate = $username_candidate;

	my $user_ds = $session->get_archive()->get_data_set( "user" );
		
	while( $found==0 )
	{
		#print "Trying $candidate\n";
	
		if( $session->get_db()->exists( $user_ds, $candidate ) )
		{
			# Already exists. Try again...
			$used_count++;
			$candidate = $username_candidate . $used_count;
		}
		else
		{
			# Doesn't exist, we've found it.
			$found = 1;
		}
	}

	# Now we have a new user name. Generate a password for it.
	my $passwd = _generate_password( 6 );

	# And work out the date joined.
	my $date_joined = EPrints::MetaField::get_datestamp( time );

	# Add the user to the database... e-mail add. is lowercased
# cjg add_record call
	$session->{database}->add_record( $user_ds,
	                                  { "username"=>$candidate,
	                                    "passwd"=>$passwd,
	                                    "usertype"=>$access_level,
	                                    "joined"=>$date_joined,
	                                    "email"=>lc $email } );
	
	# And return the new user as User object.
	return( EPrints::User->new( $session, $candidate ) );
}


######################################################################
#
#  $password = _generate_password( $length )
#
#   Generates a random password $length characters long.
#
######################################################################

## WP1: BAD
sub _generate_password
{
	my( $length ) = @_;
	
	# Seed the random number generator
	srand;
	# no l's (mdh 1/7/98)
	my $enc="0123456789abcdefghijkmnopqrstuvwxyz";
	# now for the associated password
	my $passwd = "";

	my $i;
	for ($i = 0; $i < $length ;$i++)
	{
		$passwd .= substr($enc,int(rand(35)),1);
	}

	return( $passwd );
}


######################################################################
#
# $user = user_with_email( $session, $email )
#
#  Find the user with address $email. If no user exists, undef is
#  returned. [STATIC]
#
######################################################################

## WP1: BAD
sub user_with_email
{
	my( $session, $email ) = @_;
	
	my $user_ds = $session->get_archive()->get_data_set( "user" );
	# Find out which user it is
	my @row = $session->{database}->retrieve_single(
		$user_ds,
		"email",
		lc $email );

	if( $#row >= 0 )
	{
		# Found the user
		return( new EPrints::User( $session, $row[0] ) );
	}
	else
	{
		return( undef );
	}
}


######################################################################
#
# $fullname = full_name()
#   str
#
#  Returns the user's full name
#
######################################################################

## WP1: BAD
sub full_name
{
	my( $self ) = @_;

	# Delegate to site-specific routine
	return( $self->{session}->get_archive()->call(
			"user_display_name",
			$self ) );
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

## WP1: GOOD
sub validate
{
	my( $self ) = @_;

	my @all_problems;
	my @all_fields = $self->{session}->
		get_archive()->get_data_set( "user" )->get_fields();

	my $field;
	foreach $field ( @all_fields )
	{
		# Check that the field is filled in if it is required
		if( $field->get_property( "required" ) && 
		    !$self->is_set( $field->get_name() ) )
		{
			push @all_problems, 
			  $self->{session}->phrase( 
			   "lib/user:missed_field", 
			   field => $field->display_name( $self->{session} ) );
		}
		else
		{
			# Give the validation module a go
			my $problem = $self->{session}->get_archive()->call(
				"validate_user_field",
				$field,
				$self->get_value( $field->get_name() ),
				$self->{session} );

			if( defined $problem && $problem ne "" )
			{
				push @all_problems, $problem;
			}
		}
	}

	return( \@all_problems );
}


######################################################################
#
# $success = commit()
#
#  Update the database with any changes that have been made.
#
######################################################################

## WP1: BAD
sub commit
{
	my( $self ) = @_;
	
	my $user_ds = $self->{session}->get_archive()->get_data_set( "user" );
	my $success = $self->{session}->{database}->update(
		$user_ds,
		$self->{data} );

	return( $success );
}



######################################################################
#
# $success = send_introduction()
#  bool
#
#  Send an email to the user, introducing them to the archive and
#  giving them their username and password.
#
######################################################################

## WP1: BAD
sub send_introduction
{
	my( $self ) = @_;

	my $subj;
	if ( $self->{usertype} eq "staff" )
	{
		$subj = "lib/user:new_staff";
	}
	else
	{
		$subj = "lib/user:new_user";
	}
	# Try and send the mail
	return( EPrints::Mailer::prepare_send_mail(
		$self->{session},
		$self->{session}->phrase( $subj , sitename=>$self->{session}->get_archive()->get_conf( "sitename" ) ),
		$self->{email},
		$self->{session}->phrase( "lib/user:welcome", 
		                          sitename=>$self->{session}->get_archive()->get_conf( "sitename" ) ),
		$self->{session}->get_archive()->get_conf( "template_user_intro" ),
		$self ) );
}


######################################################################
#
# $success = send_reminder( $message )
#
#  Sends the user a reminder of their username and password, with the
#  given message. The message passed in should just be a line or two
#  of explanation, or can be left blank.
#
######################################################################

## WP1: BAD
sub send_reminder
{
	my( $self, $message ) = @_;
	
	my $full_message = $self->{session}->phrase(
	     	"lib/user:reminder",
		 sitename=>$self->{session}->get_archive()->get_conf( "sitename" ),
	     	 message=>( defined $message ? "$message\n\n" : "" ),
		 username=>$self->{username},
		 password=>$self->{passwd},
		 adminemail=>$self->{session}->get_archive()->get_conf( "admin" )  );

	return( EPrints::Mailer::send_mail( 
			$self->{session},
			$self->full_name(),
	                $self->{email},
	                $self->{session}->phrase( "lib/user:reminder_sub" ),
	                $full_message ) );
}

######################################################################
#
# @users = retrieve_users( $session, $conditions, $order )
#
#  Retrieves users from the database, returning User objects. [STATIC]
#
######################################################################

## WP1: BAD
sub retrieve_users
{
	my( $session, $conditions, $order ) = @_;
	
	my @fields = $session->{metainfo}->get_fields( "user" );

	my $user_ds = $session->get_archive()->get_data_set( "user" );
	my $rows = $session->{database}->retrieve_fields(
		$user_ds,
		\@fields,
		$conditions,
		$order );


	my $r;
	my @users;

	foreach $r (@$rows)
	{
		push @users, new EPrints::User( $session,
		                                $r->[0],
		                                $r );
	}
	
	return( @users );		                                        
}


######################################################################
#
# $success = remove()
#
#  Removes the user from the archive, together with their EPrints
#  and subscriptions.
#
######################################################################

## WP1: BAD
sub remove
{
	my( $self ) = @_;
	
	my $success = 1;

	# First, remove their EPrints
	my @eprints = EPrints::EPrint::retrieve_eprints(
		$self->{session},
		EPrints::Database::table_name( "archive" ),
		[ "username LIKE \"$self->{username}\"" ] );

	foreach (@eprints)
	{
		$success = $success && $_->remove();
	}

	# And subscriptions
	my @subs = EPrints::Subscription::subscriptions_for(
		$self->{session},
		$self );
	
	foreach (@subs)
	{
		$success = $success && $_->remove();
	}

	# Now remove user record
	my $user_ds = $self->{session}->get_archive()->get_data_set( "user" );
	$success = $success && $self->{session}->{database}->remove(
		$user_ds,
		"username",
		$self->{username} );
	
	return( $success );
}

######################################################################
#
# @username = $extract( $names )
#
#  Gets the usernames out of a username list. Returns an array of username's
#
######################################################################

## WP1: BAD
sub extract
{
	my( $usernames ) = @_;
	
	my( @usernamelist, $i, @usernamesplit );
	
	@usernamesplit = split /:/, $usernames if( defined $usernames );
	
	for( $i = 1; $i<=$#usernamesplit; $i++ )
	{
		push @usernamelist, $usernamesplit[$i]
			if( $usernamesplit[$i] ne "" );
	}
	
	return( @usernamelist );
}

## WP1: BAD
sub to_string
{
	my( $self ) = @_;

	return( $self->{session}->get_archive()->call( "user_display_name" , $self  ) );
}

## WP1: GOOD
sub get_value
{
	my( $self , $fieldname ) = @_;

	if( $self->{data}->{$fieldname} eq "")
	{
		return undef;
	}

	return $self->{data}->{$fieldname};
}

sub getValues
{
	my( $self ) = @_;

	return $self->{data};
}

## WP1: GOOD
sub set_value
{
	my( $self , $fieldname, $newvalue ) = @_;

	$self->{data}->{$fieldname} = $newvalue;
}

## WP1: GOOD
sub is_set
{
	my( $self ,  $fieldname ) = @_;

	if( !defined $self->{data}->{$fieldname} )
	{
		return 0;
	}

	if( $self->{data}->{$fieldname} eq "" )
	{
		return 0;
	}

	return 1;
}

## WP1: GOOD
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

sub get_eprints
{
	my( $self , $ds ) = @_;

	my $searchexp = new EPrints::SearchExpression(
		session=>$self->{session},
		dataset=>$ds );

	$searchexp->add_field(
		$ds->get_field( "username" ),
		"PHR:EQ:$self->{username}" );

#cjg set order (it's in the site config)

	my $searchid = $searchexp->perform_search;

	return  $searchexp->get_records;
}

1;
