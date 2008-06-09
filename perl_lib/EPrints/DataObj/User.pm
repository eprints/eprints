######################################################################
#
# EPrints::DataObj::User
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

B<EPrints::DataObj::User> - Class representing a single user.

=head1 DESCRIPTION

This class represents a single eprint user record and the metadata 
associated with it. 

EPrints::DataObj::User is a subclass of EPrints::DataObj with the following
metadata fields (plus those defined in ArchiveMetadataFieldsConfig:

=head1 SYSTEM METADATA

=over 4

=item userid (int)

The unique ID number of this user record. Unique within the current repository.

=item rev_number (int)

The revision number of this record. Each time it is changed the revision
number is increased. This is not currently used for anything but it may
be used for logging later.

=item username (text)

The username of this user. Used for logging into the system. Unique within
this repository.

=item password (secret)

The password of this user encoded with crypt. This may be ignored if the
repository is using an alternate authentication system, eg. LDAP.

=item usertype (namedset)

The type of this user. The options are configured in metadata-phrases.xml.

=item newemail (email)

Used to store a new but as yet unconfirmed email address.

=item newpassword (secret)

Used to store a new but as yet unconfirmed password.

=item pin (text)

A code required to confirm a new username or password. This code is emailed
to the user to confirm they are who they say they are.

=item pinsettime (int)

When the pin code was set, so we can make it time out.

=item joined (time)

The date and time that the user account was created. Before EPrints 2.4 this
was a date field so users created before the upgrade will appear to have been 
created at midnight.

=item email (email)

The email address of this user. Unique within the repository. 

=item lang (namedset) 

The ID of the prefered language of this user. Only really used in multilingual
repositories.

=item editperms (search, multiple)

This field is used to filter what eprints a staff member can approve and 
modify. If it's unset then they can modify any (given the correct privs. but
if it is set then an eprint must match at least one of the searches to be
within their scope.

=item frequency (set)

Only relevant to staff accounts. Is the frequency they want to be mailed 
about eprints matching their scope that are in editorial review. never, 
daily, weekly or monthly.

=item mailempty (boolean)

Only relevant to staff accounts. If set to true then emails are sent
even if there are no items matching the scope.

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::User;

@ISA = ( 'EPrints::DataObj' );

use EPrints;
use EPrints::Search;

use strict;


######################################################################
=pod

=item $field_info = EPrints::DataObj::User->get_system_field_info

Return an array describing the system metadata of the this 
dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"userid", type=>"int", required=>1, import=>0, can_clone=>1, },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0 },

		{ name=>"saved_searches", type=>"subobject", datasetid=>'saved_search',
			multiple=>1 },

		{ name=>"username", type=>"text", required=>1 },

		{ name=>"password", type=>"secret", show_in_html=>0,
			fromform=>\&EPrints::Utils::crypt_password },

		{ name=>"usertype", type=>"namedset", required=>1, 
			set_name=>"user", input_style=>"medium" },
	
		{ name=>"newemail", type=>"email", show_in_html=>0 },
	
		{ name=>"newpassword", type=>"secret", show_in_html=>0, 
			fromform=>\&EPrints::Utils::crypt_password },

		{ name=>"pin", type=>"text", show_in_html=>0 },

		{ name=>"pinsettime", type=>"int", show_in_html=>0 },

		{ name=>"joined", type=>"time", required=>1 },

		{ name=>"email", type=>"email", required=>1 },

		{ name=>"lang", type=>"arclanguage", required=>0, 
			input_rows=>1 },

		{ name => "editperms", 
			multiple => 1,
			input_ordered => 0,
			input_add_boxes => 1,
			input_boxes => 1,
			type => "search", 
			datasetid => "eprint",
			fieldnames => "editpermfields",
		},

		{ name => "permission_group", multiple => 1, type => "namedset", 
			set_name => "permission_group", },

		{ name => "roles", multiple => 1, type => "text", text_index=>0 },

		{ name=>"frequency", type=>"set", input_style=>"medium",
			options=>["never","daily","weekly","monthly"] },

		{ name=>"mailempty", type=>"boolean", input_style=>"radio" },

		{ name=>"items_fields", type=>"fields", datasetid=>"eprint", 
			multiple=>1, input_ordered=>1, required=>1, volatile=>1 },

		{ name=>"review_fields", type=>"fields", datasetid=>"eprint", 
			multiple=>1, input_ordered=>1, required=>1, volatile=>1 },

		{ name=>"latitude", type=>"float", required=>0 },

		{ name=>"longitude", type=>"float", required=>0 },

	)
};



