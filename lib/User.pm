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
use EPrints::MetaInfo;
use EPrints::Log;
use EPrints::Mailer;
use EPrints::Subscription;
use EPrintSite::SiteInfo;
use EPrintSite::SiteRoutines;
use EPrintSite::Validate;

use strict;

sub get_system_field_info
{
	my( $class , $site ) = @_;

	my @usertypes = keys %{$site->{usertypes}};

	return ( 
	{
		name=>"username",
		type=>"text",
		required=>1,
		editable=>0,
		visable=>0
	},
	{
		name=>"passwd",
		type=>"text",
		required=>1,
		editable=>0,
		visable=>0
	},
	{
		name=>"usertype",
		type=>"set",
		required=>1,
		editable=>0,
		visable=>0,
		options=>\@usertypes
	},
	{
		name=>"joined",
		type=>"date",
		required=>1,
		editable=>0,
		visable=>0
	},
	{
		name=>"email",
		type=>"email",
		required=>1,
		visable=>1
	} );
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

sub new
{
	my( $class, $session, $username, $known ) = @_;
	

	if( !defined $known )
	{
		return $session->{database}->get_single( "user", $username );
	} 

	my $self = $known;
	bless $self, $class;
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

sub create_user
{
	my( $session, $username_candidate, $email, $access_level ) = @_;
	
	my $found = 0;
	my $used_count = 0;
	my $candidate = $username_candidate;
	
	while( $found==0 )
	{
		#print "Trying $candidate\n";
	
		if( $session->{database}->exists( "user", $candidate ) )
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
	$session->{database}->add_record( "user",
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
# $user = current_user( $session )
#
#  Convenience function, returning the current user (if any). undef
#  is returned if there is no current user.
#
######################################################################

sub current_user
{
	my( $session ) = @_;

	my $user = undef;
	
	my $username = $ENV{'REMOTE_USER'};
	#$session->{request}->user;

#EPrints::Log::debug( "User", "current_user: $username" );

	if( defined $username && $username ne "" )
	{
		$user = new EPrints::User( $session, $username );
	}

	return( $user );
}


######################################################################
#
#  $password = _generate_password( $length )
#
#   Generates a random password $length characters long.
#
######################################################################

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

sub user_with_email
{
	my( $session, $email ) = @_;
	
	# Find out which user it is
	my @row = $session->{database}->retrieve_single(
		"user",
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

sub full_name
{
	my( $self ) = @_;

	# Delegate to site-specific routine
	return( EPrintSite::SiteRoutines::user_display_name( $self ) );
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

sub validate
{
	my( $self ) = @_;

	my @all_problems;
	my @all_fields = $self->{session}->{metainfo}->get_fields( "users" );
	my $field;
	
	foreach $field (@all_fields)
	{
		# Check that the field is filled in if it is required
		if( $field->{required} && ( !defined $self->{$field->{name}} ||
		                        	 $self->{$field->{name}} eq "" ) )
		{
			push @all_problems, 
			   $self->{session}->{lang}->phrase( "H:missedfield", 
			                                     { field=>$field->displayname( $self->{session} ) } );
		}
		else
		{
			# Give the validation module a go
			my $problem = EPrintSite::Validate::validate_user_field(
				$field,
				$self->{$field->{name}} );

			if( defined $problem && $problem ne "" )
			{
				push @all_problems, $problem;
			}
		}
	}

#	foreach (@all_problems)
#	{
#		EPrints::Log::debug( "User", "validate: got problem $_" );
#	}

	return( \@all_problems );
}


######################################################################
#
# $success = commit()
#
#  Update the database with any changes that have been made.
#
######################################################################

sub commit
{
	my( $self ) = @_;
	
	my $success = $self->{session}->{database}->update(
		"user",
		$self );

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

sub send_introduction
{
	my( $self ) = @_;

	my $subj;
	if ( $self->{usertype} eq "Staff" )
	{
		$subj = "S:newstaff";
   }
	else
	{
		$subj = "S:newuser";
   }
	# Try and send the mail
	return( EPrints::Mailer::prepare_send_mail(
		$self->{session},
		$self->{session}->{lang}->phrase( $subj , { sitename=>$self->{session}->{site}->{sitename} } ),
		$self->{email},
		$self->{session}->{lang}->phrase( "S:welcome", 
		                                 { sitename=>$self->{session}->{site}->{sitename} } ),
		$self->{session}->{site}->{template_user_intro},
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

sub send_reminder
{
	my( $self, $message ) = @_;
	
	my $full_message = $self->{session}->{lang}->phrase(
	     "M:reminder",
		  { sitename=>$self->{session}->{site}->{sitename},
	     	  message=>( defined $message ? "$message\n\n" : "" ),
		  username=>$self->{username},
		  password=>$self->{passwd},
		  adminemail=>$EPrintSite::SiteInfo::admin } );

	return( EPrints::Mailer::send_mail( 
			$self->{session},
			$self->full_name(),
	                $self->{email},
	                $self->{session}->{lang}->phrase( 
                        	"S:remindersub" ),
	                $full_message ) );
}

######################################################################
#
# @users = retrieve_users( $session, $conditions, $order )
#
#  Retrieves users from the database, returning User objects. [STATIC]
#
######################################################################

sub retrieve_users
{
	my( $session, $conditions, $order ) = @_;
	
	my @fields = $session->{metainfo}->get_fields( "users" );

	my $rows = $session->{database}->retrieve_fields(
		"user",
		\@fields,
		$conditions,
		$order );

#EPrints::Log::debug( "EPrint", "Making User objects" );

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
	$success = $success && $self->{session}->{database}->remove(
		"user",
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



1;
