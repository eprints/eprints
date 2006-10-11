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

=over 4

=cut

package EPrints::Apache::Rewrite;

use EPrints::Apache::AnApache; # exports apache constants

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
	my $esec = $r->dir_config( "EPrints_Secure" );
	my $secure = (defined $esec && $esec eq "yes" );
	my $urlpath;
	if( $secure ) 
	{ 
		$urlpath = $repository->get_conf( "securepath" );
	}
	else
	{ 
		$urlpath = $repository->get_conf( "urlpath" );
	}

	my $uri = $r->uri;
	my $lang = EPrints::Session::get_session_language( $repository, $r );
	my $args = $r->args;
	if( $args ne "" ) { $args = '?'.$args; }

	# REMOVE the urlpath if any!
	unless( $uri =~ s#^$urlpath## )
	{
		return DECLINED;
	}

	# Skip rewriting the /perl/ path and any other specified in
	# the config file.
	my $econf = $repository->get_conf('rewrite_exceptions');
	my @exceptions = ( '/cgi/' );
	if( defined $econf ) { @exceptions = @{$econf}; }
	push @exceptions, '/perl/';

	my $securehost = $repository->get_conf( "securehost" );
	if( EPrints::Utils::is_set( $securehost ) && !$secure )
	{
		# If this repository has secure mode but we're not
		# on the https site then skip /secure/ to let
		# it just get rediected to the secure site.
		push @exceptions, '/secure/';
	}
	


	foreach my $exppath ( @exceptions )
	{
		return DECLINED if( $uri =~ m/^$exppath/ );
	}
	
	# shorturl does not (yet) effect secure docs.
	if( $uri =~ s#^/secure/([0-9]+)([0-9][0-9])([0-9][0-9])([0-9][0-9])#/secure/$1/$2/$3/$4# )
	{
		$r->filename( $repository->get_conf( "htdocs_path" )."/".$uri );
		return OK;
	}


	my $shorturl = $repository->get_conf( "use_short_urls" );
	$shorturl = 0 unless( defined $shorturl );

	#$uri =~ s#^/archive/([0-9]+)([0-9][0-9])([0-9][0-9])([0-9][0-9])#/archive/$1/$2/$3/$4#;
	if( $uri =~ m#^/archive/([0-9]+)(.*)$# )
	{
		# is a long record url
		my $n = $1;
		my $tail = $2;
		my $redir =0;
		if( $tail eq "" ) { $tail = "/"; $redir=1 }
		
		if( $shorturl )
		{
			# redirect to short form
			return redir( $r, sprintf( "%s/%d%s",$urlpath, $n, $tail ).$args );
		}

		my $s8 = sprintf('%08d',$n);
		$s8 =~ m/(..)(..)(..)(..)/;	
		if( length $n < 8 || $redir)
		{
			# not enough zeros, redirect to correct version
			return redir( $r, sprintf( "%s/archive/%08d%s",$urlpath, $n, $tail ).$args );
		}
		$uri = "/archive/$1/$2/$3/$4$tail";
	}

	
	if( $uri =~ m#^/([0-9]+)(.*)$# )
	{
		# is a shorturl record url
		my $n = $1;
		my $tail = $2;
		my $redir = 0;
		if( $tail eq "" ) { $tail = "/"; $redir = 1; }
		if( !$shorturl )
		{
			# redir to long form
			return redir( $r, sprintf( "%s/archive/%08d%s",$urlpath, $n, $tail ).$args);
		} 

		if( ($n + 0) ne $n || $redir)
		{
			# leading zeros
			return redir( $r, sprintf( "%s/%d%s",$urlpath, $n, $tail ).$args );
		}
		my $s8 = sprintf('%08d',$n);
		$s8 =~ m/(..)(..)(..)(..)/;	
		$uri = "/archive/$1/$2/$3/$4$tail";
	}

	# apache 2 does not automatically look for index.html so we have to do it ourselves
	if( $uri =~ m#/$# )
	{
		$r->filename( $repository->get_conf( "htdocs_path" )."/".$lang.$uri."index.html" );
	}
	else
	{
		$r->filename( $repository->get_conf( "htdocs_path" )."/".$lang.$uri );
	}
	$r->set_handlers(PerlResponseHandler =>[ 'EPrints::Apache::Template' ] );

	return OK;
}


sub redir
{
	my( $r, $url ) = @_;

	$r->status_line( "302 Close but no Cigar" );
	EPrints::Apache::AnApache::header_out( $r, "Location", $url );
	EPrints::Apache::AnApache::send_http_header( $r );
	return DONE;
} 



1;


