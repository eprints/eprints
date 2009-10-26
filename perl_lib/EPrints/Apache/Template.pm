######################################################################
#
# EPrints::Apache::Template
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
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

	return DECLINED unless( $filename =~ s/.html$// );

	return DECLINED unless( -r $filename.".page" );

	my $repository = $EPrints::HANDLE->current_repository;

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
			$repository->log( "Could not read ".$filename.".".$part );
		}
	}

	
	my $template = delete $parts->{"utf-8.template"};
	chomp $template;
	$template = 'default' if $template eq "";
	local $repository->{preparing_static_page} = 1; 
	$repository->prepare_page( $parts, page_id=>"static", template=>$template );
	delete $repository->{preparing_static_page};
	$repository->send_page;

	return OK;
}








1;

######################################################################
=pod

=back

=cut

