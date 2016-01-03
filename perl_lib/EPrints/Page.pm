######################################################################
#
# EPrints::Page
#
######################################################################
#
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
	my( $class, $repository, $page, %options ) = @_;

	EPrints::Utils::process_parameters( \%options, {
		   add_doctype => 1,
	});

	return bless { repository=>$repository, page=>$page, %options }, $class;
}

sub send_header
{
	my( $self, %options ) = @_;

	$self->{repository}->send_http_header( %options );
}

sub send
{
	my( $self, %options ) = @_;

	if( !defined $self->{page} ) 
	{
		EPrints::abort( "Attempt to send the same page object twice!" );
	}

	binmode(STDOUT, ":utf8");

	$self->send_header( %options );

	eval {
		if( $self->{add_doctype} )
		{
			print $self->{repository}->xhtml->doc_type;
		}
		print delete($self->{page});
	};
	if( $@ )
	{
		if(
			$@ !~ m/^Software caused connection abort/ &&
			$@ !~ m/:Apache2 IO write: \(104\) Connection reset by peer/ &&
			$@ !~ m/:Apache2 IO write: \(32\) Broken pipe/ &&
			$@ !~ m/:Apache2 IO write: \(70007\) The timeout specified has expired/
		  )
		{
			EPrints::abort( "Error in send_page: $@" );	
		}
		else
		{
			die $@;
		}
	}
}

# back-ported https://github.com/eprints/eprints/commit/7d3fe41fce984da63103824c94e4eee2c7b74fd3
sub write_to_file
{
	my( $self, $filename, $wrote_files ) = @_;

	if( !defined $self->{page} ) 
	{
		EPrints::abort( "Attempt to write the same page object twice!" );
	}

	if( open(my $fh, ">:utf8", $filename) )
	{
		if( $self->{add_doctype} )
		{
			print $fh $self->{repository}->xhtml->doc_type;
		}
		print $fh delete($self->{page});
		if( defined $wrote_files )
		{
			$wrote_files->{$filename} = 1;
		}
	}
	else
	{
		EPrints::abort( <<END );
Can't open to write to file: $filename
END
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

