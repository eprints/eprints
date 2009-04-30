
######################################################################
#
# Web Sign-up customisation
#
######################################################################

# Allow users to sign up for an account on
# the web.
# NOTE: If you disable this you should edit the template file 
#   cfg/template-en.xml
# and the error page 
#   cfg/static/en/error401.xpage 
# to remove the links to web registration.
$c->{allow_web_signup} = 1;

# Set this to "minimal" to allow minimal user accounts -
# users can set up alerts but not deposit
$c->{signup_style} = "full";

# Allow users to change their password via the web?
# You may wish to disable this if you import passwords from an
# external system or use LDAP.
$c->{allow_reset_password} = 1;

# in addition to the required username, email and password.
# "lang" may be useful if this is a multilingual archive.
$c->{user_registration_fields} = [ "name" ];

# The type of user that gets created when someone signs up
# over the web. This can be modified after they sign up by
# staff with the right priv. set. 
$c->{default_user_type} = "user";
#$c->{default_user_type} = "minuser";

# This function allows you to allow/deny sign-ups from
# particular email domains 
#$c->{check_registration_email} = sub
#{
#	my( $session, $email ) = @_;
#
#	# registration allowed
#	return 1 if $email =~ /\@your\.domain\.com$/;
#
#	return 0; # registration denied
#}

