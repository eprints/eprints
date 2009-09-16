package EPrints::Plugin::Convert::ThumbnailVideos;

=pod

=head1 NAME

EPrints::Plugin::Convert::ThumbnailVideos

=cut

use strict;
use warnings;

use Carp;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

# beginning of the list:
# to add: real media, flash video flc, MKV, mp4
our (%FORMATS, @ORDERED, %FORMATS_PREF);
@ORDERED = %FORMATS = qw(
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
);
# formats pref maps mime type to file suffix. Last suffix
# in the list is used.
for(my $i = 0; $i < @ORDERED; $i+=2)
{
	$FORMATS_PREF{$ORDERED[$i+1]} = $ORDERED[$i];
}
our $EXTENSIONS_RE = join '|', keys %FORMATS;

our $GEOMETRY = {
	small=>"66x50",
	medium=>"200x150",
	preview=>"400x300"
};

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Thumbnail Videos";
	$self->{visible} = "all";
	$self->{ffmpeg} = defined($self->{session}) ?
		$self->get_repository->get_conf( "executables", "ffmpeg" ) :
		undef;

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	return unless $plugin->{ffmpeg};

	my %types;

	# Get the main file name
	my $fn = $doc->get_main() or return ();

	if( $fn =~ /\.($EXTENSIONS_RE)$/oi ) 
	{
		$types{"thumbnail_small"} = { plugin => $plugin, };
		$types{"thumbnail_medium"} = { plugin => $plugin, };
		$types{"thumbnail_preview"} = { plugin => $plugin, };
		$types{"thumbnail_video"} = { plugin => $plugin, };
	}

	return %types;
}



sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	return unless $plugin->{ffmpeg};

	my( $size ) = $type =~ m/^thumbnail_(.*)$/;
	if( !defined( $size ) )
	{
		return ();
	}
	elsif( $size eq "video" )
	{
		return $plugin->export_flv( $dir, $doc, $type, $size );
	}
	elsif( exists( $GEOMETRY->{$size} ) )
	{
		# Export the cell at 5 seconds
		return $plugin->export_cell( $dir, $doc, $type, "00:00:05" );
	}
	else
	{
		return ();
	}
}

sub export_cell
{
	my( $self, $dir, $doc, $type, $offset ) = @_;
	
	my $ffmpeg = $self->{ffmpeg};

	my( $size ) = $type =~ /^thumbnail_(.+)$/;

	# As we may be attempting this twice, don't attempt to copy the file
	# twice!
	my $src = $doc->get_stored_file( $doc->get_main );
	$src = $self->{_local_copy} ||= $src->get_local_copy();

	my $fn = "$size.jpg";

	my $geom = $GEOMETRY->{$size};

	my $cmd = "$ffmpeg -y -i ".quotemeta($src)." -vcodec mjpeg -vframes 1 -an -f rawvideo -ss $offset -s $geom ".quotemeta($dir.'/'.$fn)." 2>/dev/null";
	system($cmd);

	if( not -s "$dir/$fn" )
	{
		if( $offset eq "00:00:00" )
		{
			delete $self->{_local_copy};
			return ();
		}
		else
		{
			return $self->export_cell( $dir, $doc, $type, "00:00:00" );
		}
	}

	# if output file does not exist it could be that the video is VERY short (<2secs), in this case-> need to gen the thumbnails from 0sec
	#actually in that case, the file exists, but its size = 0
	
	EPrints::Utils::chown_for_eprints( "$dir/$fn" );
	
	delete $self->{_local_copy};

	return ($fn);
}

sub export_flv
{
	my( $self, $dir, $doc, $type ) = @_;

	my $ffmpeg = $self->{ffmpeg};

	my $src = $doc->get_stored_file( $doc->get_main );
	$src = $src->get_local_copy;

	my $fn = "video_preview.flv";

	system("$ffmpeg -y -i ".quotemeta($src)." -acodec mp3 -ac 2 -ar 22050 -ab 32 -f flv -r 10.00 -s 320x240 $dir/$fn 2>/dev/null");

	EPrints::Utils::chown_for_eprints( "$dir/$fn" );

	return ($fn);
}

1;

