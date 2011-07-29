
$c->{summary_page_metadata} = [qw/
	commentary
	note
	keywords
	subjects
	divisions
	sword_depositor
	userid
	datestamp
	lastmod
/];

# IMPORTANT NOTE ABOUT SUMMARY PAGES
#
# While you can completely customise them using the perl subroutine
# below, it's easier to edit them via citation/eprint/summary_page.xml


######################################################################

=item $xhtmlfragment = eprint_render( $eprint, $repository, $preview )

This subroutine takes an eprint object and renders the XHTML view
of this eprint for public viewing.

Takes two arguments: the L<$eprint|EPrints::DataObj::EPrint> to render and the current L<$repository|EPrints::Session>.

Returns three XHTML DOM fragments (see L<EPrints::XML>): C<$page>, C<$title>, (and optionally) C<$links>.

If $preview is true then this is only being shown as a preview.
(This is used to stop the "edit eprint" link appearing when it makes
no sense.)

=cut

######################################################################

$c->{eprint_render} = sub
{
	my( $eprint, $repository, $preview ) = @_;

	my $succeeds_field = $repository->dataset( "eprint" )->field( "succeeds" );
	my $commentary_field = $repository->dataset( "eprint" )->field( "commentary" );

	my $flags = { 
		has_multiple_versions => $eprint->in_thread( $succeeds_field ),
		in_commentary_thread => $eprint->in_thread( $commentary_field ),
		preview => $preview,
	};
	my %fragments = ();

	# Put in a message describing how this document has other versions
	# in the repository if appropriate
	if( $flags->{has_multiple_versions} )
	{
		my $latest = $eprint->last_in_thread( $succeeds_field );
		if( $latest->value( "eprintid" ) == $eprint->value( "eprintid" ) )
		{
			$flags->{latest_version} = 1;
			$fragments{multi_info} = $repository->html_phrase( "page:latest_version" );
		}
		else
		{
			$fragments{multi_info} = $repository->render_message(
				"warning",
				$repository->html_phrase( 
					"page:not_latest_version",
					link => $repository->render_link( $latest->get_url() ) ) );
		}
	}		


	# Now show the version and commentary response threads
	if( $flags->{has_multiple_versions} )
	{
		$fragments{version_tree} = $eprint->render_version_thread( $succeeds_field );
	}
	
	if( $flags->{in_commentary_thread} )
	{
		$fragments{commentary_tree} = $eprint->render_version_thread( $commentary_field );
	}

if(0){	
	# Experimental SFX Link
	my $authors = $eprint->value( "creators" );
	my $first_author = $authors->[0];
	my $url ="http://demo.exlibrisgroup.com:9003/demo?";
	#my $url = "http://aire.cab.unipd.it:9003/unipr?";
	$url .= "title=".$eprint->value( "title" );
	$url .= "&aulast=".$first_author->{name}->{family};
	$url .= "&aufirst=".$first_author->{name}->{family};
	$url .= "&date=".$eprint->value( "date" );
	$fragments{sfx_url} = $url;
}

if(0){
	# Experimental OVID Link
	my $authors = $eprint->value( "creators" );
	my $first_author = $authors->[0];
	my $url ="http://linksolver.ovid.com/OpenUrl/LinkSolver?";
	$url .= "atitle=".$eprint->value( "title" );
	$url .= "&aulast=".$first_author->{name}->{family};
	$url .= "&date=".substr($eprint->value( "date" ),0,4);
	if( $eprint->is_set( "issn" ) ) { $url .= "&issn=".$eprint->value( "issn" ); }
	if( $eprint->is_set( "volume" ) ) { $url .= "&volume=".$eprint->value( "volume" ); }
	if( $eprint->is_set( "number" ) ) { $url .= "&issue=".$eprint->value( "number" ); }
	if( $eprint->is_set( "pagerange" ) )
	{
		my $pr = $eprint->value( "pagerange" );
		$pr =~ m/^([^-]+)-/;
		$url .= "&spage=$1";
	}
	$fragments{ovid_url} = $url;
}

	foreach my $key ( keys %fragments ) { $fragments{$key} = [ $fragments{$key}, "XHTML" ]; }
	
	my $page = $eprint->render_citation( "summary_page", %fragments, flags=>$flags );

	my $title = $eprint->render_citation("brief");

	my $links = $repository->xml()->create_document_fragment();
	if( !$preview )
	{
		$links->appendChild( $repository->plugin( "Export::Simple" )->dataobj_to_html_header( $eprint ) );
		$links->appendChild( $repository->plugin( "Export::DC" )->dataobj_to_html_header( $eprint ) );
	}

	return( $page, $title, $links );
};


