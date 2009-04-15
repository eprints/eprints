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
	my( $session, $langid, $localpath ) = @_;

	my $repository = $session->get_repository;

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
		return if $localpath =~ m# /style/auto\.css$ #x;
		return if $localpath =~ m# /javascript/auto\.js$ #x;
		return if $localpath =~ m# /javascript/secure_auto\.js$ #x;
	}

	my $source_mtime;
	my $source;
	my $map;

	if( $localpath =~ m# /style/auto\.css$ #x )
	{
		return update_auto_css( 
				$session,
				$repository->get_conf( "htdocs_path" )."/$langid",
				\@static_dirs
			);
	}
	elsif( $localpath =~ m# /javascript/auto\.js$ #x )
	{
		return update_auto_js(
				$session,
				$repository->get_conf( "htdocs_path" )."/$langid",
				\@static_dirs
			);
	}
	elsif( $localpath =~ m# /javascript/secure_auto\.js$ #x )
	{
		return update_secure_auto_js(
				$session,
				$repository->get_conf( "htdocs_path" )."/$langid",
				\@static_dirs
			);
	}

	if( $localpath =~ m# \.html$ #x )
	{
		my $base = $localpath;
		$base =~ s/\.html$//;
		DIRLOOP: foreach my $dir ( @static_dirs )
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
		foreach my $dir ( @static_dirs )
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

=item update_auto_css( $target_dir, $dirs )

=cut

sub update_auto_css
{
	my( $session, $target_dir, $static_dirs ) = @_;

	my @dirs = map { "$_/style/auto" } grep { defined } @$static_dirs;

	update_auto(
			"$target_dir/style/auto.css",
			"css",
			\@dirs
		);
}

sub update_secure_auto_js
{
	my( $session, $target_dir, $static_dirs ) = @_;

	my @dirs = map { "$_/javascript/auto" } grep { defined } @$static_dirs;

	my $js = "";
	$js .= "var eprints_http_root = ".EPrints::Utils::js_string( $session->get_url( scheme => "https", host => 1, path => "static" ) ).";\n";
	$js .= "var eprints_http_cgiroot = ".EPrints::Utils::js_string( $session->get_url( scheme => "https", host => 1, path => "cgi" ) ).";\n";
	$js .= "var eprints_oai_archive_id = ".EPrints::Utils::js_string( $session->get_repository->get_conf('oai','v2','archive_id') ).";\n";
	$js .= "\n";

	update_auto(
			"$target_dir/javascript/secure_auto.js",
			"js",
			\@dirs,
			{ prefix => $js },
		);
}

sub update_auto_js
{
	my( $session, $target_dir, $static_dirs ) = @_;

	my @dirs = map { "$_/javascript/auto" } grep { defined } @$static_dirs;

	my $js = "";
	$js .= "var eprints_http_root = ".EPrints::Utils::js_string( $session->get_url( scheme => "http", host => 1, path => "static" ) ).";\n";
	$js .= "var eprints_http_cgiroot = ".EPrints::Utils::js_string( $session->get_url( scheme => "http", host => 1, path => "cgi" ) ).";\n";
	$js .= "var eprints_oai_archive_id = ".EPrints::Utils::js_string( $session->get_repository->get_conf('oai','v2','archive_id') ).";\n";

	update_auto(
			"$target_dir/javascript/auto.js",
			"js",
			\@dirs,
			{ prefix => $js },
		);
}

=item $auto = update_auto( $target_filename, $extension, $dirs [, $opts ] )

Update a file called $target_filename by concantenating all of the files found in $dirs with the extension $extension (js, css etc. - may be a regexp).

If more than one file with the same name exists in $dirs then only the last encountered file will be used.

Returns the full path to the resulting auto file.

$opts:

=over 4

=item prefix

Prefix text to the output file.

=item postfix

Postfix text to the output file.

=back

=cut

sub update_auto
{
	my( $target, $ext, $dirs, $opts ) = @_;

	my $target_dir = $target;
	unless( $target_dir =~ s/\/[^\/]+$// )
	{
		EPrints::abort "Expected filename to write to: $target";
	}

	my $target_time = EPrints::Utils::mtime( $target );
	$target_time = 0 unless defined $target_time;
	my $out_of_date = 0;

	my %map;
	# build a map of every uniquely-named auto file from $dirs
	foreach my $dir (@$dirs)
	{
		opendir(my $dh, $dir) or next;
		$out_of_date = 1 if (stat($dir))[9] > $target_time;
		foreach my $fn (readdir($dh))
		{
			next if $fn =~ /^\./;
			next if -d "$dir/$fn";
			next unless $fn =~ /\.$ext$/;
			$map{$fn} = "$dir/$fn";
			$out_of_date = 1 if (stat(_))[9] > $target_time;
		}
		closedir($dh);
	}

	return $target unless $out_of_date;

	EPrints::Platform::mkdir( $target_dir );

	# to improve speed use raw read/write
	open(my $fh, ">:raw", $target) or EPrints::abort( "Can't write to $target: $!" );

	print $fh Encode::encode_utf8($opts->{prefix}) if defined $opts->{prefix};

	# concat all of the mapped files into a single "auto" file
	foreach my $fn (sort keys %map)
	{
		my $path = $map{$fn};

		print $fh "\n\n\n/* From: $path */\n\n";
		open(my $in, "<:raw", $path) or EPrints::abort( "Can't read from $path: $!" );
		my $buffer = "";
		while(read($in, $buffer, 4096))
		{
			print $fh $buffer;
		}
		close($in);
	}

	print $fh Encode::encode_utf8($opts->{postfix}) if defined $opts->{postfix};

	close($fh);

	return $target;
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

	my $html = $doc->documentElement;
	if( !defined $html )
	{
		$session->get_repository->log( "Error: no html element in ".$from );
		EPrints::XML::dispose( $doc );
		return;
	}
	# why clone?
	#$session->set_page( $session->clone_for_me( $elements->{html}, 1 ) );
	$session->set_page( 
		EPrints::XML::EPC::process( 
			$html, 
			in => $from,
			session => $session ) ); 

	$session->page_to_file( $to, $wrote_files );
}





1;


