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
				$session->terminate;
				return OK;
			}
	
			my $filename = sprintf( '%s/%02d%s',$eprint->local_path.($thumbnails?"/thumbnails":""), $pos, $tail );

			$r->filename( $filename );

			$session->terminate;
			
			return OK;
		}
		
		my $file = $repository->get_conf( "variables_path" )."/abstracts.timestamp";	
		if( -e $file )
		{
			my $poketime = (stat( $file ))[9];
			my $localpath = $uri;
			$localpath.="index.html" if( $uri =~ m#/$# );
			my $targetfile = $repository->get_conf( "htdocs_path" )."/".$lang.$localpath;
			if( -e $targetfile )
			{
				my $targettime = (stat( $targetfile ))[9];
				if( $targettime < $poketime )
				{
					# There is an abstracts file, AND we're looking
					# at serving an abstract page, AND the abstracts timestamp
					# file is newer than the abstracts page...
					# so try and regenerate the abstracts page.
					my $session = new EPrints::Session(2); # don't open the CGI info
					my $eprint = EPrints::DataObj::EPrint->new( $session, $eprintid );
					if( defined $eprint )
					{
						$eprint->generate_static;
					}
					$session->terminate;
				}
			}
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

	my @static_dirs = ();;

	my $theme = $repository->get_conf( "theme" );
	push @static_dirs, $repository->get_conf( "lib_path" )."/static";
	push @static_dirs, $repository->get_conf( "lib_path" )."/lang/$langid/static";
	if( defined $theme )
	{	
		push @static_dirs, $repository->get_conf( "lib_path" )."/themes/$theme/static";
		push @static_dirs, $repository->get_conf( "lib_path" )."/themes/$theme/lang/$langid/static";
	}
	push @static_dirs, $repository->get_conf( "config_path" )."/static";
	push @static_dirs, $repository->get_conf( "config_path" )."/lang/$langid/static";

	my $ok = $repository->get_conf( "auto_update_auto_files" );
	if( defined $ok && $ok == 0 )
	{
		return if $localpath =~ m!/style/auto.css$!;
		return if $localpath =~ m!/javascript/auto.js$!;
	}

	my $source_mtime;
	my $source;
	my $map;

	my $auto_to_scan;
	$auto_to_scan = 'style' if( $localpath =~ m!/style/auto\.css$! );
	$auto_to_scan = 'javascript' if( $localpath =~ m!/javascript/auto\.js$! );

	if( defined $auto_to_scan )
	{
		$source_mtime = 0;

		DIRLOOP: foreach my $dir ( reverse @static_dirs )
		{
			my $dh;
			my $path;
			$path = "$dir/$auto_to_scan/auto";
			next unless -d $path;
			# check the dir too, just in case a file got removed.
			my $this_mtime = _mtime( $path );

			$source_mtime = $this_mtime if( $this_mtime > $source_mtime );	
			opendir( $dh, $path ) || EPrints::abort( "Failed to read dir: $path" );
			while( my $file = readdir( $dh ) )
			{
				next if $file eq ".svn";
				next if $file eq "CVS";
				next if $file eq ".";
				next if $file eq "..";
				# file
				my $this_mtime = _mtime( "$path/$file" );
				$source_mtime = $this_mtime if( $this_mtime > $source_mtime );	
				$map->{"/$auto_to_scan/auto/$file"} = "$path/$file";
			}
			closedir( $dh );
		}
	}
	elsif( $localpath =~ m/\.html$/ )
	{
		my $base = $localpath;
		$base =~ s/\.html$//;
		DIRLOOP: foreach my $dir ( reverse @static_dirs )
		{
			foreach my $suffix ( qw/ .html .xpage .xhtml / )
			{
				if( -e $dir.$base.$suffix )
				{
					$source = _mtime( $dir.$base.$suffix );
					$source_mtime = _mtime( $source );
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
				$source_mtime = _mtime( $source );
				last;
			}
		}
	}

	if( !defined $source_mtime ) 
	{
		# no source file therefore source file not changed.
		return;
	}

	my $target_mtime = _mtime( $target );

	return if( $target_mtime > $source_mtime ); # nothing to do

	if( defined $auto_to_scan && $auto_to_scan eq "style" )
	{
		# do the magic auto.css
		my $css = "";
		my $base_url = $repository->get_conf( "base_url" );
		foreach my $target ( sort keys %{$map} )
		{
			if( $target =~ m/(\/style\/auto\/.*\.css$)/ )
			{
				# $css .= "\@import url($base_url$1);\n";
				my $fn = $map->{$target};
				open( CSS, $fn ) || EPrints::abort( "Can't read $fn: $!" );
				$css .= "\n\n\n/* From: $fn */\n\n";
				$css .= join( "", <CSS> );
				close CSS;	
			}	
		}
	
		my $fn = $repository->get_conf( "htdocs_path" )."/$langid/style/auto.css";
		open( CSS, ">$fn" ) || EPrints::abort( "Can't write $fn: $!" );
		print CSS $css;
		close CSS;
	
		return;
	}

	if( defined $auto_to_scan && $auto_to_scan eq "javascript" )
	{
		# do the magic auto.js 
		my $js = "";
		foreach my $target ( sort keys %{$map} )
		{
			if( $target =~ m/(\/javascript\/auto\/.*\.js$)/ )
			{
				my $fn = $map->{$target};
				open( JS, $fn ) || EPrints::abort( "Can't read $fn: $!" );
				$js .= "\n\n\n/* From: $fn */\n\n";
				$js .= join( "", <JS> );
				close JS;	
			}	
		}
	
		my $fn = $repository->get_conf( "htdocs_path" )."/$langid/javascript/auto.js";
		open( JS, ">$fn" ) || EPrints::abort( "Can't write $fn: $!" );
		print JS $js;
		close JS;

		return;
	}


	$target =~ m/^(.*)\/([^\/]+)/;
	my( $target_dir, $target_file ) = ( $1, $2 );
	
	if( !-e $target_dir )
	{
		EPrints::Platform::mkdir( $target_dir );
	}

	$source =~ m/\.([^.]+)$/;
	my $suffix = $1;

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

sub _mtime
{
	my( $file ) = @_;

	my @filestat = stat( $file );

	return $filestat[9];
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


