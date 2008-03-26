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

	my $localpath = $uri;
	$localpath.="index.html" if( $uri =~ m#/$# );
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

	my $session = new EPrints::Session(2); # don't open the CGI info
	my $eprint = EPrints::DataObj::EPrint->new( $session, $eprintid );
	if( defined $eprint )
	{
		$eprint->generate_static;
	}
	$session->terminate;
}

1;
