######################################################################
#
# EPrints::Paracite
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Paracite> - Module for rendering reference blocks into links. 

=head1 DESCRIPTION

If your repository allows users to specify references in a reference field,
you can use this function.

=over 4

=cut

######################################################################

package EPrints::Paracite;

use strict;

######################################################################
=pod

=item $xhtml = EPrints::Paracite::render_reference( $handle, $field, $value )

This function is intended to be passed by reference to the 
render_single_value property of a referencetext metadata field. Each
reference will then be rendered as a link to a CGI script. 

=cut
######################################################################

sub render_reference
{
	my( $handle , $field , $value ) = @_;
	
	my $i=0;
	my $mode = 0;
	my $html = $handle->make_doc_fragment();
	my $perlurl = $handle->get_repository->get_conf( 
		"http_cgiurl" );
	my $baseurl = $handle->get_repository->get_conf( 
		"http_url" );

	# Loop through all references
	my @references = split "\n", $value;	
	return $html unless ( scalar @references > 0 );

	foreach my $reference (@references)
	{
		next if( $reference =~ /^\s*$/ );

		my $form = $handle->render_form( 'post', $perlurl.'/paracite' );
		my $p = $handle->make_element(
			"p", 
			class=>"citation_reference" );
		$form->appendChild( $p );
		$p->appendChild( $handle->make_text( $reference." " ) );
		$p->appendChild( $handle->make_element( 'input', name=>'action', value=>'1', type=>'image', src=>$baseurl."/images/reflink.png" ) );
		$p->appendChild( $handle->make_element( 'input', name=>'ref', value=>$reference, type=>'hidden' ) );
		$html->appendChild( $form );		
	}

	return $html;
}

######################################################################
=pod

=back

=cut
1;

