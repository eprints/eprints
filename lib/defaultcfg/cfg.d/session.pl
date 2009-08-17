

######################################################################
#
# session_init( $handle, $offline )
#
#  Invoked each time a new session is needed (generally one per
#  script invocation.) $handle is a session object that can be used
#  to store any values you want. To prevent future clashes, prefix
#  all of the keys you put in the hash with repository.
#
#  If $offline is non-zero, the session is an `off-line' session, i.e.
#  it has been run as a shell script and not by the web server.
#
######################################################################

$c->{session_init} = sub
{
	my( $handle, $offline ) = @_;
};


######################################################################
#
# session_close( $handle )
#
#  Invoked at the close of each session. Here you should clean up
#  anything you did in session_init().
#
######################################################################

$c->{session_close} = sub
{
	my( $handle ) = @_;
};

######################################################################
#
# email_for_doc_request( $handle, $eprint )
#
#  Invoked to determine the contact email address for an eprint. Used
#  by the "request documents" feature
#
######################################################################
