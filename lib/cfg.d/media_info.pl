# GNU file
$c->add_trigger( EP_TRIGGER_MEDIA_INFO, sub {
	my( %params ) = @_;

	my $epdata = $params{epdata};
	my $repo = $params{repository};

	return 0 if defined $epdata->{format};
	return 0 if !defined $repo->config( "executables", "file" );

	my $filename = $params{filename};
	my $filepath = $params{filepath};

	if( open(my $fh, "file -b -i ".quotemeta($filepath)."|") )
	{
		my $output = <$fh>;
		close($fh);
		chomp($output);
		my( $mime_type, $opts ) = split /;\s*/, $output, 2;
		return 0 if !defined $mime_type;
		return 0 if $mime_type eq "application/octet-stream";
		$epdata->{format} = $mime_type;
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

# ffmpeg
$c->add_trigger( EP_TRIGGER_MEDIA_INFO, sub {
	my( %params ) = @_;

	my $epdata = $params{epdata};
	my $repo = $params{repository};

	return 0 if !defined $repo->config( "executables", "ffmpeg" );

	my $filename = $params{filename};
	my $filepath = $params{filepath};

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
}, priority => 1000);

# other
$c->add_trigger( EP_TRIGGER_MEDIA_INFO, sub {
	my( %params ) = @_;

	my $epdata = $params{epdata};
	my $repo = $params{repository};

	return 0 if defined $epdata->{format};

	$epdata->{format} = "other";

	return 0;
}, priority => 10000);

# guess_doc_type
$c->add_trigger( EP_TRIGGER_MEDIA_INFO, sub {
	my( %params ) = @_;

	my $epdata = $params{epdata};
	my $filename = $params{filename};
	my $repo = $params{repository};

	return 0 if defined $epdata->{format};

	my $format = $repo->call( "guess_doc_type", $repo, $filename );
	$epdata->{format} = $format if $format ne "other";

	return 0;
});
