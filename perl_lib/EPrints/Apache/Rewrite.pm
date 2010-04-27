######################################################################
#
# EPrints::Apache::Rewrite
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

B<EPrints::Apache::Rewrite> - rewrite cosmetic URL's to internally useful ones.

=head1 DESCRIPTION

This rewrites the URL apache receives based on certain things, such
as the current language.

Expands 
/archive/00000123/*
to 
/archive/00/00/01/23/*

and so forth.

This should only ever be called from within the mod_perl system.

This also causes some pages to be regenerated on demand, if they are stale.

=over 4

=cut

package EPrints::Apache::Rewrite;

use EPrints::Apache::AnApache; # exports apache constants

use Data::Dumper;

use strict;
  
sub handler 
{
	my( $r ) = @_;

	my $repoid = $r->dir_config( "EPrints_ArchiveID" );
	return if !$repoid;

	if( defined $EPrints::HANDLE )
	{
		$EPrints::HANDLE->init_from_request( $r );
	}
	else
	{
		EPrints->abort( __PACKAGE__."::handler was called before EPrints was initialised (you may need to re-run generate_apacheconf)" );
	}

	my $repository = $EPrints::HANDLE->current_repository();
	if( !defined $repository )
	{
		EPrints->abort( "'$repoid' is not a valid repository identifier:\nPerlSetVar EPrints_ArchiveID $repoid" );
	}

	my $esec = $r->dir_config( "EPrints_Secure" );
	my $secure = (defined $esec && $esec eq "yes" );
	my $urlpath;
	my $cgipath;
	if( $secure ) 
	{ 
		$urlpath = $repository->get_conf( "https_root" );
		$cgipath = $repository->get_conf( "https_cgiroot" );
	}
	else
	{ 
		$urlpath = $repository->get_conf( "http_root" );
		$cgipath = $repository->get_conf( "http_cgiroot" );
	}

	my $uri = $r->uri;
	{
		use bytes;
		if( $uri =~ /\xc3/ )
		{
			utf8::decode($uri);
		}
		else
		{
			$uri = Encode::decode( "iso-8859-1", $uri );
		}
	}

	# Not an EPrints path (only applies if we're in a non-standard path)
	if( $uri !~ /^(?:$urlpath)|(?:$cgipath)/ )
	{
		return DECLINED;
	}

	# Non-EPrints paths within our tree
	my $exceptions = $repository->config( 'rewrite_exceptions' );
	$exceptions = [] if !defined $exceptions;
	foreach my $exppath ( @$exceptions )
	{
		next if $exppath eq '/cgi/'; # legacy
		next if $exppath eq '/archive/'; # legacy
		return DECLINED if( $uri =~ m/^$exppath/ );
	}

	# database needs updating
	if( $r->is_initial_req && !$repository->get_database->is_latest_version )
	{
		my $msg = "Database schema is out of date: ./bin/epadmin upgrade ".$repository->get_id;
		$repository->log( $msg );
		EPrints::Apache::AnApache::send_status_line( $r, 500, "EPrints Database schema is out of date" );
		return 500;
	}

	# 404 handler
	$r->custom_response( Apache2::Const::NOT_FOUND, $repository->current_url( path => "cgi", "handle_404" ) );

	my $args = $r->args;
	$args = "" if !defined $args;
	$args = "?$args" if length($args);

	my $lang = EPrints::Session::get_session_language( $repository, $r );

	# /archive/ redirect
	if( $uri =~ m! ^$urlpath/archive/(.*) !x )
	{
		return redir( $r, "$urlpath/$1$args" );
	}

	# don't respond to anything containing '..' or '/.'
	if( $uri =~ /\.\./ || $uri =~ /\/\./ )
	{
		return DECLINED;
	}

	# /perl/ redirect
	my $perlpath = $cgipath;
	$perlpath =~ s! /cgi\b ! /perl !x;
	if( $uri =~ s! ^$perlpath !!x )
	{
		return redir( $r, "$cgipath$uri$args" );
	}

	# CGI
	if( $uri =~ s! ^$cgipath !!x )
	{
		# redirect secure stuff
		if( $repository->config( "securehost" ) && !$secure && $uri =~ s! ^/(
			(?:users/)|
			(?:change_user)|
			(?:confirm)|
			(?:register)|
			(?:reset_password)|
			(?:set_password)
			) !!x )
		{
			my $https_redirect = $repository->current_url(
				scheme => "https", 
				host => 1,
				path => "cgi",
				"$1$uri" ) . $args;
			return redir( $r, $https_redirect );
		}

		if( $repository->config( "use_mimetex" ) && $uri eq "mimetex.cgi" )
		{
			$r->handler('cgi-script');
			$r->filename( $repository->config( "executables", "mimetex" ) );
			return OK;
		}

		$r->filename( EPrints::Config::get( "cgi_path" ).$uri );

		# !!!Warning!!!
		# If path_info is defined before the Response stage Apache will
		# attempt to find the file identified by path_info using an internal
		# request (presumably to get the content-type). We don't want that to
		# happen so we delay setting path_info until just before the response
		# is generated.
		my $path_info;
		# strip the leading '/'
		my( undef, @parts ) = split m! /+ !x, $uri;
		PATH: foreach my $path (
				$repository->config( "cgi_path" ),
				EPrints::Config::get( "cgi_path" ),
			)
		{
			for(my $i = $#parts; $i >= 0; --$i)
			{
				my $filename = join('/', $path, @parts[0..$i]);
				if( -f $filename )
				{
					$r->filename( $filename );
					$path_info = join('/', @parts[$i+1..$#parts]);
					$path_info = '/' . $path_info if length($path_info);
					last PATH;
				}
			}
		}

		if( $uri =~ m! ^/users\b !x )
		{
			$r->push_handlers(PerlAccessHandler => [
				\&EPrints::Apache::Auth::authen,
				\&EPrints::Apache::Auth::authz
				] );
		}

		$r->handler('perl-script');

		$r->set_handlers(PerlResponseHandler => [
			# set path_info for the CGI script
			sub { $_[0]->path_info( $path_info ); DECLINED },
			'ModPerl::Registry'
			]);

		return OK;
	}

	# SWORD-APP
	if( $uri =~ s! ^$urlpath/sword-app/ !!x )
	{
		$r->handler( 'perl-script' );

		$r->set_handlers( PerlMapToStorageHandler => sub { OK } );

		if( $uri =~ s! ^atom\b !!x )
		{
			$r->set_handlers( PerlResponseHandler => [ 'EPrints::Sword::AtomHandler' ] );
		}
		elsif( $uri =~ s! ^deposit\b !!x )
		{
			$r->set_handlers( PerlResponseHandler => [ 'EPrints::Sword::DepositHandler' ] );
		}
		elsif( $uri =~ s! ^servicedocument\b !!x )
		{
			$r->set_handlers( PerlResponseHandler => [ 'EPrints::Sword::ServiceDocument' ] );
		}
		else
		{
			return NOT_FOUND;
		}
	}

	# REST
	if( $uri =~ m! ^$urlpath/rest !x )
	{
		$r->handler( 'perl-script' );

		$r->set_handlers( PerlMapToStorageHandler => sub { OK } );

	 	$r->set_handlers(PerlResponseHandler => \&EPrints::Apache::REST::handler );
		return OK;
	}

	# URI redirection
	if( $uri =~ m! ^$urlpath/id/repository$ !x )
	{
		my $accept = EPrints::Apache::AnApache::header_in( $r, "Accept" );
		$accept = "application/rdf+xml" unless defined $accept;

		my $plugin = content_negotiate_best_plugin( 
			$repository, 
			accept_header => $accept,
			consider_summary_page => 0,
			plugins => [$repository->plugin_list(
				type => "Export",
				is_visible => "all",
				can_accept => "list/triple" )]
		);
		
		if( !defined $plugin )  { return NOT_FOUND; }

		my $url = $repository->config( "http_cgiurl" )."/export/repository/".
			$plugin->get_subtype."/".$repository->get_id.$plugin->param("suffix");

		return redir_see_other( $r, $url );
	}

	if( $uri =~ m! ^$urlpath/id/x-(.*)$ !x )
	{
		my $id = $1;
		my $accept = EPrints::Apache::AnApache::header_in( $r, "Accept" );
		$accept = "application/rdf+xml" unless defined $accept;

		my $plugin = content_negotiate_best_plugin( 
			$repository, 
			accept_header => $accept,
			consider_summary_page => 0,
			plugins => [$repository->plugin_list(
				type => "Export",
				is_visible => "all",
				can_accept => "list/triple" )]
		);

		if( !defined $plugin )  { return NOT_FOUND; }

		my $fn = $id;
		$fn=~s/\//_/g;
		my $url = $repository->config( "http_cgiurl" )."/export/x-".
			$id."/".$plugin->get_subtype."/$fn".$plugin->param("suffix");

		return redir_see_other( $r, $url );
	}

	if( $uri =~ m! ^$urlpath/id/([^/]+)/(.*)$ !x )
	{
		my( $datasetid, $id ) = ( $1, $2 );

		my $dataset = $repository->get_dataset( $datasetid );
		my $item;
		if( defined $dataset )
		{
			$item = $dataset->dataobj( $id );
		}

		if( defined $item )
		{
			# Subject URI's redirect to the top of that particular subject tree
			# rather than the node in the tree. (the ancestor with "ROOT" as a parent).
			if( $item->dataset->id eq "subject" )
			{
				ANCESTORS: foreach my $anc_subject_id ( @{$item->get_value( "ancestors" )} )
				{
					my $anc_subject = $repository->dataset("subject")->dataobj($anc_subject_id);
					next ANCESTORS if( !$anc_subject );
					next ANCESTORS if( !$anc_subject->is_set( "parents" ) );
					foreach my $anc_subject_parent_id ( @{$anc_subject->get_value( "parents" )} )
					{
						if( $anc_subject_parent_id eq "ROOT" )
						{
							$item = $anc_subject;
							last ANCESTORS;
						}
					}
				}
			}

			if( $item->dataset->confid eq "eprint" && $item->dataset->id ne "archive" )
			{
				return redir_see_other( $r, $item->get_control_url );
			}

			# content negotiation. Only worries about type, not charset
			# or language etc. at this stage.
			#
			my $accept = EPrints::Apache::AnApache::header_in( $r, "Accept" );
			$accept = "text/html" unless defined $accept;

			my $match = content_negotiate_best_plugin( 
				$repository, 
				accept_header => $accept,
				consider_summary_page => ( $dataset->confid eq "eprint" ? 1 : 0 ),
				plugins => [$repository->plugin_list(
					type => "Export",
					is_visible => "all",
					can_accept => "dataobj/".$dataset->confid )],
			);

			if( $match eq "DEFAULT_SUMMARY_PAGE" )
			{
				return redir_see_other( $r, $item->get_url );
			}
			else
			{
				my $url = $match->dataobj_export_url( $item );	
				if( defined $url )
				{
					return redir_see_other( $r, $url );
				}
			}
		}	

		return NOT_FOUND;
	}

	# /XX/ eprints
	if( $uri =~ s! ^$urlpath/(0*)([1-9][0-9]*)\b !!x )  # ignore leading 0s
	{
		# It's an eprint...
	
		my $eprintid = $2;
		my $eprint = $repository->dataset( "eprint" )->dataobj( $eprintid );
		if( !defined $eprint )
		{
			return NOT_FOUND;
		}

		# redirect to canonical path - /XX/
		if( length($1) || !length($uri) )
		{
			return redir( $r, "$urlpath/$eprintid/$uri$args" );
		}

		if( $uri =~ s! ^/(0*)([1-9][0-9]*)\b !!x )
		{
			# It's a document....			

			my $pos = $2;
			my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos( $repository, $eprintid, $pos );
			if( !defined $doc )
			{
				return NOT_FOUND;
			}

			if( length($1) || !length($uri) )
			{
				return redir( $r, "$urlpath/$eprintid/$pos/$uri$args" );
			}

			$uri =~ s! ^([^/]*)/ !!x;
			my @relations = grep { length($_) } split /\./, $1;

			my $filename = $uri;

			$r->pnotes( eprint => $eprint );
			$r->pnotes( document => $doc );
			$r->pnotes( dataobj => $doc );
			$r->pnotes( filename => $filename );

			$r->handler('perl-script');

			# no real file to map to
			$r->set_handlers(PerlMapToStorageHandler => sub { OK } );

			$r->push_handlers(PerlAccessHandler => [
				\&EPrints::Apache::Auth::authen_doc,
				\&EPrints::Apache::Auth::authz_doc
				] );

		 	$r->set_handlers(PerlResponseHandler => \&EPrints::Apache::Storage::handler );

			$r->push_handlers( PerlCleanupHandler => \&EPrints::Apache::LogHandler::document );

			$repository->run_trigger( EPrints::Const::EP_TRIGGER_DOC_REWRITE,
				request => $r,
				eprint => $eprint,
				document => $doc,
				filename => $filename,
				relations => \@relations,
			);

			# a trigger has set an error code
			return $r->status if $r->status != 200;
		}
		# OK, It's the EPrints abstract page (or something whacky like /23/fish)
		else
		{
			my $path = "/archive/" . $eprint->store_path();
			EPrints::Update::Abstract::update( $repository, $lang, $eprint->id, $path );

			if( $uri =~ m! /$ !x )
			{
				$uri .= "index.html";
			}
			$r->filename( $eprint->_htmlpath( $lang ) . $uri );

			if( $uri =~ /\.html$/ )
			{
				$r->pnotes( eprint => $eprint );

				$r->handler('perl-script');
				$r->set_handlers(PerlResponseHandler => [ 'EPrints::Apache::Template' ] );

				# log abstract hits
				$r->push_handlers(PerlCleanupHandler => \&EPrints::Apache::LogHandler::eprint );
			}
		}

		return OK;
	}

	# apache 2 does not automatically look for index.html so we have to do it ourselves
	my $localpath = $uri;
	$localpath =~ s! ^$urlpath !!x;
	if( $uri =~ m! /$ !x )
	{
		$localpath.="index.html";
	}
	$r->filename( $repository->get_conf( "htdocs_path" )."/".$lang.$localpath );

	if( $uri =~ m! ^$urlpath/view(.*) !x )
	{
		$uri =~ s! ^$urlpath !!x;
		# redirect /foo to /foo/ 
		if( $uri eq "/view" || $uri =~ m! ^/view/[^/]+$ !x )
		{
			return redir( $r, "$uri/" );
		}

		local $repository->{preparing_static_page} = 1; 
		my $filename = EPrints::Update::Views::update_view_file( $repository, $lang, $localpath, $uri );
		return NOT_FOUND if( !defined $filename );

		$r->filename( $filename );
	}
	else
	{
		local $repository->{preparing_static_page} = 1; 
		EPrints::Update::Static::update_static_file( $repository, $lang, $localpath );
	}

	if( $r->filename =~ /\.html$/ )
	{
		$r->handler('perl-script');
		$r->set_handlers(PerlResponseHandler => [ 'EPrints::Apache::Template' ] );
	}

	return OK;
}

sub redir
{
	my( $r, $url ) = @_;

	EPrints::Apache::AnApache::send_status_line( $r, 302, "Found" );
	EPrints::Apache::AnApache::header_out( $r, "Location", $url );
	EPrints::Apache::AnApache::send_http_header( $r );
	return DONE;
} 

sub redir_see_other
{
	my( $r, $url ) = @_;

	EPrints::Apache::AnApache::send_status_line( $r, 303, "See Other" );
	EPrints::Apache::AnApache::header_out( $r, "Location", $url );
	EPrints::Apache::AnApache::send_http_header( $r );
	return DONE;
} 

sub content_negotiate_best_plugin
{
	my( $repository, %o ) = @_;

	EPrints::Utils::process_parameters( \%o, {
		accept_header => "*REQUIRED*",
		consider_summary_page => 1, 
		plugins => "*REQUIRED*",
	 } );

	my $pset = {};
	if( $o{consider_summary_page} )
	{
		$pset->{"text/html"} = { qs=>0.99, DEFAULT_SUMMARY_PAGE=>1 };
	}

	foreach my $a_plugin_id ( @{$o{plugins}} )
	{
		my $a_plugin = $repository->plugin( $a_plugin_id );
		my( $type, %params ) = split( /\s*[;=]\s*/, $a_plugin->{mimetype} );
	
		next if( defined $pset->{$type} && $pset->{$type}->{qs} >= $a_plugin->{qs} );
		$pset->{$type} = $a_plugin;
	}
	my @pset_order = sort { $pset->{$b}->{qs} <=> $pset->{$a}->{qs} } keys %{$pset};

	my $accepts = { "*/*" => { q=>0.000001 }};
	CHOICE: foreach my $choice ( split( /\s*,\s*/, $o{accept_header} ) )
	{
		my( $mime, %params ) = split( /\s*[;=]\s*/, $choice );
		$params{q} = 1 unless defined $params{q};
		$accepts->{$mime} = \%params;
	}
	my @acc_order = sort { $accepts->{$b}->{q} <=> $accepts->{$a}->{q} } keys %{$accepts};

	my $match;
	CHOICE: foreach my $choice ( @acc_order )
	{
		if( $pset->{$choice} ) 
		{
			$match = $pset->{$choice};
			last CHOICE;
		}

		if( $choice eq "*/*" )
		{
			$match = $pset->{$pset_order[0]};
			last CHOICE;
		}

		if( $choice =~ s/\*[^\/]+$// )
		{
			foreach my $type ( @pset_order )
			{
				if( $choice eq substr( $type, 0, length $type ) )
				{
					$match = $pset->{$type};
					last CHOICE;
				}
			}
		}
	}

	if( $match->{DEFAULT_SUMMARY_PAGE} )
	{
		return "DEFAULT_SUMMARY_PAGE";
	}

	return $match; 
}


1;


