######################################################################
#
# EPrints::Page
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::Page> - A Webpage 

=head1 DESCRIPTION

This class describes a webpage suitable for serving via mod_perl or writing to a file.

=over 4

=item $page = $repository->xhtml->page( { title => ..., body => ... }, %options );

Construct a new page.

=item $page->send( [%options] )

Send this page via the current HTTP connection. 

=cut

=item $page->write_to_file( $filename )

Write this page to the given filename.

=back

=cut

package EPrints::Page;

sub new
{
	my( $class, $repository, $xhtml_page, %options ) = @_;

	EPrints::Utils::process_parameters( \%options, {
		   add_doctype => 1,
	});

	return bless { repository=>$repository, xhtml_page=>$xhtml_page, %options }, $class;
}

sub send_header
{
	my( $self, %options ) = @_;

	$self->{repository}->send_http_header( %options );
	if( $self->{add_doctype} )
	{
		print <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
END
	}
}

sub send
{
	my( $self, %options ) = @_;

	EPrints::abort( "\$page->send(..) must be subclassed." );
}

sub write_to_file
{
	my( $self, $filename ) = @_;

	EPrints::abort( "\$page->write_to_file(..) must be subclassed." );
}

1;

