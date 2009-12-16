######################################################################
#
# EPrints::Page::Text
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

package EPrints::Page::Text;

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

