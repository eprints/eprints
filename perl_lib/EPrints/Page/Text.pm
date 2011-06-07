=head1 NAME

EPrints::Page::Text

=cut

######################################################################
#
# EPrints::Page::Text
#
######################################################################
#
#
######################################################################

package EPrints::Page::Text;

@ISA = qw/ EPrints::Page /;

use strict;

sub new
{
	my( $class, $repository, $page_text, %options ) = @_;

	EPrints::Utils::process_parameters( \%options, {
		   add_doctype => 1,
	});

	return bless { repository=>$repository, page_text=>$page_text, %options }, $class;
}

sub send
{
	my( $self, %options ) = @_;

	if( !defined $self->{page_text} ) 
	{
		EPrints::abort( "Attempt to send the same page object twice!" );
	}

	binmode(STDOUT,":utf8");

	$self->send_header( %options );

	eval { print $self->{page_text}; };
	if( $@ && $@ !~ m/^Software caused connection abort/ )
	{
		EPrints::abort( "Error in send_page: $@" );	
	}

	delete $self->{page_text};
}

sub write_to_file
{
	my( $self, $filename, $wrote_files ) = @_;
	
	if( !defined $self->{page_text} ) 
	{
		EPrints::abort( "Attempt to write the same page object twice!" );
	}

	unless( open( XMLFILE, ">$filename" ) )
	{
		EPrints::abort( <<END );
Can't open to write to XML file: $filename
END
	}

	if( defined $wrote_files )
	{
		$wrote_files->{$filename} = 1;
	}

	binmode(XMLFILE,":utf8");
	if( $self->{add_doctype} )
	{
		print XMLFILE <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
END
	}
	print XMLFILE $self->{page_text};
	close XMLFILE;

	delete $self->{page_text};
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

