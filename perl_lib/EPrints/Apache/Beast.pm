=head1 NAME

EPrints::Apache::Beast

=cut


# To go in Rewrite:
# use EPrints::Apache::Beast;
# if( !-e $filename && -e "$filename.link" )
# {
# 	$r->set_handlers(PerlResponseHandler => \&EPrints::Apache::Beast::handler );
# }


package EPrints::Apache::Beast;

use EPrints::Apache::AnApache; # exports apache constants
use Honey;

sub handler
{
	my( $request ) = @_;

	my $filename = $request->filename();

	open( LINK, "$filename.link" );
	my $mimetype = <LINK>;
	my $oid = <LINK>;
	close LINK;
	chomp $mimetype;
	chomp $oid;

	EPrints::Apache::AnApache::header_out($request, "Content-type"=>$mimetype );
	my $honey = Honey->new( "hc-data", 8080 );
	print $honey->string_oid( $oid );
	$honey->print_error if( $honey->error );

	return OK;
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