######################################################################
=pod

=item $user = EPrints::DataObj::User->new( $session, $userid )

Load the user with the ID of $userid from the database and return
it as an EPrints::DataObj::User object.

=cut
######################################################################

sub new
{
	my( $class, $session, $userid ) = @_;

	return $session->get_database->get_single( 
		$session->get_repository->get_dataset( "user" ),
		$userid );
}


######################################################################
=pod

=item $user = EPrints::DataObj::User->new_from_data( $session, $data )

Construct a new EPrints::DataObj::User object based on the $data hash 
reference of metadata.

Used to create an object from the data retrieved from the database.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$session->get_repository->get_dataset( "user" ) );
}



######################################################################
# =pod
# 
# =item $user = EPrints::DataObj::User::create( $session, $user_type )
# 
# Create a new user in the database with the specified user type.
# 
# =cut
######################################################################

sub create
{
	my( $session, $user_type ) = @_;


	return EPrints::DataObj::User->create_from_data( 
		$session, 
		{ usertype=>$user_type },
		$session->get_repository->get_dataset( "user" ) );
}

######################################################################
# =pod
# 
# =item $dataobj = EPrints::DataObj->create_from_data( $session, $data, $dataset )
# 
# Create a new object of this type in the database. 
# 
# $dataset is the dataset it will belong to. 
# 
# $data is the data structured as with new_from_data.
# 
# =cut
######################################################################

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	my $new_user = $class->SUPER::create_from_data( $session, $data, $dataset );

	$session->get_database->counter_minimum( "userid", $new_user->get_id );

	return $new_user;
}

######################################################################
=pod

=item $dataset = EPrints::DataObj::User->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "user";
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::User->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	my $date_joined = EPrints::Time::get_iso_timestamp();

	my $defaults = { 
		"userid"=>$data->{userid},
		"joined"=>$date_joined,
		"frequency"=>'never',
		"mailempty"=>"FALSE",
		"rev_number"=>1,
	};

	if( !defined $data->{userid} )
	{ 
		$defaults->{userid} = _create_userid( $session );
	}

	$session->get_repository->call(
		"set_user_defaults",
		$defaults,
		$session );

	return $defaults;
}



######################################################################
=pod

=item $user = EPrints::DataObj::User::user_with_email( $session, $email )

Return the EPrints::user with the specified $email, or undef if they
are not found.

=cut
######################################################################

sub user_with_email
{
	my( $session, $email ) = @_;
	
	my $user_ds = $session->get_repository->get_dataset( "user" );

	my $searchexp = new EPrints::Search(
		session=>$session,
		dataset=>$user_ds );

	$searchexp->add_field(
		$user_ds->get_field( "email" ),
		$email );

	my $searchid = $searchexp->perform_search;
	my @records = $searchexp->get_records(0,1);
	$searchexp->dispose();
	
	return $records[0];
}


######################################################################
=pod

=item $user = EPrints::DataObj::User::user_with_username( $session, $username )

Return the EPrints::user with the specified $username, or undef if 
they are not found.

=cut
######################################################################

sub user_with_username
{
	my( $session, $username ) = @_;
	
	my $user_ds = $session->get_repository->get_dataset( "user" );

	my $searchexp = new EPrints::Search(
		session=>$session,
		dataset=>$user_ds );

	$searchexp->add_field(
		$user_ds->get_field( "username" ),
		$username,
		"EX" );

	my $results = $searchexp->perform_search;
	my @records = $results->get_records(0,1);
	
	return $records[0];
}


