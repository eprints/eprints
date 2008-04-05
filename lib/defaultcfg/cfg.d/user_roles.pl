
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

# If you want to add additional roles to the system, you can do it here.
# These can be useful to create "hats" which can be given to a user via
# the roles field. You can also override the default roles.
#
#$c->{roles}->{"approve-hat"} = {
#	"eprint/buffer/view" => 8,
#	"eprint/buffer/summary" => 8,
#	"eprint/buffer/details" => 8,
#	"eprint/buffer/move_archive" => 8,
#};


