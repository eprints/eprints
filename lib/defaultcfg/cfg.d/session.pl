

######################################################################
#
# session_init( $repository, $offline )
#
#  Invoked each time a new repository is needed (generally one per
#  script invocation.) $repository is a repository object that can be used
#  to store any values you want. To prevent future clashes, prefix
#  all of the keys you put in the hash with repository.
#
#  If $offline is non-zero, the repository is an `off-line' repository, i.e.
#  it has been run as a shell script and not by the web server.
#
######################################################################

$c->{session_init} = sub
{
	my( $repository, $offline ) = @_;
};


######################################################################
#
# session_close( $repository )
#
#  Invoked at the close of each repository. Here you should clean up
#  anything you did in session_init().
#
######################################################################

$c->{session_close} = sub
{
	my( $repository ) = @_;
};

######################################################################
#
# email_for_doc_request( $repository, $eprint )
#
#  Invoked to determine the contact email address for an eprint. Used
#  by the "request documents" feature
#
######################################################################