######################################################################
=pod

=item $problems = $thing->validate

Validate the user - find out if all the required fields are filled
out, and that what's been filled in is OK. Returns a reference to an
array of problem descriptions.

If there are no probelms then the array is empty.

The problems are XHTML DOM objects describing the problem.

=cut
######################################################################

sub validate
{
	my( $self ) = @_;

	my @problems;

	my $user_ds = $self->{session}->get_repository->get_dataset( "user" );

	my %opts = ( item=> $self, session=>$self->{session} );
 	my $workflow = EPrints::Workflow->new( $self->{session}, "default", %opts );

	push @problems, $workflow->validate;

	push @problems, $self->{session}->get_repository->call(
			"validate_user",
			$self,
			$self->{session} );

	return( \@problems );
}



######################################################################
=pod

=item $user->commit( [$force] )

Write this object to the database.

If $force isn't true then it only actually modifies the database
if one or more fields have been changed.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;

	$self->{session}->get_repository->call( 
		"set_user_automatic_fields", 
		$self );
	
	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}
	if( $self->{non_volatile_change} )
	{
		$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );	
	}

	my $user_ds = $self->{session}->get_repository->get_dataset( "user" );
	$self->tidy;
	my $success = $self->{session}->get_database->update(
		$user_ds,
		$self->{data} );
	
	$self->queue_changes;

	return( $success );
}



######################################################################
=pod

=item $success = $user->remove

Remove this user from the database. Also, remove their saved searches,
but do not remove their eprints.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	my $success = 1;

	foreach my $saved_search ( $self->get_saved_searches )
	{
		$saved_search->remove;
	}

	# remove user record
	my $user_ds = $self->{session}->get_repository->get_dataset( "user" );
	$success = $success && $self->{session}->get_database->remove(
		$user_ds,
		$self->get_value( "userid" ) );
	
	return( $success );
}




######################################################################
=pod

=item $list = $user->get_eprints( $dataset )

Return EPrints in the given EPrints::DataSet which have this user
as their creator.

Since 2.4 this returns an EPrints::List object, not an array of eprints.

=cut
######################################################################

sub get_eprints
{
	my( $self , $ds ) = @_;

	my $searchexp = new EPrints::Search(
		session=>$self->{session},
		custom_order=>"eprintid",
		dataset=>$ds );

	$searchexp->add_field(
		$ds->get_field( "userid" ),
		$self->get_value( "userid" ) );

	return $searchexp->perform_search;
}

######################################################################
=pod

=item $list = $user->get_editable_eprints

Return eprints currently in the editorial review buffer. If this user
has editperms set then only return those records which match.

Since 2.4 this returns an EPrints::List object, not an array of eprints.

=cut
######################################################################

sub get_editable_eprints
{
	my( $self ) = @_;

	unless( $self->is_set( 'editperms' ) )
	{
		my $ds = $self->{session}->get_repository->get_dataset( 
			"buffer" );
		my $searchexp = EPrints::Search->new(
			allow_blank => 1,
			custom_order => "-datestamp",
			dataset => $ds,
			session => $self->{session} );
		return $searchexp->perform_search;
	}

	my $editperms = $self->{dataset}->get_field( "editperms" );
	my $list = undef;
	foreach my $sv ( @{$self->get_value( 'editperms' )} )
	{
		my $searchexp = $editperms->make_searchexp(
			$self->{session},
			$sv );
		$searchexp->add_field(
			$self->{session}->get_repository->get_dataset("eprint" )->get_field( "eprint_status" ),
			"buffer" );
		$searchexp->{custom_order}="-datestamp";
	        $searchexp->{order} = $EPrints::Search::CustomOrder;

		my $newlist = $searchexp->perform_search;
		if( defined $list )
		{
			$list = $list->merge( $newlist );
		}
		else
		{
			$list = $newlist;
		}
	}
	return $list;
}

######################################################################
=pod

