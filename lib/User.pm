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

##cjg _ verify password is NOT non-ascii!

package EPrints::User;

use EPrints::Database;
use EPrints::MetaField;
use EPrints::Utils;
use EPrints::Subscription;

use strict;

## WP1: BAD
sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"userid", type=>"int", required=>1 },

		{ name=>"username", type=>"text", required=>1 },

		{ name=>"password", type=>"secret" },

		{ name=>"usertype", type=>"datatype", required=>1, 
			datasetid=>"user" },
	
		{ name=>"newemail", type=>"email" },
	
		{ name=>"newpassword", type=>"secret" },

		{ name=>"pin", type=>"text" },

		{ name=>"pinsettime", type=>"int" },

		{ name=>"editorsubjects", type=>"subject", multiple=>1, showall=>1, showtop=>1, top=>"ROOT" },

		#cjg created would be a better name than joined??
		{ name=>"joined", type=>"date", required=>1 },

		{ name=>"email", type=>"email", required=>1 },

		{ name=>"lang", type=>"datatype", required=>0, 
			datasetid=>"arclanguage" }
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

## WP1: BAD
sub new
{
	my( $class, $session, $userid ) = @_;

	return $session->get_db()->get_single( 
		$session->get_archive()->get_dataset( "user" ),
		$userid );
}

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	my $self = {};
	bless $self, $class;
	$self->{data} = $known;
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

