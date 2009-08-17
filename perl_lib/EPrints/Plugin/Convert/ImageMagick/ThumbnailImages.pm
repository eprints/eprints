package EPrints::Plugin::Convert::ImageMagick::ThumbnailImages;

=pod

=head1 NAME

EPrints::Plugin::Convert::ImageMagick::ThumbnailImages 

=head1 DESCRIPTION

Generate thumbnail (smaller) images of image documents.

=head1 PARAMETERS

=over 4

=item formats = { ext => mime_type }

Define the formats to enable thumbnailing from.

=item sizes = { size => [$w, $h] }

Define the size of thumbnails that can be generated.

=item call_convert( $plugin, $dst, $doc, $src, $geom )

If defined is called to do the image conversion of $doc. $dst is the filename to write to, $src is the filename to read from and $geom is the image dimensions to write.

=back

=head1 METHODS

=cut

use EPrints::Plugin::Convert;
@ISA = qw/ EPrints::Plugin::Convert /;

use strict;

# formats supported by ImageMagick
my %FORMATS = qw(
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
# thumbnail sizes to output
my %SIZES = (
	small => [66,50],
	medium => [200,150],
	preview => [400,300],
#	lightbox => [640,480],
);

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Image thumbnails";
	$self->{visible} = "all";
	if( defined $self->{session} )
	{
		$self->{formats} = $self->param( "formats" );
		$self->{sizes} = $self->param( "sizes" );
		$self->{call_convert} = $self->param( "call_convert" );
	}
	$self->{formats} = \%FORMATS if !defined $self->{formats};
	$self->{sizes} = \%SIZES if !defined $self->{sizes};
	$self->{call_convert} = \&call_convert if !defined $self->{call_convert};

	return $self;
}

sub can_convert
{
	my( $self, $doc ) = @_;

	return () unless $self->get_repository->can_execute( "convert" );

	my %types;

	# Get the main file name
	my $fn = $doc->get_main() or return ();

	my( $ext ) = $fn =~ /\.([^\.]+)$/;
	return () unless defined $ext;

	if( exists $self->{formats}->{lc($ext)} )
	{
		foreach my $size (keys %{$self->{sizes}})
		{
			$types{"thumbnail_$size"} = { plugin => $self };
		}
	}

	return %types;
}

sub convert
{
	my( $self, $eprint, $doc, $type ) = @_;

	my $new_doc = $self->SUPER::convert( $eprint, $doc, $type );

	return undef if !defined $new_doc;

	$new_doc->set_value( "format", "image/jpg" );

	return $new_doc;
}

sub export
{
	my ( $self, $dir, $doc, $type ) = @_;

	my $src = $doc->get_stored_file( $doc->get_main );
	$src = $src->get_local_copy();

	return () unless defined $src;

	my( $size ) = $type =~ m/^thumbnail_(.*)$/;
	return () unless defined $size;
	my $geom = $self->{sizes}->{$size};
	return () unless defined $geom;
	
	my $fn = "$size.jpg";

	&{$self->{call_convert}}( $self, "$dir/$fn", $doc, $src, $geom );

	unless( -s "$dir/$fn" ) {
		return ();
	}

	EPrints::Utils::chown_for_eprints( "$dir/$fn" );
	
	return ($fn);
}

=item $plugin->call_convert( $dst, $doc, $src, $geom )

Calls the ImageMagick C<convert> tool to convert $doc into a thumbnail image. Writes the image to $dst. $src is the full path to the main file from $doc. The resulting image should not exceed $geom dimensions ([w,h] array ref).

This method can be overridden with the B<call_convert> parameter.

=cut

sub call_convert
{
	my( $self, $dst, $doc, $src, $geom ) = @_;

	return () unless $self->get_repository->can_execute( "convert" );

	my $convert = $self->get_repository->get_conf( 'executables', 'convert' );

	$geom = "$geom->[0]x$geom->[1]";
# PNG8
#	system($convert, "-strip", "-colorspace", "RGB", "-thumbnail","$geom>", "-extract", $geom, $src."[0]", "PNG8:$dst");
	system($convert, "-strip", "-colorspace", "RGB", "-thumbnail","$geom>", "-extract", $geom, $src."[0]", "$dst");
}

1;