=item $list = $user->get_owned_eprints( $dataset );

Return a list of the eprints which this user owns. This is by default
the same as $user->get_eprints( $dataset) but may be over-ridden by
get_users_owned_eprints.

Since 2.4 this returns an EPrints::List object, not an array of eprints.

=cut
######################################################################

sub get_owned_eprints
{
	my( $self, $ds ) = @_;

	my $fn = $self->{session}->get_repository->get_conf( "get_users_owned_eprints" );

	if( !defined $fn )
	{
		return $self->get_eprints( $ds );
	}

	my $result = &$fn( $self->{session}, $self, $ds );
	unless( $result->isa( "EPrints::List" ) )
	{
		EPrints::abort( "get_users_owned_eprints should now return an EPrints::List object." );
	}
	return $result;
}

######################################################################
=pod

=item $boolean = $user->has_owner( $possible_owner )

True if the users are the same record.

=cut
######################################################################

sub has_owner
{
	my( $self, $possible_owner ) = @_;

	if( $possible_owner->get_value( "userid" ) == $self->get_value( "userid" ) )
	{
		return 1;
	}

	return 0;
}






######################################################################
=pod

=item $ok = $user->mail( $subjectid, $message, [$replyto], [$email] )

Send an email to this user. 

$subjectid is the ID of a phrase to use as the subject of this email.

$message is an XML DOM object describing the message in simple XHTML.

$replyto is the reply to address for this email, if different to the
repository default.

$email is the email address to send this email to if different from
this users configured email address.

Return true if the email was sent OK.

=cut
######################################################################

sub mail
{
	my( $self,   $subjectid, $message, $replyto,  $email ) = @_;
	#   User   , string,     DOM,      User/undef Other Email

	# Mail the admin in the default language
	my $langid = $self->get_value( "lang" );
	my $lang = $self->{session}->get_repository->get_language( $langid );

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

	return EPrints::Email::send_mail(
		session  => $self->{session},
		langid   => $langid,
		to_name  => EPrints::Utils::tree_to_utf8( $self->render_description ),
		to_email => $email,
		subject  => EPrints::Utils::tree_to_utf8( $lang->phrase( $subjectid, {}, $self->{session} ) ),
		message  => $message,
		sig      => $lang->phrase( "mail_sig", {}, $self->{session} ),
		replyto_name  => $rname, 
		replyto_email => $remail,
	); 
}



######################################################################
# 
# $userid = EPrints::DataObj::User::_create_userid( $session )
#
# Get the next unused userid value.
#
######################################################################

sub _create_userid
{
	my( $session ) = @_;
	
	my $new_id = $session->get_database->counter_next( "userid" );

	return( $new_id );
}


######################################################################
=pod

=item ( $page, $title ) = $user->render

Render this user into HTML using the "user_render" method in
ArchiveRenderConfig.pm. Returns both the rendered information and
the title as XHTML DOM.

=cut
######################################################################

sub render
{
	my( $self ) = @_;

	my( $dom, $title ) = $self->{session}->get_repository->call( "user_render", $self, $self->{session} );

	if( !defined $title )
	{
		$title = $self->render_description;
	}

	return( $dom, $title );
}

# This should include all the info, not just that presented to the public.

######################################################################
=pod

=item ( $page, $title ) = $user->render_full

The same as $user->render, but renders all fields, not just those 
intended for public viewing. This is the admin view of the user.

=cut
######################################################################

sub render_full
{
	my( $self ) = @_;

	my( $table, $title ) = $self->SUPER::render_full;

	my $ds = $self->{session}->get_repository->get_dataset( "saved_search" );
	foreach my $saved_search ( $self->get_saved_searches )
	{
		my $rowright = $self->{session}->make_doc_fragment;
		foreach( "frequency","spec","mailempty" )
		{
			my $strong;
			$strong = $self->{session}->make_element( "strong" );
			$strong->appendChild( $ds->get_field( $_ )->render_name( $self->{session} ) );
			$strong->appendChild( $self->{session}->make_text( ": " ) );
			$rowright->appendChild( $strong );
			$rowright->appendChild( $saved_search->render_value( $_ ) );
			$rowright->appendChild( $self->{session}->make_element( "br" ) );
		}
		$table->appendChild( $self->{session}->render_row(
			$self->{session}->html_phrase(
				"page:saved_search" ),
			$rowright ) );
				
	}

	return( $table, $title );
}


