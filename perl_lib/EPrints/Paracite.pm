######################################################################
#
# EPrints::Paracite
#
######################################################################
#
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

=item $xhtml = EPrints::Paracite::render_reference( $session, $field, $value )

This function is intended to be passed by reference to the 
render_single_value property of a referencetext metadata field. Each
reference will then be rendered as a link to a CGI script. 

=cut
######################################################################

sub render_reference
{
	my( $session , $field , $value ) = @_;
	
	my $i=0;
	my $mode = 0;
	my $html = $session->make_doc_fragment();
	my $perlurl = $session->get_repository->get_conf( 
		"http_cgiurl" );
	my $baseurl = $session->get_repository->get_conf( 
		"http_url" );

	# Loop through all references
	my @references = split "\n", $value;	
	return $html unless ( scalar @references > 0 );

	foreach my $reference (@references)
	{
		next if( $reference =~ /^\s*$/ );

		my $form = $session->render_form( 'post', $perlurl.'/paracite' );
		my $p = $session->make_element(
			"p", 
			class=>"citation_reference" );
		$form->appendChild( $p );
		$p->appendChild( $session->make_text( $reference." " ) );
		$p->appendChild( $session->make_element( 'input', name=>'action', value=>'1', type=>'image', src=>$baseurl."/images/reflink.png" ) );
		$p->appendChild( $session->make_element( 'input', name=>'ref', value=>$reference, type=>'hidden' ) );
		$html->appendChild( $form );		
	}

	return $html;
}

######################################################################
=pod

=back

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

