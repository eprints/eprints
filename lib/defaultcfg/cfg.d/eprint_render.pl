
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

=item $xhtmlfragment = eprint_render( $eprint, $handle, $preview )

This subroutine takes an eprint object and renders the XHTML view
of this eprint for public viewing.

Takes two arguments: the L<$eprint|EPrints::DataObj::EPrint> to render and the current L<$handle|EPrints::RepositoryHandle>.

Returns three XHTML DOM fragments (see L<EPrints::XML>): C<$page>, C<$title>, (and optionally) C<$links>.

If $preview is true then this is only being shown as a preview.
(This is used to stop the "edit eprint" link appearing when it makes
no sense.)

=cut

######################################################################

$c->{eprint_render} = sub
{
	my( $eprint, $handle, $preview ) = @_;

	my $succeeds_field = $handle->get_repository->get_dataset( "eprint" )->get_field( "succeeds" );
	my $commentary_field = $handle->get_repository->get_dataset( "eprint" )->get_field( "commentary" );

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
		if( $latest->get_value( "eprintid" ) == $eprint->get_value( "eprintid" ) )
		{
			$fragments{multi_info} = $handle->html_phrase( "page:latest_version" );
		}
		else
		{
			$fragments{multi_info} = $handle->render_message(
				"warning",
				$handle->html_phrase( 
					"page:not_latest_version",
					link => $handle->render_link( $latest->get_url() ) ) );
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
	my $authors = $eprint->get_value( "creators" );
	my $first_author = $authors->[0];
	my $url ="http://demo.exlibrisgroup.com:9003/demo?";
	#my $url = "http://aire.cab.unipd.it:9003/unipr?";
	$url .= "title=".$eprint->get_value( "title" );
	$url .= "&aulast=".$first_author->{name}->{family};
	$url .= "&aufirst=".$first_author->{name}->{family};
	$url .= "&date=".$eprint->get_value( "date" );
	$fragments{sfx_url} = $url;
}

if(0){
	# Experimental OVID Link
	my $authors = $eprint->get_value( "creators" );
	my $first_author = $authors->[0];
	my $url ="http://linksolver.ovid.com/OpenUrl/LinkSolver?";
	$url .= "atitle=".$eprint->get_value( "title" );
	$url .= "&aulast=".$first_author->{name}->{family};
	$url .= "&date=".substr($eprint->get_value( "date" ),0,4);
	if( $eprint->is_set( "issn" ) ) { $url .= "&issn=".$eprint->get_value( "issn" ); }
	if( $eprint->is_set( "volume" ) ) { $url .= "&volume=".$eprint->get_value( "volume" ); }
	if( $eprint->is_set( "number" ) ) { $url .= "&issue=".$eprint->get_value( "number" ); }
	if( $eprint->is_set( "pagerange" ) )
	{
		my $pr = $eprint->get_value( "pagerange" );
		$pr =~ m/^([^-]+)-/;
		$url .= "&spage=$1";
	}
	$fragments{ovid_url} = $url;
}

	foreach my $key ( keys %fragments ) { $fragments{$key} = [ $fragments{$key}, "XHTML" ]; }
	
	$fragments{documents} = [ [$eprint->get_all_documents()], "STRING" ];

	my $page = $eprint->render_citation( "summary_page", %fragments, flags=>$flags );

	my $title = $eprint->render_description();

	my $links = $handle->make_doc_fragment();
	$links->appendChild( $handle->plugin( "Export::Simple" )->dataobj_to_html_header( $eprint ) );
	$links->appendChild( $handle->plugin( "Export::DC" )->dataobj_to_html_header( $eprint ) );

	return( $page, $title, $links );
};