######################################################################
=pod

=item $url = $user->get_url

Return the URL which will display information about this user.

If $staff is true then return the URL for an administrator to view
and modify this record.

=cut
######################################################################

sub get_url
{
	my( $self ) = @_;

	return $self->{session}->get_repository->get_conf( "http_cgiurl" )."/users/home?screen=User::View&userid=".$self->get_value( "userid" );
}

sub get_control_url
{
	my( $self ) = @_;

	return $self->{session}->get_repository->get_conf( "http_cgiurl" )."/users/home?screen=User::View&userid=".$self->get_value( "userid" );
}
	

######################################################################
=pod

=item $type = $user->get_type

Return the type of this user. Equivalent of 
$user->get_value( "usertype" );

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;

	return $self->get_value( "usertype" );
}


######################################################################
=pod

=item @saved_searches = $eprint->get_saved_searches

Return an array of all EPrint::DataObj::SavedSearch objects associated with this
user.

=cut
######################################################################

sub get_saved_searches
{
	my( $self ) = @_;

	my $ds = $self->{session}->get_repository->get_dataset( 
		"saved_search" );

	my $searchexp = EPrints::Search->new(
		session=>$self->{session},
		dataset=>$ds,
		custom_order=>"id" );

	$searchexp->add_field(
		$ds->get_field( "userid" ),
		$self->get_value( "userid" ) );

	my $searchid = $searchexp->perform_search;
	my @results = $searchexp->get_records;
	$searchexp->dispose;

	return( @results );
}


######################################################################
=pod

=item $user->send_out_editor_alert

Called on users who are editors, when it's time to send their update
on what items are in the editorial review buffer.

Sends the email if needed.

=cut
######################################################################

sub send_out_editor_alert
{
	my( $self ) = @_;

	my $freq = $self->get_value( "frequency" );


	if( $freq eq "never" )
	{
		$self->{session}->get_repository->log( 
			"Attempt to send out an editor alert for a user\n".
			"which has frequency 'never'\n" );
		return;
	}

	unless( $self->has_role( "editor" ) )
	{
		$self->{session}->get_repository->log( 
			"Attempt to send out an editor alert for a user\n".
			"which does not have editor role (".
			$self->get_value("username").")\n" );
		return;
	}
		
	my $origlangid = $self->{session}->get_langid;
	
	$self->{session}->change_lang( $self->get_value( "lang" ) );

	my $list = $self->get_editable_eprints;

	if( $list->count > 0 || $self->get_value( "mailempty" ) eq 'TRUE' )
	{
		my $url = URI->new($self->{session}->get_repository->get_conf( "http_cgiurl" )."/users/home");
		$url->query_form(
			screen => "User::Edit",
			userid => $self->get_id
		);
		my $freqphrase = $self->{session}->html_phrase(
			"lib/saved_search:".$freq ); # nb. reusing the SavedSearch.pm phrase
		my $searchdesc = $self->render_value( "editperms" );

		my $matches = $self->{session}->make_doc_fragment;

		$list->map( sub {
			my( $session, $dataset, $eprint ) = @_;

			my $p = $self->{session}->make_element( "p" );
			$p->appendChild( $eprint->render_citation );
			$matches->appendChild( $p );
			$matches->appendChild( $self->{session}->make_text( $eprint->get_url( 1 ) ) );
			$matches->appendChild( $self->{session}->make_element( "br" ) );
		} );

		my $mail = $self->{session}->html_phrase( 
				"lib/user:editor_update_mail",
				howoften => $freqphrase,
				n => $self->{session}->make_text( $list->count ),
				search => $searchdesc,
				matches => $matches,
				url => $self->{session}->render_link( $url ) );
		$self->mail( 
			"lib/user:editor_update_subject",
			$mail );
		EPrints::XML::dispose( $mail );
	}

	$self->{session}->change_lang( $origlangid );
}


