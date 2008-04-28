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

	my $repository_id = $r->dir_config( "EPrints_ArchiveID" );
	if( !defined $repository_id )
	{
		return DECLINED;
	}
	my $repository = EPrints::Repository->new( $repository_id );
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

	my $lang = EPrints::Session::get_session_language( $repository, $r );
	my $args = $r->args;
	if( $args ne "" ) { $args = '?'.$args; }

	# Skip rewriting the /cgi/ path and any other specified in
	# the config file.
	my $econf = $repository->get_conf('rewrite_exceptions');
	my @exceptions = ();
	if( defined $econf ) { @exceptions = @{$econf}; }
	push @exceptions,
		$cgipath,
		"$urlpath/thumbnails/";

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
	if( $uri =~ m!^$urlpath/id/([^/]+)/(.*)$! )
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
			$url = $item->get_url;
		}
		$session->terminate;
		if( defined $url )
		{
			return redir( $r, $url );
		}
	}

	if( $uri =~ m#^/([0-9]+)(.*)$# )
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

		my $thumbnails = 0;
		$thumbnails = 1 if( $tail =~ s/^\/thumbnails// );

		if( $tail =~ s/^\/(\d+)// )
		{
			# it's a document....			

			my $pos = $1;
			if( $tail eq "" || $pos ne $pos+0 )
			{
				$tail = "/" if $tail eq "";
				return redir( $r, sprintf( "%s/%d/%d%s",$urlpath, $eprintid, $pos, $tail ).$args );
			}

			my $filename = $tail;
			$filename =~ s/^\/+//;

			$r->pnotes( datasetid => "document" );
			$r->pnotes( eprintid => $eprintid );
			$r->pnotes( pos => $pos );
			$r->pnotes( bucket => ($thumbnails ? "thumbnail" : "data" ) );
			$r->pnotes( filename => $filename );

		 	$r->set_handlers(PerlResponseHandler => \&EPrints::Apache::Storage::handler );

			return DECLINED;
		}
	
		# OK, It's the EPrints abstract page (or something whacky like /23/fish)
		EPrints::Update::Abstract::update( $repository, $lang, $eprintid, $uri );
	}

	# apache 2 does not automatically look for index.html so we have to do it ourselves
	my $localpath = $uri;
	if( $uri =~ m#/$# )
	{
		$localpath.="index.html";
	}
	$r->filename( $repository->get_conf( "htdocs_path" )."/".$lang.$localpath );

	if( $uri =~ m#^/view(.*)# )
	{
		my $session = new EPrints::Session(2); # don't open the CGI info
		EPrints::Update::Views::update_view_file( $session, $lang, $localpath, $uri );
		$session->terminate;
	}
	else
	{
		EPrints::Update::Static::update_static_file( $repository, $lang, $localpath );
	}

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


