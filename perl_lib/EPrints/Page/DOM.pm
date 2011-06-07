=head1 NAME

EPrints::Page::DOM

=cut

######################################################################
#
# EPrints::Page::DOM
#
######################################################################
#
#
######################################################################

package EPrints::Page::DOM;

@ISA = qw/ EPrints::Page /;

use strict;

sub new
{
	my( $class, $repository, $page_dom, %options ) = @_;

	EPrints::Utils::process_parameters( \%options, {
		   add_doctype => 1,
	});

	return bless { repository=>$repository, page_dom=>$page_dom, %options }, $class;
}

sub send
{
	my( $self, %options ) = @_;

	if( !defined $self->{page_dom} ) 
	{
		EPrints::abort( "Attempt to send the same page object twice!" );
	}

	binmode(STDOUT,":utf8");

	$self->send_header( %options );

	eval { print EPrints::XML::to_string( $self->{page_dom}, undef, 1 ); };
	if( $@ && $@ !~ m/^Software caused connection abort/ )
	{
		EPrints::abort( "Error in send_page: $@" );	
	}

	EPrints::XML::dispose( $self->{page_dom} );
	delete $self->{page_dom};
}

sub write_to_file
{
	my( $self, $filename, $wrote_files ) = @_;
	
	if( !defined $self->{page_dom} ) 
	{
		EPrints::abort( "Attempt to write the same page object twice!" );
	}

	EPrints::XML::write_xhtml_file( $self->{page_dom}, $filename, add_doctype=>$self->{add_doctype} );

	if( defined $wrote_files )
	{
		$wrote_files->{$filename} = 1;
	}

	EPrints::XML::dispose( $self->{page_dom} );
	delete $self->{page_dom};
}


sub DESTROY
{
	my( $self ) = @_;

	if( defined $self->{page_dom} )
	{
		EPrints::XML::dispose( $self->{page_dom} );
	}
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