######################################################################
=pod

=item EPrints::DataObj::User::process_editor_alerts( $session, $frequency );

Static method.

Called to send out all editor alerts of a given frequency (daily,
weekly, monthly) for the current repository.

=cut
######################################################################

sub process_editor_alerts
{
	my( $session, $frequency ) = @_;

	if( $frequency ne "daily" && 
		$frequency ne "weekly" && 
		$frequency ne "monthly" )
	{
		$session->get_repository->log( "EPrints::DataObj::User::process_editor_alerts called with unknown frequency: ".$frequency );
		return;
	}

	my $subs_ds = $session->get_repository->get_dataset( "user" );

	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $subs_ds );

	$searchexp->add_field(
		$subs_ds->get_field( "frequency" ),
		$frequency );

	my $fn = sub {
		my( $session, $dataset, $item, $info ) = @_;

		return unless( $item->has_role( "editor" ) );

		$item->send_out_editor_alert;
		if( $session->get_noise >= 2 )
		{
			print "Sending out editor alert for ".$item->get_value( "username" )."\n";
		}
	};

	$searchexp->perform_search;
	$searchexp->map( $fn, {} );
	$searchexp->dispose;

	# currently no timestamp for editor alerts 
}





# Privs and Role related methods

# this maps roles onto privs
my $PRIVMAP = 
{

	general => 
	[
		"user/view",
	],

	"edit-own-record" => 
	[
		"user/edit:owner",
	],
		
	"set-password" => 
	[
		"set-password",
	],

	"change-email" => 
	[
		# not done
	],

	"change-user" => 
	[
		# not done
	],

	"staff-view" => 
	[
		# still needs search tools

		"eprint/inbox/view",
		"eprint/inbox/summary",
		"eprint/inbox/staff/export",
		"eprint/inbox/staff/details",
		"eprint/inbox/history",

		"eprint/buffer/view",
		"eprint/buffer/summary",
		"eprint/buffer/staff/export",
		"eprint/buffer/staff/details",
		"eprint/buffer/history",

		"eprint/archive/view",
		"eprint/archive/summary",
		"eprint/archive/staff/export",
		"eprint/archive/staff/details",
		"eprint/archive/history",

		"eprint/deletion/view",
		"eprint/deletion/summary",
		"eprint/deletion/staff/export",
		"eprint/deletion/staff/details",
		"eprint/deletion/history",

		"staff/eprint_search",
	],
	
	"view-status" => 
	[
		"status"
	],

	"admin" =>
	[
		"indexer/stop",
		"indexer/start",
		"indexer/force_start",
		"user/remove:editor",
		"user/view:editor",
		"user/history:editor",
		"user/staff/edit:editor",
		"create_user",
		"subject/edit:editor",
		"staff/user_search",
		"staff/history_search",
		"staff/issue_search",
		"config/view",
		"config/view/xml",
		"config/view/workflow",
		"config/view/citation",
		"config/view/phrase",
		"config/view/namedset",
		"config/view/template",
		"config/view/static",
		"config/view/autocomplete",
		"config/view/apache",
		"config/view/perl",
		"config/test_email",
		"config/add_field",
		"config/remove_field",
		"config/regen_abstracts",
		"config/regen_views",
		"metafield/view",
		"metafield/edit",
	],

	"toolbox" => 
	[
		"toolbox",
	],

	"edit-config" => 
	[
		"config/edit",
		"config/edit/xml",
		"config/edit/workflow",
		"config/edit/citation",
		"config/edit/phrase",
		"config/edit/namedset",
		"config/edit/template",
		"config/edit/static",
		"config/edit/autocomplete",
		# not editing perl files or apache files!
		"config/reload",
	],

	"saved-searches" => 
	[
		"saved_search",
		"create_saved_search",
		"saved_search/view:owner",
		"saved_search/perform:owner",
		"saved_search/edit:owner",
		"saved_search/remove:owner",
	],

	deposit => 
	[
		"items",
		"create_eprint",
		"user/history:owner",
	
		"eprint/inbox/view:owner",
		"eprint/inbox/summary:owner",
		"eprint/inbox/deposit:owner",
		"eprint/inbox/edit:owner",
		"eprint/inbox/remove:owner",
		"eprint/inbox/export:owner",
		"eprint/inbox/details:owner",
		"eprint/inbox/history:owner",
		"eprint/inbox/messages:owner",
		"eprint/inbox/issues:owner",
	
		"eprint/inbox/deposit:owner",
		"eprint/inbox/use_as_template:owner",
		"eprint/inbox/derive_version:owner",
	
	
		"eprint/buffer/view:owner",
		"eprint/buffer/summary:owner",
		"eprint/buffer/move_inbox:owner",
		"eprint/buffer/export:owner",
		"eprint/buffer/details:owner",
		"eprint/buffer/history:owner",
		"eprint/buffer/messages:owner",
	
		"eprint/buffer/request_removal:owner",
		"eprint/buffer/use_as_template:owner",
		"eprint/buffer/derive_version:owner",
	
	
		"eprint/archive/view:owner",
		"eprint/archive/summary:owner",
		"eprint/archive/export:owner",
		"eprint/archive/details:owner",
		"eprint/archive/history:owner",
		"eprint/archive/messages:owner",
	
		"eprint/archive/request_removal:owner",
		"eprint/archive/use_as_template:owner",
		"eprint/archive/derive_version:owner",
	

		"eprint/deletion/view:owner",
		"eprint/deletion/summary:owner",
		"eprint/deletion/export:owner",
		"eprint/deletion/details:owner",
		"eprint/deletion/history:owner",
		"eprint/deletion/messages:owner",
	
		"eprint/deletion/use_as_template:owner",
		"eprint/deletion/derive_version:owner",
	],

	editor => 
	[
		"editorial_review",

		"eprint/inbox/view:editor",
		"eprint/inbox/summary:editor",
		"eprint/inbox/staff/export:editor",
		"eprint/inbox/staff/details:editor",
		"eprint/inbox/history:editor",
		"eprint/inbox/messages:editor",

		"eprint/inbox/remove_with_email:editor",
		"eprint/inbox/move_archive:editor",
		"eprint/inbox/move_buffer:editor",
		"eprint/inbox/use_as_template:editor",
		"eprint/inbox/derive_version:editor",
		"eprint/inbox/staff/edit:editor",


		"eprint/buffer/view:editor",
		"eprint/buffer/summary:editor",
		"eprint/buffer/staff/export:editor",
		"eprint/buffer/staff/details:editor",
		"eprint/buffer/history:editor",
		"eprint/buffer/messages:editor",
		"eprint/buffer/issues:editor",

		"eprint/buffer/remove_with_email:editor",
		"eprint/buffer/reject_with_email:editor",
		"eprint/buffer/move_inbox:editor",
		"eprint/buffer/move_archive:editor",
		"eprint/buffer/use_as_template:editor",
		"eprint/buffer/derive_version:editor",
		"eprint/buffer/staff/edit:editor",


		"eprint/archive/view:editor",
		"eprint/archive/summary:editor",
		"eprint/archive/staff/export:editor",
		"eprint/archive/staff/details:editor",
		"eprint/archive/history:editor",
		"eprint/archive/messages:editor",
		"eprint/archive/issues:editor",

		"eprint/archive/move_buffer:editor",
		"eprint/archive/move_deletion:editor",
		"eprint/archive/use_as_template:editor",
		"eprint/archive/derive_version:editor",
		"eprint/archive/staff/edit:editor",


		"eprint/deletion/view:editor",
		"eprint/deletion/summary:editor",
		"eprint/deletion/staff/export:editor",
		"eprint/deletion/staff/details:editor",
		"eprint/deletion/history:editor",
		"eprint/deletion/messages:editor",

		"eprint/deletion/move_archive:editor",
		"eprint/deletion/use_as_template:editor",
		"eprint/deletion/derive_version:editor",
	],
	
};



