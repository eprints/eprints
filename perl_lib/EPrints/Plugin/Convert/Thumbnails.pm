package EPrints::Plugin::Convert::Thumbnails;

=for Pod2Wiki

=head1 NAME

EPrints::Plugin::Convert::Thumbnails - thumbnail-sized versions of audio/video/images

=head1 SYNOPSIS

	use EPrints;
	
	# enable audio previews
	$c->{plugins}->{'Convert::Thumbnails'}->{params}->{audio} = 1;
	# disable video previews
	$c->{plugins}->{'Convert::Thumbnails'}->{params}->{video} = 0;
	
	# enable audio_*/video_* previews
	$c->{thumbnail_types} = sub {
		my( $list, $repo, $doc ) = @_;

		push @$list, qw( audio_mp4 audio_ogg video_mp4 video_ogg );
	};
	
	...
	
	my $plugin = $session->plugin( "Convert" );
	my %available = $plugin->can_convert( $doc );
	$plugin = $available{"thumbnail_video"}->{plugin};
	$new_doc = $plugin->convert( $doc, "thumbnail_video" );


=head1 DESCRIPTION

Conversion of images, videos and audio into preview/thumbnail versions.

This plugin wraps the ImageMagick I<convert> and I<ffmpeg> tools.

=head1 PARAMETERS

These parameters can be set through the B<plugins.pl> configuration file. You must also configure the B<executables> locations for I<convert> and I<ffmpeg> in L<EPrints::SystemSettings>.

=over 4

=item convert_formats = { ext => mime_type }

Define the formats supported for input by the call_convert() method.

=item ffmpeg_formats = { ext => mime_type }

Define the formats supported for input by the call_ffmpeg() method.

=item sizes = { size => [$w, $h] }

Define the size of thumbnails that can be generated e.g. "small => [66,50]". The image dimensions generated may be smaller than those specified if the aspect ratio of the source document is different.

Images are output in 8-bit paletted PNG.

=item video = 1

Enable video previews.

=item audio = 1

Enable audio previews.

=item video_height = "480"

Video preview vertical lines.

=item audio_sampling = "44100"

Audio frequency sampling rate in Hz.

=item audio_bitrate = "96k"

Audio bit rate in kb/s

=item audio_codec = "libfaac"

I<ffmpeg> compiled-in AAC codec name.

=item frame_rate = "10.00"

Video frame rate in fps.

=item video_codec = "h264"

I<ffmpeg> compiled-in H.264 codec name (may be libx264 on some platforms).

=item video_rate = "1500k"

Video bit rate in kilobits.

=item call_convert = sub( $plugin, $dst, $doc, $src, $geom, $size )

See L</call_convert>.

=item call_ffmpeg = sub( $plugin, $dst, $doc, $src, $geom, $size, $offset )

See L</call_ffmpeg>.

=back

=head1 METHODS

=over 4

=cut

use EPrints::Plugin::Convert;
@ISA = qw/ EPrints::Plugin::Convert /;

use strict;

# default settings
my %DEFAULT;

# formats supported by ImageMagick
$DEFAULT{convert_formats} = {qw(
	bmp image/bmp
	gif image/gif
	ief image/ief
	jpeg image/jpeg
	jpe image/jpeg
	jpg image/jpeg
	jp2	image/jp2
	png image/png
	tiff image/tiff
	tif image/tiff
	pnm image/x-portable-anymap
	pbm image/x-portable-bitmap
	pgm image/x-portable-graymap
	ppm image/x-portable-pixmap
	pdf	application/pdf
	ps	application/postscript
)};
# formats supported by ffmpeg
$DEFAULT{ffmpeg_formats} = {qw(
	mp3	audio/mpeg
	mp4	video/mpeg
	mp2	video/mpeg
	mpa	video/mpeg
	mpe	video/mpeg
	mpeg	video/mpeg
	mpg	video/mpeg
	mpv2	video/mpeg
	mov	video/quicktime
	qt	video/quicktime
	lsf	video/x-la-asf
	lsx	video/x-la-asf
	asf	video/x-ms-asf
	asr	video/x-ms-asf
	avi	video/x-msvideo
	vob	video/mpeg
	m4v	video/mpeg
	m2v	video/mpeg
	wmv	video/x-ms-wmv
	ogv	video/ogg
	flv	video/x-flv
	wav	audio/wav
	ac3	audio/ac3
	m4a	audio/mp4
	wma audio/x-ms-wma
)};
# thumbnail sizes to output
$DEFAULT{sizes} = {(
	small => [66,50],
	medium => [200,150],
	preview => [400,300],
	lightbox => [640,480],
)};
# enable/disable audio/video previews
$DEFAULT{video} = 1;
$DEFAULT{audio} = 1;

