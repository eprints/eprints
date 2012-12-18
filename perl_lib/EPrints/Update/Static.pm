######################################################################
#
# EPrints::Update::Static
#
######################################################################
#
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

use File::Find;

use strict;

=item %files = scan_static_dirs( $repo, $static_dirs )

Returns a list of files in $static_dirs where the key is the relative path and
the value is the absolute path.

=cut

sub scan_static_dirs
{
	my( $repo, $static_dirs ) = @_;

	my %files;

	foreach my $dir (@$static_dirs)
	{
		_scan_static_dirs( $repo, $dir, "", \%files );
	}

	return %files;
}

sub _scan_static_dirs
{
	my( $repo, $dir, $path, $files ) = @_;

	File::Find::find({
		wanted => sub {
			return if $dir eq $File::Find::name;
			return if $File::Find::name =~ m#/\.#;
			return if -d $File::Find::name;
			$files->{substr($File::Find::name,length($dir)+1)} = $File::Find::name;
		},
	}, $dir);
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
	$js .= "var eprints_oai_archive_id = ".EPrints::Utils::js_string( EPrints::OpenArchives::archive_id( $session ) ).";\n";
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

	update_auto(
			"$target_dir/javascript/auto.js",
			"js",
			\@dirs,
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
		# if a file is removed the dir mtime will change
		$out_of_date = 1 if (stat($dir))[9] > $target_time;
		foreach my $fn (readdir($dh))
		{
			next if exists $map{$fn};
			next if $fn =~ /^\./;
			next if $fn !~ /\.$ext$/;
			next if -d "$dir/$fn";

			$out_of_date = 1 if (stat(_))[9] > $target_time;

			$map{$fn} = "$dir/$fn";
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

sub copy_file
{
	my( $repo, $from, $to, $wrote_files ) = @_;

	my @path = split '/', $to;
	pop @path;
	EPrints::Platform::mkdir( join '/', @path );

	if( $from =~ /\.xhtml$/ )
	{
		return copy_xhtml( @_ );
	}
	elsif( $from =~ /\.xpage$/ )
	{
		return copy_xpage( $repo, $from, substr($to,0,-6), $wrote_files );
	}
	else
	{
		return copy_plain( @_[1..$#_] );
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

	return $to;
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
		next unless( $part eq "head" || $part eq "body" || $part eq "title" || $part eq "template" );

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

	my $page = EPrints::Page->new(
			repository => $session,
			pins => $parts,
		);

	my @written = $page->write_to_file( $to );

	$wrote_files->{$_} = 1 for @written;

	EPrints::XML::dispose( $doc );

	return "$to.page";
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

	my $html = EPrints::XML::EPC::process( 
			$doc->documentElement, 
			in => $from,
			session => $session );

	open(my $fh, ">:utf8", $to) or die "Error writing to $to: $!";
	print $fh $session->xhtml->to_xhtml( $html );
	close($fh);

	$wrote_files->{$to} = 1;

	return $to;
}





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

