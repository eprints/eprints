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
	$repository->check_secure_dirs( $r );
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

	# Skip rewriting the /cgi/ path and any other specified in
	# the config file.
	my $econf = $repository->get_conf('rewrite_exceptions');
	my @exceptions = ();
	if( defined $econf ) { @exceptions = @{$econf}; }
	push @exceptions, '/cgi/', '/thumbnails/';

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
			my $session = new EPrints::Session(2); # don't open the CGI info
			my $ds = $repository->get_dataset("eprint") ;
			my $searchexp = new EPrints::Search( session=>$session, dataset=>$ds );
			$searchexp->add_field( $ds->get_field( "eprintid" ), $eprintid );
			my $results = $searchexp->perform_search;
			my( $eprint ) = $results->get_records(0,1);
			$searchexp->dispose;
		
			# let it fail if this isn't a real eprint	
			if( !defined $eprint )
			{
				return OK;
			}
	
			my $filename = sprintf( '%s/%02d%s',$eprint->local_path.($thumbnails?"/thumbnails":""), $pos, $tail );

			$r->filename( $filename );

			$session->terminate;
			
			return OK;
		}
	}

	# apache 2 does not automatically look for index.html so we have to do it ourselves
	my $localpath = $uri;
	if( $uri =~ m#/$# )
	{
		$localpath.="index.html";
	}
	$r->filename( $repository->get_conf( "htdocs_path" )."/".$lang.$localpath );

	update_static_file( $repository, $lang, $localpath );

	$r->set_handlers(PerlResponseHandler =>[ 'EPrints::Apache::Template' ] );

	return OK;
}

sub update_static_file
{
	my( $repository, $langid, $localpath ) = @_;

	my $target = $repository->get_conf( "htdocs_path" )."/".$langid.$localpath;

	return if $localpath =~ m!/style/auto.css$!;
	return if $localpath =~ m!/javascript/auto.js$!;

	my @static_dirs = ();;

	my $theme = $repository->get_conf( "theme" );
	$static_dirs[0] = $repository->get_conf( "lib_path" )."/static";
	if( defined $theme )
	{	
		$static_dirs[2] = $repository->get_conf( "lib_path" )."/themes/$theme/static";
	}
	$static_dirs[4] = $repository->get_conf( "config_path" )."/static";

	$static_dirs[1] = $repository->get_conf( "lib_path" )."/lang/$langid/static";
	if( defined $theme )
	{	
		$static_dirs[3] = $repository->get_conf( "lib_path" )."/themes/$theme/lang/$langid/static";
	}
	$static_dirs[5] = $repository->get_conf( "config_path" )."/lang/$langid/static";

	my $source;

	if( $localpath =~ m/\.html$/ )
	{
		my $base = $localpath;
		$base =~ s/\.html$//;
		DIRLOOP: foreach my $dir ( reverse @static_dirs )
		{
			foreach my $suffix ( qw/ .html .xpage .xhtml / )
			{
				if( -e $dir.$base.$suffix )
				{
					$source = $dir.$base.$suffix;
					last DIRLOOP;
				}
			}
		}
	}
	else
	{
		foreach my $dir ( reverse @static_dirs )
		{
			if( -e $dir.$localpath )
			{
				$source = $dir.$localpath;
				last;
			}
		}
	}

	if( !defined $source ) 
	{
#		$repository->log( "No static-website cfg file for $localpath." );
		return;
	}

	my @sourcestat = stat( $source );
	my @targetstat = stat( $target );
	my $sourcemtime = $sourcestat[9];
	my $targetmtime = $targetstat[9];

	return if( $targetmtime > $sourcemtime ); # nothing to do

#	print STDERR "$source ($sourcemtime/$targetmtime)\n";

	$target =~ m/^(.*)\/([^\/]+)/;
	my( $target_dir, $target_file ) = ( $1, $2 );
	
	if( !-e $target_dir )
	{
		EPrints::Platform::mkdir( $target_dir );
	}

	$source =~ m/\.([^.]+)$/;
	my $suffix = $1;
#	print STDERR  "$source -> $target\n";
	if( $suffix eq "xhtml" ) 
	{ 
		my $session = new EPrints::Session(2); # don't open the CGI info
		copy_xhtml( $session, $source, $target, {} ); 
		$session->terminate;
	}
	elsif( $suffix eq "xpage" ) 
	{ 
		my $session = new EPrints::Session(2); # don't open the CGI info
		copy_xpage( $session, $source, $target, {} ); 
		$session->terminate;
	}
	else 
	{ 
		copy_plain( $source, $target, {} ); 
	}
}

sub copy_plain
{
	my( $from, $to, $wrote_files ) = @_;

	if( !EPrints::Utils::copy( $from, $to ) )
	{
		EPrints::abort( "Can't copy $from to $to: $!" );
	}

	$wrote_files->{$to} = 1;
}


sub copy_xpage
{
	my( $session, $from, $to, $wrote_files ) = @_;

	my $doc = $session->get_repository->parse_xml( $from );

	if( !defined $doc )
	{
		$session->get_repository->log( "Could not load file: $from" );
		return;
	}

	my $html = $doc->documentElement;
	my $parts = {};
	foreach my $node ( $html->getChildNodes )
	{
		my $part = $node->nodeName;
		$part =~ s/^.*://;
		next unless( $part eq "body" || $part eq "title" );

		$parts->{$part} = $session->make_doc_fragment;
			
		foreach my $kid ( $node->getChildNodes )
		{
			$parts->{$part}->appendChild( 
				EPrints::XML::EPC::process( 
					$kid,
					in => $from,
					session => $session ) ); 
		}
	}
	foreach my $part ( qw/ title body / )
	{
		if( !$parts->{$part} )
		{
			$session->get_repository->log( "Error: no $part element in ".$from );
			EPrints::XML::dispose( $doc );
			return;
		}
	}

	$parts->{page} = delete $parts->{body};
	$to =~ s/.html$//;
	$session->write_static_page( $to, $parts, "static", $wrote_files );

	EPrints::XML::dispose( $doc );
}

sub copy_xhtml
{
	my( $session, $from, $to, $wrote_files ) = @_;

	my $doc = $session->get_repository->parse_xml( $from );

	if( !defined $doc )
	{
		$session->get_repository->log( "Could not load file: $from" );
		return;
	}

	my( $elements ) = EPrints::XML::find_elements( $doc, "html" );
	if( !defined $elements->{html} )
	{
		$session->get_repository->log( "Error: no html element in ".$from );
		EPrints::XML::dispose( $doc );
		return;
	}
	# why clone?
	#$session->set_page( $session->clone_for_me( $elements->{html}, 1 ) );
	$session->set_page( 
		EPrints::XML::EPC::process( 
			$elements->{html}, 
			in => $from,
			session => $session ) ); 

	$session->page_to_file( $to, $wrote_files );
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


