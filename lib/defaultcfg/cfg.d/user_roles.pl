
######################################################################
#
# User Roles
#
#  Here you can configure which different types of user are 
#  parts of the system they are allowed to use.
#
######################################################################

	
$c->{user_roles}->{user} = [qw/
	general
	edit-own-record
	saved-searches
	set-password
	deposit
	change-email
/],

$c->{user_roles}->{editor} = [qw/
	general
	edit-own-record
	saved-searches
	set-password
	deposit
	change-email
	editor
	view-status
	staff-view
/],

$c->{user_roles}->{admin} = [qw{
	general
	edit-own-record
	saved-searches
	set-password
	deposit
	change-email
	editor
	view-status
	staff-view
	admin
	edit-config
}],
# Note -- nobody has the very powerful "toolbox" role by default!

$c->{user_roles}->{minuser} = [qw/
	general
	edit-own-record
	saved-searches
	set-password
	lock-username-to-email
/];