sub create_user
{
	my( $session, $access_level ) = @_;
	
	my $user_ds = $session->get_archive()->get_dataset( "user" );
	my $userid = _create_userid( $session );
		
	# And work out the date joined.
	my $date_joined = EPrints::MetaField::get_datestamp( time );

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

sub user_with_email
{
	my( $session, $email ) = @_;
	
	my $user_ds = $session->get_archive()->get_dataset( "user" );

	my $searchexp = new EPrints::SearchExpression(
		session=>$session,
		dataset=>$user_ds );

	$searchexp->add_field(
		$user_ds->get_field( "email" ),
		"PHR:EQ:".$email );

	my $searchid = $searchexp->perform_search;
	my @records = $searchexp->get_records;
	$searchexp->dispose();
	
	return $records[0];
}

sub user_with_username
{
	my( $session, $username ) = @_;
	
	my $user_ds = $session->get_archive()->get_dataset( "user" );

	my $searchexp = new EPrints::SearchExpression(
		session=>$session,
		dataset=>$user_ds );

	$searchexp->add_field(
		$user_ds->get_field( "username" ),
		"PHR:EQ:".$username );

	my $searchid = $searchexp->perform_search;

	my @records = $searchexp->get_records;
	$searchexp->dispose();
	
	return $records[0];
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
	my $user_ds = $self->{session}->get_archive()->get_dataset( "user" );
	my @rfields = $user_ds->get_required_type_fields();
	my @all_fields = $user_ds->get_fields();

	my $field;
	foreach $field ( @rfields )
	{
		# Check that the field is filled in if it is required
		if( !$self->is_set( $field->get_name() ) )
		{
			push @all_problems, 
			  $self->{session}->phrase( 
			   "lib/user:missed_field", 
			   field => $field->display_name( $self->{session} ) );
		}
	}

	# Give the validation module a go
	foreach $field ( @all_fields )
	{
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

	$self->{session}->get_archive()->call( "set_user_automatic_fields", $self );
	
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

## WP1: BAD
sub remove
{
	my( $self ) = @_;
	
	my $success = 1;

	# First, remove their EPrints
	my @eprints = EPrints::EPrint::retrieve_eprints(
		$self->{session},
		EPrints::Database::table_name( "archive" ),
		[ "userid LIKE \"$self->{userid}\"" ] );

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
	my $user_ds = $self->{session}->get_archive()->get_dataset( "user" );
	$success = $success && $self->{session}->{database}->remove(
		$user_ds,
		"userid",
		$self->{userid} );
	
	return( $success );
}


sub get_value
{
	my( $self , $fieldname ) = @_;

	unless( EPrints::Utils::is_set( $self->{data}->{$fieldname} ) )
	{
		return undef;
	}

	return $self->{data}->{$fieldname};
}

sub get_values
{
	my( $self ) = @_;

	return $self->{data};
}

sub set_value
{
	my( $self , $fieldname, $newvalue ) = @_;

	$self->{data}->{$fieldname} = $newvalue;
}

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
		$ds->get_field( "userid" ),
		"PHR:EQ:".$self->get_value( "userid" ) );

#cjg set order (it's in the site config)

	my $searchid = $searchexp->perform_search;

	my @records = $searchexp->get_records;
	$searchexp->dispose();
	return @records;
}

# return eprints currently in the submission buffer for which this user is a 
# valid editor.
#cjg not done yet.
sub get_editable_eprints
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_archive()->get_dataset( "buffer" );

	my $searchexp = new EPrints::SearchExpression(
		session=>$self->{session},
		allow_blank=>1,
		dataset=>$ds );

#	$searchexp->add_field(
#		$ds->get_field( "userid" ),
#		"PHR:EQ:".$self->get_value( "userid" ) );

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

# cjg not done
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
# cjg could be ICK and just use get_owned_eprints...
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


sub mail
{
	my( $self,   $subjectid, $messageid,    %inserts ) = @_;
	#   Session, string,     string OR DOM, string->DOM

	# Mail the admin in the default language
	my $langid = $self->get_value( "lang" );
	my $lang = $self->{session}->get_archive()->get_language( $langid );
print STDERR "REF: ".ref($messageid)."\n";
	my $message;
	if( ref($message) eq "" )
	{
		print STDERR "BoNG\n";
		$message = $lang->phrase( $messageid, \%inserts, $self->{session} );
		print STDERR "BING\n";
	}
	else
	{
		$message = $messageid;
	}


	return EPrints::Utils::send_mail(
		$self->{session}->get_archive(),
		$langid,
		$self->full_name(),
		$self->get_value( "email" ),
		EPrints::Utils::tree_to_utf8( $lang->phrase( $subjectid, {}, $self->{session} ) ),
		$message,
		$lang->phrase( "mail_sig", {}, $self->{session} ) ); 
}



sub _create_userid
{
	my( $session ) = @_;
	
	my $new_id = $session->get_db()->counter_next( "userid" );

	return( $new_id );
}

sub render_value
{
	my( $self, $fieldname, $showall ) = @_;

	my $field = $self->{dataset}->get_field( $fieldname );	
	
	return $field->render_value( $self->{session}, $self->get_value($fieldname), $showall );
}



sub render
{
        my( $self ) = @_;

        my( $dom, $title ) = $self->{session}->get_archive()->call( "user_render", $self, $self->{session}, 0 );
	
        return( $dom, $title );
}

# This should include all the info, not just that presented to the public.
sub render_full
{
        my( $self ) = @_;

        my( $dom, $title ) = $self->{session}->get_archive()->call( "user_render", $self, $self->{session}, 1 );

        return( $dom, $title );
}

sub get_dataset
{
	my( $self ) = @_;
	
	return $self->{dataset};
}

sub get_session
{
	my( $self ) = @_;

	return $self->{session};
}

sub render_citation_link
{
	my( $self , $cstyle , $staff ) = @_;
	my $url;

#cjg finish me!
	if( defined $staff && $staff )
	{
		$url = $self->{session}->get_archive()->get_conf( "server_perl_root" )."/users/staff/view_user?userid=".$self->get_value( "userid" );

	}
	else
	{
		$url = $self->{session}->get_archive()->get_conf( "server_perl_root" )."/view_user?userid=".$self->get_value( "userid" );
		$url = "???";
	}

	my $a = $self->{session}->make_element( "a", href=>$url );
	$a->appendChild( $self->render_citation( $cstyle ) );

	return $a;
}

sub render_citation
{
	my( $self , $cstyle ) = @_;

	if( !defined $cstyle )
	{
		$cstyle = $self->{session}->get_citation_spec(
					$self->{dataset},
					$self->get_value( "usertype" ) );
	}

	EPrints::Utils::render_citation( $self , $cstyle );
}

sub get_id
{
	my( $self ) = @_;

	return $self->{data}->{userid};
}
	

1;
