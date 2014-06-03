#
# sf2 - previously known as Apache::Rewrite
# 
# Web requests handler
# 
# Refer to the old Apache::Rewrite to re-implement missing features / controllers.
#

package EPrints::Apache::Handler;

use EPrints::Apache;	 # exports apache constants

use strict;
  
sub handler 
{
	my( $r ) = @_;

	# sf2 - set by cfg/apache/<repoid>.conf
	my $repoid = $r->dir_config( "EPrints_ArchiveID" );
	return DECLINED if !$repoid;

	if( defined $EPrints::HANDLE )
	{
		$EPrints::HANDLE->init_from_request( $r );
	}
	else
	{
		EPrints->abort( __PACKAGE__."::handler was called before EPrints was initialised (you may need to re-run generate_apacheconf)" );
	}

	my $repo = $EPrints::HANDLE->current_repository();
	if( !defined $repo )
	{
		EPrints->abort( "'$repoid' is not a valid repository identifier:\nPerlSetVar EPrints_ArchiveID $repoid" );
	}

# sf2 - removed $secure (derived from $repo->is_secure)
# sf2 - removed $cgi_path since CGI are gone

	# if the repo is under e.g. /mediabank/
	my $urlpath = $repo->is_secure ? $repo->config( "https_root" ) : $repo->config( "http_root" );

	my $uri = $r->uri;
	{
		$uri = eval { Encode::decode_utf8( $uri ) };
		$uri = Encode::decode( "iso-8859-1", $uri ) if $@; # utf-8 failed
	}
	
	# don't respond to anything containing '/.'
	if( $uri =~ /\/\./ )
	{
		return DECLINED;
	}

	# Not an EPrints path (only applies if we're in a non-standard path)
	if( $uri !~ /^(?:$urlpath)/ )
	{
		return DECLINED;
	}

# sf2 - removed rewrite_exceptions

# sf2 - removed db_check (is_latest_version), done by $repo when creating a DB connection

# sf2 - removed custom 404 handler (too UI-y)

	my $args = $r->args;
	$args = "" if !defined $args;
	$args = "?$args" if length($args);

	my $lang = $repo->get_lang->get_id;


# - request is derived from repo: $repo->request
# - lang same $repo->get_lang->get_id
# - args: well is that useful
# - urlpath: derived from repo??
# - cgipath: CGI is gone
# - uri: can keep i suppose
# - secure: $repo->is_secure
# - return_code: must keep

	my $rc = undef;
	$repo->run_trigger( EPrints::Const::EP_TRIGGER_REQUEST_PROCESSING,
		request => $r,
		   lang => $lang,    # en
		   args => $args,    # "" or "?foo=bar"
		urlpath => $urlpath, # "" or "/subdir"
		    uri => $uri,     # /foo/bar
            return_code => \$rc,     # set to trigger a return
	);
	# if the trigger has set an return code
	return $rc if defined $rc;

	$repo->debug_log( "request", "processing %s %s", $r->method, $uri );

	$repo->debug_log( "controllers", "calling request controllers..." );


########### Controller Plug-ins - test ###############
	
	# removes any URL prefixes (e.g. if EPrints is under /eprints/)
	$uri =~ s/^$urlpath//g;
	
	my %params = (	
		repository => $repo,	# needed? should be passed to any plug-in
		request => $r,
		   lang => $lang,    # en
		   args => $args,    # "" or "?foo=bar"
		urlpath => $urlpath, # "" or "/subdir"
		    uri => $uri,     # /foo/bar
            return_code => \$rc,     # set to trigger a return
	);

        my @plugins = $repo->get_plugins( 
		\%params,
                type => "Controller",
		can_process => $uri 
	);

	# order by priority
	if( scalar( @plugins ) > 1 )
	{
		@plugins = sort {
			$a->param( 'priority' ) <=> $b->param( 'priority' )
		} @plugins;
	}

	my $plugin = shift @plugins;

	if( defined $plugin )
	{
		$repo->debug_log( "request", "using controller %s", $plugin->get_id );

		$rc = $plugin->init;

		# init phase may fail in which case we can return early (ie now)
		if( $rc != EPrints::Const::HTTP_OK )
		{
			return $rc;
		}

                $r->handler( 'perl-script' );
                $r->set_handlers( PerlMapToStorageHandler => sub { $plugin->storage } );
                $r->set_handlers( PerlHeaderParserHandler => sub { $plugin->header_parser } );
               
		$r->push_handlers(PerlAccessHandler => [
					sub { $plugin->auth },
					sub { $plugin->authz },
		] );

		$r->set_handlers( PerlResponseHandler => sub { $plugin->response } );

		$repo->debug_log( "request", "request passed on to Perl Handlers" );

		return OK;
	}

	$repo->debug_log( "request", "nothing to do" );
	return OK;


########### Controller Plug-ins - test/END ###############




	$repo->run_trigger( EPrints::Const::EP_TRIGGER_REQUEST_CONTROLLER,
		request => $r,
		   lang => $lang,    # en
		   args => $args,    # "" or "?foo=bar"
		urlpath => $urlpath, # "" or "/subdir"
		    uri => $uri,     # /foo/bar
            return_code => \$rc,     # set to trigger a return
	);
	# if the trigger has set an return code
	if( defined $rc )
	{
		return $rc;
	}


# sf2 - removed:
#
#	EPrints::Const::EP_TRIGGER_URL_REWRITE
#	/cgi/, /cgi/*
#	SWORD handler (service document)
#	/robots.txt
#	/sitemap.xml
#	REST - /rest/
#	RDF - /id/(repository|dump)
#	CRUD - /id/ - moved to a controller in /lib/cfg.d/
#	EPrints summary pages and documents - /\d+/...

	$repo->debug_log( "request", "nothing to do" );
	return OK;
}

=pod

=cut


1;



=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