# video_preview lines
$DEFAULT{video_height} = "480";

# ffmpeg quality settings
#$DEFAULT{audio_codec} = "libfaac";
#$DEFAULT{audio_bitrate} = "96k";
#$DEFAULT{audio_sampling} = "44100";
#$DEFAULT{frame_rate} = "10.00";
#$DEFAULT{video_codec} = "libx264";
#$DEFAULT{video_rate} = "500k";

$DEFAULT{audio_mp4} = {
	audio_codec => "libvo_aacenc",
	audio_bitrate => "96k",
	audio_sampling => "44100",
	container => "mp4",
};
$DEFAULT{audio_ogg} = {
	audio_codec => "libvorbis",
	audio_bitrate => "96k",
	audio_sampling => "44100",
	container => "ogg",
};
$DEFAULT{video_mp4} = {
	audio_codec => "libvo_aacenc",
	audio_bitrate => "96k",
	audio_sampling => "44100",
	video_codec => "libx264",
	video_frame_rate => "10.00",
	video_bitrate => "500k",
	container => "mp4",
};
$DEFAULT{video_ogg} = {
	audio_codec => "libvorbis",
	audio_bitrate => "96k",
	audio_sampling => "44100",
	video_codec => "libtheora",
	video_frame_rate => "10.00",
	video_bitrate => "500k",
	container => "ogg",
};

# methods
$DEFAULT{call_convert} = \&call_convert;
$DEFAULT{call_ffmpeg} = \&call_ffmpeg;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Thumbnails";
	$self->{visible} = "all";
	for(qw(
		audio video
		audio_mp4 audio_ogg video_mp4 video_ogg
		convert_formats ffmpeg_formats sizes
		video_height
		call_convert call_ffmpeg
	  ))
	{
		# defined by new( foo => bar )
		next if defined $self->{$_};
		# defined by $c->{plugins}
		if( defined $self->{session} )
		{
			$self->{$_} = $self->param( $_ );
		}
		# set the default
		$self->{$_} = $DEFAULT{$_} if !defined $self->{$_};
	}

	if( defined $self->{session} )
	{
		my $cfg = $self->{session}->get_repository->get_conf( "executables" );
		if( !defined( $self->{'convert'} = $cfg->{'convert'} ) )
		{
			$self->{'convert_formats'} = {};
		}
		if( !defined( $self->{'ffmpeg'} = $cfg->{'ffmpeg'} ) )
		{
			$self->{'ffmpeg_formats'} = {};
		}
	}

	return $self;
}

=item %types = $plugin->can_convert( $doc )

Returns a hash map of types this plugin can convert $doc to.

This may be relatively expensive to do if the plugin has to call an external tool to determine if it can export something.

=cut

sub can_convert
{
	my( $self, $doc ) = @_;

	return () unless $self->get_repository->can_execute( "convert" );

	my %types;

	# Get the main file name
	my $fn = $doc->get_main() or return ();

	my( $ext ) = $fn =~ /\.([^\.]+)$/;
	return () unless defined $ext;

	if( exists $self->{convert_formats}->{lc($ext)} )
	{
		foreach my $size (keys %{$self->{sizes}})
		{
			$types{"thumbnail_$size"} = { plugin => $self };
		}
	}
	if( exists $self->{ffmpeg_formats}->{lc($ext)} )
	{
		if( $doc->exists_and_set( "media_video_codec" ) )
		{
			foreach my $size (keys %{$self->{sizes}})
			{
				$types{"thumbnail_$size"} = { plugin => $self };
			}
			if( $self->{video_mp4} )
			{
				$types{"thumbnail_video_mp4"} = { plugin => $self };
			}
			if( $self->{video_ogg} )
			{
				$types{"thumbnail_video_ogg"} = { plugin => $self };
			}
		}
		# only offer audio thumbnailing if there's no video
		elsif( $doc->exists_and_set( "media_audio_codec" ) )
		{
			if( $self->{audio_mp4} )
			{
				$types{"thumbnail_audio_mp4"} = { plugin => $self };
			}
			if( $self->{audio_ogg} )
			{
				$types{"thumbnail_audio_ogg"} = { plugin => $self };
			}
		}
	}

	return %types;
}

