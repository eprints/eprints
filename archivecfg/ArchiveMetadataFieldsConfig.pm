######################################################################
#
#  Site Information: Metadata Fields
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
# __LICENSE__
#
######################################################################
#
# Metadata Configuration
#
#  The archive specific fields for users and eprints. Some fields
#  come automatically like a user's username or an eprints type. See
#  the docs for more information.
#
#  It's very tricky to change these fields without erasing the archive
#  and starting from scratch. So make the effort to get it right!
#
#  Note: Changing the fields here (usually) requires you to make a 
#  number of other configuration changes in some or all of the 
#  following:
#   - The metadata types config XML file
#   - The citation config XML file(s)
#   - The render functions
#   - The search options 
#   - The OAI support 
#
#  To (re)create the database you will need to run
#   bin/erase_archive  (if you've already run create_tables before)
#   bin/create_tables
#
#  See the documentation for more information.
#
######################################################################

sub get_metadata_conf
{
my $fields = {};

$fields->{user} = [

	{ name => "name", type => "name" },

	{ name => "dept", type => "text" },

	{ name => "org", type => "text" },

	{ name => "address", type => "longtext", input_rows => 5 },

	{ name => "country", type => "text" },

	{ name => "hideemail", type => "boolean" },

	{ name => "os", type => "set",
		options => [ "unspec", "win9x", "unix", "vms", "mac", "other" ] },

	{ name => "url", type => "url" }

];

$fields->{eprint} = [
	{ name => "abstract", input_rows => 10, type => "longtext" },

	{ name => "altloc", type => "url", multiple => 1 },

	{ name => "authors", type => "name", multiple => 1, hasid => 1 },

	{ name => "chapter", type => "text", maxlength => 5 },

	{ name => "commref", type => "text" },

	{ name => "confdates", type => "text" },

	{ name => "conference", type => "text" },

	{ name => "confloc", type => "text" },

	{ name => "department", type => "text" },

	{ name => "editors", type => "name", multiple => 1, hasid=>1 },

	{ name => "institution", type => "text" },

	{ name => "ispublished", type => "set", 
			options => [ "unpub","inpress","pub" ] },

	{ name => "keywords", type => "longtext", input_rows => 2 },

	{ name => "month", type => "set",
		options => [ "jan","feb","mar","apr","may","jun",
			"jul","aug","sep","oct","nov","dec" ] },

	{ name => "note", type => "longtext", input_rows => 3 },

	{ name => "number", type => "text", maxlength => 6 },

	{ name => "pages", type => "pagerange" },

	{ name => "pubdom", type => "boolean", input_style=>"radio" },

	{ name => "publication", type => "text" },

	{ name => "publisher", type => "text" },

	{ name => "refereed", type => "boolean", input_style=>"menu" },

	{ name => "referencetext", type => "longtext", input_rows => 3 },

	{ name => "reportno", type => "text" },

	{ name => "series", type => "text" },

	{ name => "subjects", type=>"subject", top=>"subjects", multiple => 1, browse_link => "subjects" },

	{ name => "thesistype", type => "text" },

	{ name => "title", type => "text", render_single_value=>\&EPrints::Latex::render_string, input_style=>'textarea' },

	{ name => "volume", type => "text", maxlength => 6 },

	{ name => "year", type => "year" },

	{ name => "suggestions", type => "longtext" }
];

# Don't worry about this bit, remove it if you want.
# it's to store some information for a citation-linking
# modules we've not built yet. 
	
$fields->{document} = [
	{ name => "citeinfo", type => "longtext", multiple => 1 }
];

return $fields;
}



######################################################################
#
# set_eprint_defaults( $data , $session )
# set_user_defaults( $data , $session )
# set_document_defaults( $data , $session )
# set_subscription_defaults( $data , $session )
#
######################################################################
# $data 
# - reference to HASH mapping 
#      fieldname string
#   to
#      metadata value structure (see docs)
# $session 
# - the session object
# $eprint 
# - (only for set_document_defaults) this is the
#   eprint to which this document will belong.
#
# returns: nothing (Modify $data instead)
#
######################################################################
# These methods allow you to set some default values when things
# are created. This is useful if you skip stages in the submission 
# form or just want to set a default.
#
######################################################################

sub set_eprint_defaults
{
	my( $data, $session ) = @_;
}

sub set_user_defaults
{
	my( $data, $session ) = @_;
	$data->{os} = "unspec";
}

sub set_document_defaults
{
	my( $data, $session, $eprint ) = @_;

	$data->{security} = "";
	$data->{language} = $session->get_langid();
}

sub set_subscription_defaults
{
	my( $data, $session ) = @_;
}


######################################################################
#
# set_eprint_automatic_fields( $eprint )
# set_user_automatic_fields( $user )
# set_document_automatic_fields( $doc )
# set_subscription_automatic_fields( $subscription )
#
######################################################################
# $eprint/$user/$doc/$subscription 
# - the object to be modified
#
# returns: nothing (Modify the object instead).
#
######################################################################
# These methods are called every time commit is called on an object
# (commit writes it back into the database)
# These methods allow you to read and modify fields just before this
# happens. There are a number of uses for this. One is to encrypt 
# passwords as "secret" fields are only set if they are being changed
# otherwise they are empty. Another is to create fields which the
# submitter can't edit directly but you want to be searchable. eg.
# Number of authors.
#
######################################################################

sub set_eprint_automatic_fields
{
	my( $eprint ) = @_;
}

sub set_user_automatic_fields
{
	my( $user ) = @_;

	# Because password is a "secret" field, it is only set if it
	# is being changed - therefor if it's set we need to crypt
	# it. This could do something different like MD5 it (if you have
	# the appropriate authentication module.)
	# It could even access an external system to set the password
	# there and then set the value inside this system to undef.
	if( $user->get_value( "password" ) )
	{
		my @saltset = ('a'..'z', 'A'..'Z', '0'..'9', '.', '/');
		my $pass = $user->get_value( "password" );
		my $salt = $saltset[time % 64] . $saltset[(time/64)%64];
		my $cryptpass = crypt($pass,$salt);
		$user->set_value( "password", $cryptpass );
	}
}

sub set_document_automatic_fields
{
	my( $doc ) = @_;
}

sub set_subscription_automatic_fields
{
	my( $subscription ) = @_;
}

######################################################################
#
# update_submitted_eprint( $eprint )
#
#  This function is called on an EPrint whenever it is transferred
#  from the inbox (the author's workspace) to the submission buffer.
#  You can alter the EPrint here if you need to, or maybe send a
#  notification mail to the administrator or something. 
#
#  Any changes you make to the EPrint object will be written to the
#  database after this function finishes, so you don't need to do a
#  commit().
#
#  This method is also called if the eprint is moved into the buffer
#  from the archive. (By an editor wanting to make changes, presumably)
#
######################################################################

sub update_submitted_eprint
{
	my( $eprint ) = @_;
}


######################################################################
#
# update_archived_eprint( $eprint )
#
#  This function is called on an EPrint whenever it is transferred
#  from the submission buffer to the real archive (i.e. when it is
#  actually "archived".)
#
#  You can alter the EPrint here if you need to, or maybe send a
#  notification mail to the author or administrator or something. 
#
#  Any changes you make to the EPrint object will be written to the
#  database after this function finishes, so you don't need to do a
#  commit().
#
######################################################################

sub update_archived_eprint
{
	my( $eprint ) = @_;
}

# Return true to indicate the module loaded OK.
1;