######################################################################
=pod

=item $result = $user->allow( $priv, [$item] )

Rleturns true if $user can perform this action/view this screen.

A true result is 1..15 where the value indicates what about the user
allowed the priv to be performed. This is used for filtering owner/
editor actions in eprint control screens.

1 = anybody (not currently used)
2 = only if logged in 
4 = only if owner of item
8 = only if editor of item

For non item related privs the result will normally be 2.

Nb. That create eprint is NOT a priv related to an eprint, as you 
don't own it at that stage.

=cut
######################################################################

sub allow
{
	my( $self, $priv, $item ) = @_;

	return 1 if( $self->{session}->allow_anybody( $priv ) );

	my $privs = $self->get_privs;

	my $if_logged_in = $privs->{$priv} || 0;
	my $if_editor = $privs->{"$priv:editor"} || 0;
	my $if_owner = $privs->{"$priv:owner"} || 0;

	if( !$if_logged_in && ( $if_editor || $if_owner ) && !defined $item )
	{
		$self->{session}->get_repository->log(
"\$user->allow( $priv ) called. It needed an item to resolve the permission, but none was passed. Assuming false, but this may indicate a bug." );
		return 0;
	}

	my $r = 0;

	$r += 2 if( $if_logged_in  );

	$r += 4 if( $if_owner && defined $item && $item->has_owner( $self ) );

	$r += 8 if( $if_editor && defined $item && $item->in_editorial_scope_of( $self ) );

	return $r;
}