=item $new_doc = $plugin->convert( $eprint, $doc, $type )

Request the plugin converts $doc to $type, as returned by L</can_convert>.

=cut

sub convert
{
	my( $self, $eprint, $doc, $type ) = @_;

	my $repo = $self->{session};

	my $dir = File::Temp->newdir();

	my @files = $self->export( $dir, $doc, $type );
	return if !@files;

	my $main = $files[0];

	for(@files)
	{
		open(my $fh, "<", "$dir/$_") or EPrints->abort( "Error opening $dir/$_: $!" );
		$_ = {
			filename => $_,
			filesize => (-s $fh),
			mime_type => $self->{_mime_type},
			_content => $fh,
		};
	}

	my $new_doc = $eprint->create_subdataobj( "documents", {
		format => "other",
		formatdesc => $self->{name} . ' conversion from ' . $doc->get_type . ' to ' . $type,
		main => $main,
		files => \@files,
		security => $doc->value( "security" ),
		relation => [{
			type => EPrints::Utils::make_relation( "isVersionOf" ),
			uri => $doc->internal_uri(),
		},{
			type => EPrints::Utils::make_relation( "isVolatileVersionOf" ),
			uri => $doc->internal_uri(),
		}],
	});

	for(@files)
	{
		close $_->{_content};
	}

	return $new_doc;
}

=item @filelist = $plugin->export( $dir, $doc, $type )

Request the plugin converts $doc to $type, as returned by L</can_convert>. Outputs the resulting files to $dir and returns their paths (excluding the leading $dir part).

=cut

sub export
{
	my ( $self, $dir, $doc, $type ) = @_;
	
	my $src = $doc->get_stored_file( $doc->get_main );
	return () unless defined $src && $src->value( "filesize" ) > 0;

	my $filename = $src->value( "filename" );

	my( $ext ) = $filename =~ /\.([^\.]+)$/;
	return () unless $ext;

	my( $size ) = $type =~ m/^thumbnail_(.*)$/;
	return () unless defined $size;
	my $geom;
	if( $size =~ /^(audio|video)_(mp4|ogg)$/ )
	{
		$self->{_mime_type} = "$1/$2";
	}
	else
	{
		$geom = $self->{sizes}->{$size};
		return () if !defined $geom;

		$self->{_mime_type} = "image/png";
	}

	my @files;

	if( exists $self->{ffmpeg_formats}->{lc($ext)} )
	{
		my $seconds;
		my $duration;
		if( $doc->exists_and_set( "media_sample_start" ) )
		{
			$seconds = $doc->get_value( "media_sample_start" );
		}
		if( $doc->exists_and_set( "media_duration" ) )
		{
			$duration = $doc->get_value( "media_duration" );
		}
		# default to 5 seconds (as good a place as any)
		$seconds = 5 if !EPrints::Utils::is_set( $seconds );
		$duration = 0 if !EPrints::Utils::is_set( $duration );
		$seconds = $self->calculate_offset( $duration, $seconds );

		my $src_file = $src->get_local_copy;
		if( !$src_file )
		{
			$self->{session}->log( "get_local_copy failed for file.".$src->id );
			return ();
		}
		@files = &{$self->{call_ffmpeg}}( $self, $dir, $doc, $src_file, $geom, $size, $seconds );
	}
	else
	{
		($doc, $src) = $self->intermediate( $doc, $src, $geom, $size );

		my $src_file = $src->get_local_copy;
		if( !$src_file )
		{
			$self->{session}->log( "get_local_copy failed for file.".$src->id );
			return ();
		}
		@files = &{$self->{call_convert}}( $self, $dir, $doc, $src_file, $geom, $size );
	}

	for(@files)
	{
		EPrints::Utils::chown_for_eprints( "$dir/$_" );
	}
	
	return @files;
}

