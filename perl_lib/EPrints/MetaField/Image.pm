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

use base "EPrints::MetaField::Base64";

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;

	$defaults{maxwidth} = 640;
	$defaults{maxheight} = 480;
	return %defaults;
}

sub form_value_actual 
{
  my ($self, $session, $object, $basename) = @_;

  my $fh = $session->query->upload($basename);

  if(!defined $fh) 
  {
    return $self->property("multiple") ? [] : undef;
  }

  my $image_data;

  sysread $fh, $image_data, (-s $fh);

  return $self->property("multiple") ? [$image_data] : $image_data;
}

sub form_value 
{
  my ($self, $session, $object, $prefix) = @_;

  my $value = $self->SUPER::form_value($session, $object, $prefix);
  
  if(!$self->property("multiple")) 
  {
    return $value;
  } 

  my $basename = $self->basename($prefix);

  push @$value, @{$object->value($self->name())};

  return $value;
}

sub render_input_field 
{
  my( $self, $session, $value, $dataset, $staff, $hidden_fields, $obj, $prefix ) = @_;

  my $xhtml = $session->xml->create_document_fragment();
  my $basename = $self->basename($prefix);
    
  $xhtml->appendChild($session->xhtml->input_field($basename, undef, type => "file"));
  $xhtml->appendChild($session->xhtml->input_field("_internal_".$basename."_upload",
						   $session->phrase("lib/submissionform:action_upload"),
						   type=>"submit",
						   class=>"ep_form_internal_button"));

  $xhtml->appendChild($self->render_value($session, $value));

  return $xhtml;
}

sub render_single_value 
{
  my( $self, $session, $value ) = @_;

  my $uri = "data:image/jpeg;base64," . $value;
  return $session->xml->create_element("img", src => $uri);
}

sub has_internal_action 
{
  my ($self, $basename) = @_;

  my $ibutton = $self->{repository}->get_internal_button;

  return ($ibutton eq "${basename}_upload")
}

1;

