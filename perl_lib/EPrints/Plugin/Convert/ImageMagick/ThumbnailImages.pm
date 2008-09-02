package EPrints::Plugin::Convert::ImageMagick::ThumbnailImages;

=pod

=head1 NAME

EPrints::Plugin::Convert::ImageMagick::ThumbnailImages 

=cut

use strict;
use warnings;

use Carp;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

our (%FORMATS, @ORDERED, %FORMATS_PREF);
@ORDERED = %FORMATS = qw(
bmp image/bmp
gif image/gif
ief image/ief
jpeg image/jpeg
jpe image/jpeg
jpg image/jpeg
png image/png
tiff image/tiff
tif image/tiff
pnm image/x-portable-anymap
pbm image/x-portable-bitmap
pgm image/x-portable-graymap
ppm image/x-portable-pixmap
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

	$self->{name} = "Thumbnail";
	$self->{visible} = "all";

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	return () unless $plugin->get_repository->can_execute( "convert" );

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

	return () unless $plugin->get_repository->can_execute( "convert" );

	my $convert = $plugin->get_repository->get_conf( 'executables', 'convert' );

	my $src = $doc->get_stored_files( "data", $doc->get_main );
	$src = $src->get_local_copy();

	$type =~ m/^thumbnail_(.*)$/;
	my $size = $1;
	return () unless defined $size;
	my $geom = { small=>"66x50", medium=>"200x150",preview=>"400x300" }->{$1};
	return () unless defined $geom;
	
	my $fn = "$size.jpg";

	system($convert, "-strip", "-colorspace", "RGB", "-thumbnail","$geom>", $src."[$geom]", $dir . '/' . $fn);

	unless( -e "$dir/$fn" ) {
		return ();
	}
	EPrints::Utils::chown_for_eprints( "$dir/$fn" );
	
	return ($fn);
}

1;