=back

=head2 Utility Methods

=over 4

=item $ver = $plugin->convert_version()

Returns the MAJOR.MINOR version of ImageMagick.

Returns 0.0 if the version can not be determined.

=cut

sub convert_version
{
	my( $self ) = @_;

	return 0.0 if !defined $self->{convert};

	my $version = `$self->{convert} --version`;
	$version =~ s/^.*Version: ImageMagick ([0-9]+\.[0-9]+)\..*$/$1/s;

	return $version || 0;
}

=item $ok = $plugin->is_video( $doc )

Returns true if $doc is a video.

=cut

sub is_video
{
	my( $self, $doc ) = @_;

	return $doc->exists_and_set( "media_video_codec" );
}

=item $doc = $plugin->intermediate( $doc, $src, $geom, $src )

Attempt to find an intermediate document that we can use to convert from (e.g. make a thumbnail from a preview version).

Returns the original $doc if not intermediate is found.

=cut

sub intermediate
{
	my( $self, $doc, $src, $geom, $size ) = @_;

	my %sizes = %{$self->param( "sizes" )};
	my @sizes = sort { $sizes{$b}->[0] <=> $sizes{$a}->[0] } keys %sizes;
	for(@sizes)
	{
		last if $_ eq $size; # anything further will be smaller

		my $relation = EPrints::Utils::make_relation(
			"has${_}ThumbnailVersion"
		);
		my( $thumb_doc ) = $doc->related_dataobjs( $relation );
		next if !defined $thumb_doc;

		# check this thumb is a current one
		my $thumb_src = $thumb_doc->stored_file( $thumb_doc->get_main );
		next if !defined $thumb_src;
		next if $thumb_src->value( "mtime" ) lt $src->value( "mtime" );

		return( $thumb_doc, $thumb_src );
	}

	return( $doc, $src );
}

=item $plugin->call_convert( $dst, $doc, $src, $geom, $size )

Calls the ImageMagick I<convert> tool to convert $doc into a thumbnail image. Writes the image to $dst. $src is the full path to the main file from $doc. The resulting image should not exceed $geom dimensions ([w,h] array ref).

$size is the thumbnail-defined size (as-in the keys to the B<sizes> parameter).

This method can be overridden with the B<call_convert> parameter.

=cut

sub call_convert
{
	my( $self, $dir, $doc, $src, $geom, $size ) = @_;

	my $convert = $self->{'convert'};
	my $version = $self->convert_version;

	if (!defined($geom)) {
		EPrints::abort("NO GEOM");
	}

	my $fn = $size . ".jpg";
	my $dst = "$dir/$fn";

	$geom = "$geom->[0]x$geom->[1]";
# JPEG
	if( $size eq "small" )
	{
		# attempt to create a thumbnail that fits within the given dimensions
		# geom^ requires 6.3.8
		if( $version > 6.3 )
		{
			$self->_system($convert, "-strip", "-colorspace", "RGB", "-background", "white", "-thumbnail","$geom^", "-gravity", "center", "-extent", $geom, "-bordercolor", "gray", "-border", "1x1", $src."[0]", "JPEG:$dst");
		}
		else
		{
			$self->_system($convert, "-strip", "-colorspace", "RGB", "-background", "white", "-thumbnail","$geom>", "-extract", $geom, "-bordercolor", "gray", "-border", "1x1", $src."[0]", "JPEG:$dst");
		}
	}
	elsif( $size eq "medium" )
	{
		$self->_system($convert, "-strip", "-colorspace", "RGB", "-trim", "+repage", "-size", "$geom", "-thumbnail","$geom>", "-background", "white", "-gravity", "center", "-extent", $geom, "-bordercolor", "white", "-border", "0x0", $src."[0]", "JPEG:$dst");
	}
	else
	{
		$self->_system($convert, "-strip", "-colorspace", "RGB", "-background", "white", "-thumbnail","$geom>", "-extract", $geom, "-bordercolor", "white", "-border", "0x0", $src."[0]", "JPEG:$dst");
	}

	if( -s $dst )
	{
		return ($fn);
	}

	return ();
}

