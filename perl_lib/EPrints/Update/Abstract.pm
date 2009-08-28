######################################################################
#
# EPrints::Update::Abstract
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

B<EPrints::Update::Abstract

=head1 DESCRIPTION

Update item summary web pages on demand.

=over 4

=cut

package EPrints::Update::Abstract;

use Data::Dumper;

use strict;
  
sub update
{
	my( $repository, $lang, $eprintid, $uri ) = @_;

	my $localpath = sprintf("%08d", $eprintid);
	$localpath =~ s/(..)/\/$1/g;
	$localpath = "/archive" . $localpath . "/index.html";

	my $targetfile = $repository->get_conf( "htdocs_path" )."/".$lang.$localpath;

	my $need_to_update = 0;

	if( !-e $targetfile ) 
	{
		$need_to_update = 1;
	}

	my $timestampfile = $repository->get_conf( "variables_path" )."/abstracts.timestamp";	
	if( -e $timestampfile && -e $targetfile )
	{
		my $poketime = (stat( $timestampfile ))[9];
		my $targettime = (stat( $targetfile ))[9];
		if( $targettime < $poketime ) { $need_to_update = 1; }
	}

	return unless $need_to_update;

	# There is an abstracts file, AND we're looking
	# at serving an abstract page, AND the abstracts timestamp
	# file is newer than the abstracts page...
	# so try and regenerate the abstracts page.

	my $handle = EPrints->get_repository_handle( consume_post_data=>0 );
	my $eprint = $handle->get_eprint( $eprintid );
	if( defined $eprint )
	{
		$eprint->generate_static;
	}
	$handle->terminate;
}

1;
