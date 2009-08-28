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

	my $repository_id = $r->dir_config( "EPrints_ArchiveID" );
	if( !defined $repository_id )
	{
		return DECLINED;
	}
	my $repository = EPrints->get_repository_config( $repository_id );
	$repository->check_secure_dirs( $r );
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

	my $lang = EPrints::RepositoryHandle::get_language( $repository, $r );
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

	# URI redirection
	if( $uri =~ m! ^$urlpath/id/([^/]+)/(.*)$ !x )
	{
		my( $datasetid, $id ) = ( $1, $2 );

		my $dataset = $repository->get_dataset( $datasetid );
		my $item;
		my $handle = EPrints->get_repository_handle( consume_post_data=>0 );
		if( defined $dataset )
		{
			$item = $dataset->get_object( $handle, $id );
		}
		my $url;
		if( defined $item )
		{
			$url = $item->get_url;
		}
		$handle->terminate;
		if( defined $url )
		{
			return redir( $r, $url );
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

	my $handle = EPrints->get_repository_handle( consume_post_data=>0 );
	$handle->{preparing_static_page} = 1; 
	if( $uri =~ m! ^/view(.*) !x )
	{
		my $filename = EPrints::Update::Views::update_view_file( $handle, $lang, $localpath, $uri );
		$r->filename( $filename );
	}
	else
	{
		EPrints::Update::Static::update_static_file( $handle, $lang, $localpath );
	}
	delete $handle->{preparing_static_page};
	$handle->terminate;

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



1;