=item $plugin->call_ffmpeg( $dst, $doc, $src, $geom, $size, $offset )

Uses the I<ffmpeg> tool to do the image conversion of $doc. $dst is the filename to write to, $src is the filename to read from and $geom is the image dimensions to write.

$size is the thumbnail-defined size (as-in the keys to the B<sizes> parameter or B<audio> or B<video>).

$offset is the time offset to extract (for B<audio>/B<video>). It is an array ref of [HOUR, MINUTE, SECOND, FRAME].

=cut

sub call_ffmpeg
{
	my( $self, $dir, $doc, $src, $geom, $size, $offset ) = @_;

	if( $size =~ /^audio_(mp4|ogg)$/ )
	{
		return $self->export_audio( $dir, $doc, $src, $1 );
	}
	elsif( $size =~ /^video_(mp4|ogg)$/ )
	{
		return $self->export_video( $dir, $doc, $src, $1 );
	}
	else
	{
		return $self->export_cell( $dir, $doc, $src, $geom, $size, $offset );
	}
}

=item $plugin->export_mp3( $dst, $doc, $src, $rate )

Export $src to $dst in MP3 format at sampling rate $rate.

=cut

sub export_mp3
{
	my( $self, $dst, $doc, $src, $rate ) = @_;

	my $ffmpeg = $self->{ffmpeg};

	my $cmd = sprintf("%s -y -i %s -acodec libmp3lame -ac 2 -ar %s -ab 32 -f mp3 %s", $ffmpeg, quotemeta($src), $rate, quotemeta($dst));
	$self->_system("$cmd >/dev/null 2>&1");

	unless( -s $dst )
	{
		print STDERR Carp::longmess( "Error in command: $cmd" );
		return;
	}
}

=item $plugin->export_audio( $dst, $doc, $src, $container )

Export audio-only $src to $dst in $container format.

Audio is encoded as I<audio_codec>.

=cut

sub export_audio
{
	my( $self, $dir, $doc, $src, $container ) = @_;

	return unless $doc->exists_and_set( "media_audio_codec" );

	my @files;

	my $format = $self->{'audio_'.$container};

	my $fn = "audio." . $format->{container};
	my $dst = "$dir/$fn";
	my $tmp = File::Temp->new;
	$self->{session}->read_exec( $tmp, 'ffmpeg_audio_'.$format->{container},
		SOURCE => $src,
		TARGET => $dst,
		%$format
	);
	if( -s $dst )
	{
		return ($fn);
	}
	else
	{
		unlink( $dst );
		sysseek($tmp,0,0);
		sysread($tmp,my $err,-s $tmp);
		$self->{session}->log( "Error in ffmpeg: " . $err );
	}

	return ();
}

=item $plugin->export_video( $dst, $doc, $src, $container )

Export audio and video $src to $dst in $container format with vertical lines $lines maintaining aspect ratio.

Video is encoded as I<video_codec>.

Audio is encoded as I<audio_codec>.

=cut

