=head1 NAME

EPrints::MetaField::Image - upload and display inline images

=head1 DESCRIPTION

Upload and store a (small) image.

Rendering the value will output an image tag with the image data inlined using the data: URI scheme:

	<img src="data:image/jpeg;base64,..." />

On upload images will be automatically reduced in size such that it fits within C<maxwidth> and C<maxheight>.

=over 4

=cut


use strict;

package EPrints::MetaField::Image;

use base EPrints::MetaField::Multipart;

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{fields} = [
		{ sub_name => "original", type => "base64", },
		{ sub_name => "small", type => "base64", },
	];
	$defaults{maxwidth} = 640;
	$defaults{maxheight} = 480;
	return %defaults;
}


1;

