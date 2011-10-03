$c->{guess_doc_type} ||= sub {
	my( $repo, $filename, $mimetype ) = @_;

	my %valid = map { $_ => 1 } $repo->get_types( "document" );

	if( $mimetype )
	{
		my( $major, $minor ) = split '/', $mimetype, 2;
		if( $major =~ /^video|audio|image|text$/ && $valid{$major} )
		{
			return $major;
		}
	}

	if( $filename =~ /\.(pdf|doc|docx)$/ && $valid{text} )
	{
		return "text";
	}
	elsif( $filename =~ /\.(ppt|pptx)$/ && $valid{slideshow} )
	{
		return "slideshow";
	}
	elsif( $filename =~ /\.(zip|tgz|gz)$/ && $valid{archive} )
	{
		return "archive";
	}
	elsif( $filename =~ /\.([^.]+)$/ )
	{
		my $suffix = "\L$1";
		my $format = $repo->config( "mimemap", $suffix );
		return $format if defined $format && $valid{$format};
	}

	return "other";
};

# GNU file
$c->add_trigger( EP_TRIGGER_MEDIA_INFO, sub {
	my( %params ) = @_;

	my $epdata = $params{epdata};
	my $repo = $params{repository};
	my $filename = $params{filename};
	my $filepath = $params{filepath};

	return 0 if defined $epdata->{mime_type};
	return 0 if !defined $filepath;
	return 0 if !defined $repo->config( "executables", "file" );

	# file thinks OpenXML office types are x-zip
	return 0 if $filename =~ /.(docx|pptx|xlsx)$/i;

	if( open(my $fh, "file -b -i ".quotemeta($filepath)."|") )
	{
		my $output = <$fh>;
		close($fh);
		chomp($output);
		my( $mime_type, $opts ) = split /;\s*/, $output, 2;
		$opts = "" if !defined $opts;
		return 0 if !defined $mime_type;
		return 0 if $mime_type =~ /^ERROR:/;
		return 0 if $mime_type eq "application/octet-stream";
		$epdata->{mime_type} = $mime_type;
		my( $charset ) = $opts =~ s/charset=(\S+)//;
		$epdata->{charset} = $charset if defined $charset;
	}
	else
	{
		$repo->log( "Error executing command file -b -i ".quotemeta($filepath).": $!" );
		return undef;
	}

	return 0;
}, priority => 1000);

# ffmpeg media info
$c->add_trigger( EP_TRIGGER_MEDIA_INFO, sub {
	my( %params ) = @_;

	my $epdata = $params{epdata};
	my $repo = $params{repository};
	my $filename = $params{filename};
	my $filepath = $params{filepath};

	return 0 if !defined $filepath;
	return 0 if !defined $repo->config( "executables", "ffmpeg" );

	if( $epdata->{mime_type} && $epdata->{mime_type} !~ /^audio|video/ )
	{
		return 0;
	}

	my $ffmpeg_log = File::Temp->new;

	$repo->read_exec( $ffmpeg_log, "ffmpeg_i", SOURCE => $filepath );
	seek($ffmpeg_log,0,0);

	my $media = $epdata->{media} ||= {};

	while(<$ffmpeg_log>)
	{
		if( /Stream #[0-9.]+[^:]*?: (Audio|Video): / )
		{
			$media->{streams}->{"\L$1"} = 1;
		}
		if( /Video: (\S+),.*?\s(\d+)x(\d+)\b/ )
		{
			$media->{video_codec} = $1;
			$media->{width} = $2;
			$media->{height} = $3;
			$media->{video_codec} =~ s/(['"])(.+)\1/$2/;
		}
		if( /Audio: (\S+),/ )
		{
			$media->{audio_codec} = $1;
			$media->{audio_codec} =~ s/(['"])(.+)\1/$2/;
		}
		if( /Duration:.* (\d+):(\d\d):(\d\d)\.\d+/ )
		{
			$media->{duration} = $1 * 3600 + $2 * 60 + $3;
		}
		if( /Video:.* DAR (\d+:\d+)\b/ )
		{
			$media->{aspect_ratio} = $1;
		}
	}

	return 0;
}, priority => 7000);

# by file extension
$c->add_trigger( EP_TRIGGER_MEDIA_INFO, sub {
	my( %params ) = @_;

	my $epdata = $params{epdata};
	my $filename = $params{filename};
	my $repo = $params{repository};

	return 0 if defined $epdata->{mime_type};

	if( $filename=~m/\.([^.]+)$/ )
	{
		my $suffix = "\L$1";
		$epdata->{mime_type} = $repo->config( "mimemap", $suffix );
	}

	return 0;
}, priority => 5000);

# defaults
$c->add_trigger( EP_TRIGGER_MEDIA_INFO, sub {
	my( %params ) = @_;

	my $epdata = $params{epdata};
	my $filename = $params{filename};
	my $repo = $params{repository};

	$epdata->{mime_type} = "application/octet-stream"
		if !defined $epdata->{mime_type};

	$epdata->{format} = $repo->call( "guess_doc_type",
			$repo,
			$filename,
			$epdata->{mime_type},
		) if !defined $epdata->{format};

	return 0;
}, priority => 10000);