sub export_video
{
	my( $self, $dir, $doc, $src, $container ) = @_;

	my $lines = $self->{video_height};

	return unless $doc->exists_and_set( "media_video_codec" );

	my $width = $doc->get_value( "media_width" );
	my $height = $doc->get_value( "media_height" );
	my $duration = $doc->get_value( "media_duration" );
	my $aspect = $doc->get_value( "media_aspect_ratio" );
	my $ratio = 4 / 3;
	if( defined $aspect && $aspect =~ /^(\d+):(\d+)$/ && ( $1 / $2 ) != 0 ) # ignore 0:n
	{
		$ratio = $1 / $2;
	}
	elsif( defined $width && defined $height )
	{
		$ratio = $width / $height;
	}
#print STDERR "Aspect ratio = $ratio\n";

	if( defined $height && $height > $lines )
	{
		$height = $lines;
	}
	elsif( !defined $height )
	{
		$height = $lines;
	}
# width must be a multiple of 8 or ffmpeg barfs (2 for x264, 8 for theora)
	$width = sprintf("%.0f", $height * $ratio );
	$width += $width % 8;
#print STDERR "Outputting $width x $height\n";

	my $format = $self->{'video_'.$container};

	my $fn = "video." . $format->{container};
	my $dst = "$dir/$fn";
	my $tmp = File::Temp->new;
	$self->{session}->read_exec( $tmp, 'ffmpeg_video_'.$format->{container},
		SOURCE => $src,
		TARGET => $dst,
		%$format,
		width => $width,
		height => $height,
	);
	if( -s $dst )
	{
		return ($fn);
	}
	else
	{
		unlink( $dst );
		sysseek($tmp,0,0);
		sysread($tmp,my $err,-s $tmp);
		$self->{session}->log( "Error in ffmpeg: " . $err );
	}

	return ();
}

=item $plugin->export_cell( $dir, $doc, $src, $geom, $size, $offset )

Export $src to $dst in JPG format in dimensions $geom from offset $offset.

=cut

sub export_cell
{
	my( $self, $dir, $doc, $src, $geom, $size, $offset ) = @_;
	
	my $ffmpeg = $self->{ffmpeg};

	$offset = _seconds_to_marker( $offset );

	$self->{_mime_type} = "image/jpeg";

	# extract the frame in MJPEG format
	my $fn = $size . '.jpg';
	my $dst = "$dir/$fn";
	my $tmp = File::Temp->new;
	$self->{session}->read_exec( $tmp, 'ffmpeg_cell',
		SOURCE => $src,
		TARGET => $dst,
		offset => $offset,
		width => $geom->[0],
		height => $geom->[1],
	);

	if( -s $dst )
	{
		return( $fn );
	}
	else
	{
		unlink( $dst );
		sysseek($tmp,0,0);
		sysread($tmp,my $err,-s $tmp);
		$self->{session}->log( "Error in ffmpeg: " . $err );
	}

	return ();
}

=item $secs = $plugin->calculate_offset( $duration, $offset )

Translates a seconds or percentage offset into seconds from the start time. If the resulting time is greater than $duration returns $duration.

To specify seconds either use just a number (1234) or append 's' (1234s).

To specify a percentage of $duration append '%' (52%).

=cut

sub calculate_offset
{
	my( $self, $duration, $offset ) = @_;

	$duration = 0 if !defined $duration;
	$offset = "" if !defined $offset;

	my $seconds = 0;
	if( $offset =~ /([0-9]+)s/ )
	{
		$seconds = $1;
		$seconds = $duration if $seconds > $duration;
	}
	elsif( $offset =~ /([0-9\.]+)\%/ )
	{
		$seconds = $duration * ($1/100);
		$seconds = $duration if $seconds > $duration;
	}
	elsif( $offset >= 0 && int($offset) <= $duration ) # ignore .frames
	{
		$seconds = $offset+0;
	}
	elsif( $duration >= 10 )
	{
		$seconds = 10;
	}
	elsif( $duration >= 5 )
	{
		$seconds = 5;
	}
	return $seconds;
}

sub _seconds_to_marker
{
	my( $seconds ) = @_;

	# enforce numeric
	$seconds = 0+$seconds;
	my $frames = $seconds-int($seconds);
	$seconds = int($seconds);

	my @offset = (int($seconds/3600), int(($seconds%3600)/60), int($seconds) % 60, $frames);

	return join(':', @offset[0..2]).".".$offset[3];
}

# make a system call
sub _system
{
	my( $self, @args ) = @_;

	if( $self->{session}->{noise} >= 2 )
	{
		$self->{session}->log( "@args" );
	}

	my $rc = system(@args);

	return $rc;
}

=back

=head1 SEE ALSO

L<EPrints::Plugin>, L<EPrints::Plugin::Convert>.

=head1 AUTHOR

Copyright 2009 Tim Brody <tdb2@ecs.soton.ac.uk>, University of Southampton, UK.

This module is released under the GPLv3 license.

=cut

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