######################################################################
#
# $privs = $user->get_privs;
#
# Return the privs a user has. Currently just based on roles, but 
# could do more later. Returns a reference to a hash. Caches the 
# result to save time.
#
######################################################################

sub get_privs
{
	my( $self ) = @_;

	return $self->{".privs"} if( defined $self->{".privs"} ) ;

	my $rep = $self->{session}->get_repository;
	my $role_config = $rep->get_conf( "user_roles", $self->get_value( "usertype" ) );
	my $extra_roles = $self->get_value( "roles" ) || [];

	my %privmap = %{$PRIVMAP};

	# extra hats defined in this repository	
	my %override_roles = %{$rep->get_conf( "roles" )||{}};
	foreach my $role_id ( keys %override_roles )
	{
		$privmap{$role_id} = $override_roles{$role_id};
	}

	$self->{".privs"} = {};
	foreach my $role ( @{$role_config}, @{$extra_roles} )
	{
		if( $role =~ m/^\+(.*)$/ )
		{
			$self->{".privs"}->{$1} = 1;
			next;
		}

		if( $role =~ m/^-(.*)$/ )
		{
			delete $self->{".privs"}->{$1};
			next;
		}

		foreach my $priv ( @{$privmap{$role}} ) 
		{ 
			$self->{".privs"}->{$priv} = 1;
		}
	}

	return $self->{".privs"};
}
	
######################################################################
#
# @roles = $user->get_roles;
#
# Return the roles the user has. Each role represents a whole bunch
# of privs.
#
######################################################################

sub get_roles
{
	my( $self ) = @_;

	my $rep = $self->{session}->get_repository;
	my $role_config = $rep->get_conf( "user_roles", $self->get_value( "usertype" ) );
	my $extra_roles = $self->get_value( "roles" ) || [];
	my @roles = ();
	foreach my $role ( @{$role_config}, @{$extra_roles} )
	{
		next if( $role =~ m/^[+-]/ );
		push @roles, $role;
	}

	return @roles;
}

sub has_role
{
	my( $self, $roleid ) = @_;

	foreach my $hasid ( $self->get_roles )
	{
		return 1 if $hasid eq $roleid;
	}
	
	return 0;
}





1;

######################################################################
=pod

=back

=cut

