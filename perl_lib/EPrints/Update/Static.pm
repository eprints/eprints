######################################################################
#
# EPrints::Update::Static
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

B<EPrints::Update::Static

=head1 DESCRIPTION

Update static web pages on demand.

=over 4

=cut

package EPrints::Update::Static;

use Data::Dumper;

use strict;
  

sub update_static_file
{
	my( $repository, $langid, $localpath ) = @_;

	if( $localpath =~ m/\/$/ ) { $localpath .= "index.html"; }

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
			my $this_mtime = EPrints::Utils::mtime( $path );

			$source_mtime = $this_mtime if( $this_mtime > $source_mtime );	
			opendir( $dh, $path ) || EPrints::abort( "Failed to read dir: $path" );
			while( my $file = readdir( $dh ) )
			{
				next if $file eq ".svn";
				next if $file eq "CVS";
				next if $file eq ".";
				next if $file eq "..";
				# file
				my $this_mtime = EPrints::Utils::mtime( "$path/$file" );
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
					$source = $dir.$base.$suffix;
					$source_mtime = EPrints::Utils::mtime( $source );
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
				$source_mtime = EPrints::Utils::mtime( $source );
				last;
			}
		}
	}

	if( !defined $source_mtime ) 
	{
		# no source file therefore source file not changed.
		return;
	}

	my $target_mtime = EPrints::Utils::mtime( $target );

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
		$js .= "var eprints_http_root = ".EPrints::Utils::js_string( $repository->get_conf('base_url') ).";\n";
		$js .= "var eprints_http_cgiroot = ".EPrints::Utils::js_string( $repository->get_conf('perl_url') ).";\n";
		$js .= "var eprints_oai_archive_id = ".EPrints::Utils::js_string( $repository->get_conf('oai','v2','archive_id') ).";\n";
		$js .= "\n";

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
		next unless( $part eq "body" || $part eq "title" || $part eq "template" );

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





1;


