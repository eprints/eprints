######################################################################
#
# EPrints::Page::DOM
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

package EPrints::Page::DOM;

our @ISA = qw/ EPrints::Page /;

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

