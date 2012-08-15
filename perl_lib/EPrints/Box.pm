######################################################################
#
# EPrints::Box
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::Box> - Class to render cute little collapsable/expandable Web 2.0ish boxes.

=head1 SYNOPSIS

	use EPrints;

	# an XHTML DOM box with a title and some content that starts rolled up.
	EPrints::Box(
		   handle => $handle,
		       id => "my_box",
		    title => $my_title_dom,
		  content => $my_content_dom,
		collapsed => 1,
	); 


=head1 DESCRIPTION

This just provides a function to render boxes in the EPrints style.

=cut

package EPrints::Box;

use strict;

######################################################################
=pod

=over 4

=item $box_xhtmldom = EPrints::Box::render( %options )

Deprecated, use L<EPrints::XHTML/box>.

=back

=cut
######################################################################

sub EPrints::Box::render
{
	my( %options ) = @_;

	$options{show_label} = $options{title};
	$options{hide_label} = $options{session}->xml->clone( delete $options{title} ),
	$options{basename} = delete $options{id};

	return $options{session}->xhtml->box( delete($options{content}), %options );

	# note: "content_style" is unsupported, which is a style to apply to a div
	# container around the contents.
}

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

