######################################################################
#
# EPrints::Apache::Template
#
######################################################################
#
#
######################################################################


=pod

=head1 NAME

B<EPrints::Apache::Template> - Template Applying Module

=head1 DESCRIPTION

This module is consulted when any file is serverd. It applies the
EPrints template.

=over 4

=cut

package EPrints::Apache::Template;

use CGI;
use FileHandle;

use EPrints::Apache::AnApache; # exports apache constants

use strict;



######################################################################
#
# EPrints::Apache::VLit::handler( $r )
#
######################################################################

sub handler
{
	my( $r ) = @_;

	my $filename = $r->filename;

	return DECLINED unless( $filename =~ s/\.html$// );

	return DECLINED unless( -r $filename.".page" );

	my $session = new EPrints::Session;

	my $parts;
	foreach my $part ( "title", "title.textonly", "page", "head", "template" )
	{
		if( !-e $filename.".".$part )
		{
			$parts->{"utf-8.".$part} = "";
			next;
		}
		if( open( CACHE, $filename.".".$part ) ) 
		{
			binmode(CACHE,":utf8");
			$parts->{"utf-8.".$part} = join("",<CACHE>);
			close CACHE;
		}
		else
		{
			$parts->{"utf-8.".$part} = "";
			$session->get_repository->log( "Could not read ".$filename.".".$part );
		}
	}

	$session->{preparing_static_page} = 1; 

	$parts->{login_status} = EPrints::ScreenProcessor->new(
		session => $session,
	)->render_toolbar;
	
	my $template = delete $parts->{"utf-8.template"};
	chomp $template;
	$template = 'default' if $template eq "";
	$session->prepare_page( $parts, page_id=>"static", template=>$template );
	$session->send_page;

	delete $session->{preparing_static_page};

	$session->terminate;


	return OK;
}








1;

######################################################################
=pod

=back

=cut


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

