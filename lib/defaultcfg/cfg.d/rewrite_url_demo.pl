
# This is a simple demo to show how to add code to redirect certain URLs,
# or to do more clever stuff too.

# EPrints will stop working through the triggers if EP_TRIGGER_DONE is 
#   returned.
# EPrints will stop processing the request if the $o{return_code} is set at 
#   the end of the triggers.

# $c->add_trigger( EP_TRIGGER_URL_REWRITE, sub {
#	my( %o ) = @_;
#
#	if( $o{uri} eq $o{urlpath}."/testpath" )
#	{
#		${$o{return_code}} = EPrints::Apache::Rewrite::redir( $o{request}, "http://totl.net/" );
#		return EP_TRIGGER_DONE;
#	}
# } );

