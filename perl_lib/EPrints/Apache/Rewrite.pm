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

	# don't attempt to rewrite the URI of an internal request
	return DECLINED unless $r->is_initial_req();

	my $repository = $EPrints::HANDLE->current_repository;
	if( !defined $repository )
	{
		return DECLINED;
	}
	if( !$repository->get_database->is_latest_version )
	{
		$repository->log( "Database schema is out of date: ./bin/epadmin upgrade ".$repository->get_id );
		return 500;
	}
#	$repository->check_secure_dirs( $r );
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

	my $lang = EPrints::Session::get_session_language( $repository, $r );
	my $args = $r->args;
	if( defined $args && $args ne "" ) { $args = '?'.$args; }

	# Skip rewriting the /cgi/ path and any other specified in
	# the config file.
	my $econf = $repository->get_conf('rewrite_exceptions');
	my @exceptions = ();
	if( defined $econf ) { @exceptions = @{$econf}; }
	push @exceptions,
		$cgipath,
		"$urlpath/sword-app/";

	foreach my $exppath ( @exceptions )
	{
		return DECLINED if( $uri =~ m/^$exppath/ );
	}

	# if we're not in an EPrints path return
	unless( $uri =~ s/^$urlpath// || $uri =~ s/^$cgipath// )
	{
		return DECLINED;
	}

	# REST

	if( $uri =~ m! ^$urlpath/rest !x )
	{
	 	$r->set_handlers(PerlResponseHandler => \&EPrints::Apache::REST::handler );
		return DECLINED;
	}

	# URI redirection

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
				handles_rdf => 1 )]
		);

		my $fn = $id;
		$fn=~s/\//_/g;
		my $url = $repository->config( "http_cgiurl" )."/exportresource/".
			$id."/".$plugin->get_subtype."/$fn.".$plugin->param("suffix");

		return redir_see_other( $r, $url );
	}

	if( $uri =~ m! ^$urlpath/id/([^/]+)/(.*)$ !x )
	{
		my( $datasetid, $id ) = ( $1, $2 );

		my $dataset = $repository->get_dataset( $datasetid );
		my $item;
		my $session = new EPrints::Session(2); # don't open the CGI info
		if( defined $dataset )
		{
			$item = $dataset->get_object( $session, $id );
		}
		my $url;
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
			# content negotiation. Only worries about type, not charset
			# or language etc. at this stage.
			#
			my $accept = EPrints::Apache::AnApache::header_in( $r, "Accept" );
			$accept = "text/html" unless defined $accept;

			my $match = content_negotiate_best_plugin( 
				$session, 
				accept_header => $accept,
				consider_summary_page => ( $dataset->confid eq "eprint" ? 1 : 0 ),
				plugins => [$repository->plugin_list(
					type => "Export",
					is_visible => "all",
					can_accept => "dataobj/".$dataset->confid )],
			);

			if( $match eq "DEFAULT_SUMMARY_PAGE" )
			{
				$url = $item->get_url;
			}
			else
			{
				$url = $match->dataobj_export_url( $item );	
			}
		}	
		$session->terminate;
		if( defined $url )
		{
			return redir_see_other( $r, $url );
		}
	}

	if( $uri =~ m! ^/([0-9]+)(.*)$ !x )
	{
		# It's an eprint...
	
		my $eprintid = $1;
		my $tail = $2;
		my $redir = 0;
		if( $tail eq "" ) { $tail = "/"; $redir = 1; }

		if( ($eprintid + 0) ne $eprintid || $redir)
		{
			# leading zeros
			return redir( $r, sprintf( "%s/%d%s",$urlpath, $eprintid, $tail ).$args );
		}
		my $s8 = sprintf('%08d',$eprintid);
		$s8 =~ m/(..)(..)(..)(..)/;	
		my $splitpath = "$1/$2/$3/$4";
		$uri = "/archive/$splitpath$tail";

		if( $tail =~ s! ^/([0-9]+) !!x )
		{
			# it's a document....			

			my $pos = $1;
			if( $tail eq "" || $pos ne $pos+0 )
			{
				$tail = "/" if $tail eq "";
				return redir( $r, sprintf( "%s/%d/%d%s",$urlpath, $eprintid, $pos, $tail ).$args );
			}

			$tail =~ s! ^([^/]*)/ !!x;
			my @relations = grep { length($_) } split /\./, $1;

			my $filename = $tail;

			$r->pnotes( datasetid => "document" );
			$r->pnotes( eprintid => $eprintid );
			$r->pnotes( pos => $pos );
			$r->pnotes( relations => \@relations );
			$r->pnotes( filename => $filename );

			$r->pnotes( loghandler => "?fulltext=yes" );

		 	$r->set_handlers(PerlResponseHandler => \&EPrints::Apache::Storage::handler );

			return DECLINED;
		}
	
		$r->pnotes( eprintid => $eprintid );

		$r->pnotes( loghandler => "?abstract=yes" );

		# OK, It's the EPrints abstract page (or something whacky like /23/fish)
		EPrints::Update::Abstract::update( $repository, $lang, $eprintid, $uri );
	}

	# apache 2 does not automatically look for index.html so we have to do it ourselves
	my $localpath = $uri;
	if( $uri =~ m! /$ !x )
	{
		$localpath.="index.html";
	}
	$r->filename( $repository->get_conf( "htdocs_path" )."/".$lang.$localpath );

	my $session = new EPrints::Session(2); # don't open the CGI info
	$session->{preparing_static_page} = 1; 
	if( $uri =~ m! ^/view(.*) !x )
	{
		# redirect /foo to /foo/ 
		if( $uri eq "/view" || $uri =~ m! ^/view/[^/]+$ !x )
		{
			return redir( $r, "$uri/" );
		}

		my $filename = EPrints::Update::Views::update_view_file( $session, $lang, $localpath, $uri );
		return NOT_FOUND if( !defined $filename );

		$r->filename( $filename );
	}
	else
	{
		EPrints::Update::Static::update_static_file( $session, $lang, $localpath );
	}
	delete $session->{preparing_static_page};
	$session->terminate;

	$r->set_handlers(PerlResponseHandler =>[ 'EPrints::Apache::Template' ] );

	return OK;
}

sub redir
{
	my( $r, $url ) = @_;

	EPrints::Apache::AnApache::send_status_line( $r, 302, "Close but no Cigar" );
	EPrints::Apache::AnApache::header_out( $r, "Location", $url );
	EPrints::Apache::AnApache::send_http_header( $r );
	return DONE;
} 

sub redir_see_other
{
	my( $r, $url ) = @_;

	EPrints::Apache::AnApache::send_status_line( $r, 303, "See Elseware" );
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


