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
);
# formats pref maps mime type to file suffix. Last suffix
# in the list is used.
for(my $i = 0; $i < @ORDERED; $i+=2)
{
	$FORMATS_PREF{$ORDERED[$i+1]} = $ORDERED[$i];
}
our $EXTENSIONS_RE = join '|', keys %FORMATS;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Thumbnail Videos";
	$self->{visible} = "all";

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	my $ffmpeg = $plugin->get_repository->get_conf( 'executables', 'ffmpeg' ) or return ();

	my %types;

	# Get the main file name
	my $fn = $doc->get_main() or return ();

	if( $fn =~ /\.($EXTENSIONS_RE)$/oi ) 
	{
		$types{"thumbnail_small"} = { plugin => $plugin, };
		$types{"thumbnail_medium"} = { plugin => $plugin, };
		$types{"thumbnail_preview"} = { plugin => $plugin, };
	}

	return %types;
}



sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	my $ffmpeg = $plugin->get_repository->get_conf( 'executables', 'ffmpeg' ) or return ();

	my $src = $doc->get_stored_files( "data", $doc->get_main );
	$src = $src->get_local_copy();

	$type =~ m/^thumbnail_(.*)$/;
	my $size = $1;
	return () unless defined $size;
	my $geom = { small=>"66x50", medium=>"200x150",preview=>"400x300" }->{$1};
	return () unless defined $geom;
	
	my $fn = "$size.png";

	system($ffmpeg." -y -i ".quotemeta($src)." -vcodec png -vframes 1 -an -f rawvideo -ss 00:00:02 -s ".$geom." ".quotemeta($dir.'/'.$fn)." 2>/dev/null");

	return () unless( -e "$dir/$fn" && -s "$dir/$fn" );

	# if output file does not exist it could be that the video is VERY short (<2secs), in this case-> need to gen the thumbnails from 0sec
	#actually in that case, the file exists, but its size = 0
	
	EPrints::Utils::chown_for_eprints( "$dir/$fn" );
	
	return ($fn);
}

1;

