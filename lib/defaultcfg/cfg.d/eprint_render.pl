
######################################################################

=item $xhtmlfragment = eprint_render( $eprint, $session )

This subroutine takes an eprint object and renders the XHTML view
of this eprint for public viewing.

Takes two arguments: the L<$eprint|EPrints::DataObj::EPrint> to render and the current L<$session|EPrints::Session>.

Returns three XHTML DOM fragments (see L<EPrints::XML>): C<$page>, C<$title>, (and optionally) C<$links>.

=cut

######################################################################

$c->{eprint_render} = sub
{
	my( $eprint, $session ) = @_;

	my $succeeds_field = $session->get_repository->get_dataset( "eprint" )->get_field( "succeeds" );
	my $commentary_field = $session->get_repository->get_dataset( "eprint" )->get_field( "commentary" );
	my $has_multiple_versions = $eprint->in_thread( $succeeds_field );

	my( $page, $p, $a );

	$page = $session->make_doc_fragment;
	# Citation
	$p = $session->make_element( "p" );
	$p->appendChild( $eprint->render_citation() );
	$page->appendChild( $p );

	# Put in a message describing how this document has other versions
	# in the repository if appropriate
	if( $has_multiple_versions )
	{
		my $latest = $eprint->last_in_thread( $succeeds_field );

		if( $latest->get_value( "eprintid" ) == $eprint->get_value( "eprintid" ) )
		{
			$page->appendChild( $session->html_phrase( 
						"page:latest_version" ) );
		}
		else
		{
			$page->appendChild( $session->html_phrase( 
				"page:not_latest_version",
				link => $session->render_link( $latest->get_url() ) ) );
		}
	}		

	# Contact email address
	my $has_contact_email = 0;
	if( $session->get_repository->can_call( "email_for_doc_request" ) )
	{
		if( defined( $session->get_repository->call( "email_for_doc_request", $session, $eprint ) ) )
		{
			$has_contact_email = 1;
		}
	}

	# Available documents
	my @documents = $eprint->get_all_documents();

	my $docs_to_show = scalar @documents;

	# look for any coverimage document
	foreach( @documents )
	{
		next unless ( $_->get_value( "format" ) eq "coverimage" );

		$page->appendChild( $session->make_element(
			"img",
			align=>"left",
			style=>"padding-right: 0.5em; padding-bottom: 0.5em;",
			src=>$_->get_url(),
			alt=>$_->get_value( "formatdesc" ) ) );
		--$docs_to_show;	
	}

	$p = $session->make_element( "p" );
	$page->appendChild( $p );

	if( $docs_to_show == 0 )
	{
		$p->appendChild( $session->html_phrase( "page:nofulltext" ) );
		if( $has_contact_email && $eprint->get_value( "eprint_status" ) eq "archive"  )
		{
			# "Request a copy" button
			my $form = $session->render_form( "post", $session->get_repository->get_conf( "perl_url" ) . "/request_doc" );
			$form->appendChild( $session->render_hidden_field( "eprintid", $eprint->get_id ) );
			$form->appendChild( $session->render_action_buttons( 
				"submit" => $session->phrase( "request:button" )
			) );
			$p->appendChild( $form );
		}
	}
	else
	{
		$p->appendChild( $session->html_phrase( "page:fulltext" ) );

		my( $doctable, $doctr, $doctd );
		$doctable = $session->make_element( "table" );

		foreach my $doc ( @documents )
		{
			next if( $doc->get_value( "format" ) eq "coverimage" );
	
			$doctr = $session->make_element( "tr" );
	
			$doctd = $session->make_element( "td" );
			$doctr->appendChild( $doctd );
			$doctd->appendChild( 
				$session->get_repository->call( "render_fileicon", 
					$session, 
					$doc->get_type, 
					$doc->get_url ) );
	
			$doctd = $session->make_element( "td" );
				$doctr->appendChild( $doctd );
			$doctd->appendChild( $doc->render_citation_link() );
			my %files = $doc->files;
			if( defined $files{$doc->get_main} )
			{
				my $size = $files{$doc->get_main};
				$doctd->appendChild( $session->make_element( 'br' ) );
				$doctd->appendChild( $session->make_text( EPrints::Utils::human_filesize($size) ));
			}

			if( $has_contact_email && !$doc->is_public && $eprint->get_value( "eprint_status" ) eq "archive" )
			{
				# "Request a copy" button
				$doctd = $session->make_element( "td" );
				my $form = $session->render_form( "post", $session->get_repository->get_conf( "perl_url" ) . "/request_doc" );
				$form->appendChild( $session->render_hidden_field( "docid", $doc->get_id ) );
				$form->appendChild( $session->render_action_buttons( 
					"submit" => $session->phrase( "request:button" )
				) );
				$doctd->appendChild( $form );
				$doctr->appendChild( $doctd );
			}

			$doctable->appendChild( $doctr );
		}
		$page->appendChild( $doctable );
	}	

	# Alternative locations
	if( $eprint->is_set( "official_url" ) )
	{
		$p = $session->make_element( "p" );
		$page->appendChild( $p );
		$p->appendChild( $session->html_phrase( "eprint_fieldname_official_url" ) );
		$p->appendChild( $session->make_text( ": " ) );
		$p->appendChild( $eprint->render_value( "official_url" ) );
	}
	
	# Then the abstract
	if( $eprint->is_set( "abstract" ) )
	{
		my $h2 = $session->make_element( "h2" );
		$h2->appendChild( 
			$session->html_phrase( "eprint_fieldname_abstract" ) );
		$page->appendChild( $h2 );

		$p = $session->make_element( "p" );
		$p->appendChild( $eprint->render_value( "abstract" ) );
		$page->appendChild( $p );
	}
	else
	{
		$page->appendChild( $session->make_element( 'br' ) );
	}
	
	my( $table, $tr, $td, $th );	# this table needs more class cjg
	$table = $session->make_element( "table",
					border=>"0",
					cellpadding=>"3" );
	$page->appendChild( $table );

	# Commentary
	if( $eprint->is_set( "commentary" ) )
	{
		my $target = EPrints::DataObj::EPrint->new( 
			$session,
			$eprint->get_value( "commentary" ),
			$session->get_repository()->get_dataset( "archive" ) );
		if( defined $target )
		{
			$table->appendChild( $session->render_row(
				$session->html_phrase( 
					"eprint_fieldname_commentary" ),
				$target->render_citation_link() ) );
		}
	}

	my $frag = $session->make_doc_fragment;
	$frag->appendChild( $eprint->render_value( "type"  ) );
	my $type = $eprint->get_value( "type" );
	if( $type eq "conference_item" )
	{
		$frag->appendChild( $session->make_text( " (" ));
		$frag->appendChild( $eprint->render_value( "pres_type"  ) );
		$frag->appendChild( $session->make_text( ")" ));
	}
	if( $type eq "monograph" )
	{
		$frag->appendChild( $session->make_text( " (" ));
		$frag->appendChild( $eprint->render_value( "monograph_type"  ) );
		$frag->appendChild( $session->make_text( ")" ));
	}
	if( $type eq "thesis" )
	{
		$frag->appendChild( $session->make_text( " (" ));
		$frag->appendChild( $eprint->render_value( "thesis_type"  ) );
		$frag->appendChild( $session->make_text( ")" ));
	}
	$table->appendChild( $session->render_row(
		$session->html_phrase( "eprint_fieldname_type" ),
		$frag ));

	# Additional Info
	if( $eprint->is_set( "note" ) )
	{
		$table->appendChild( $session->render_row(
			$session->html_phrase( "eprint_fieldname_note" ),
			$eprint->render_value( "note" ) ) );
	}


	# Keywords
	if( $eprint->is_set( "keywords" ) )
	{
		$table->appendChild( $session->render_row(
			$session->html_phrase( "eprint_fieldname_keywords" ),
			$eprint->render_value( "keywords" ) ) );
	}



	# Subjects...
	$table->appendChild( $session->render_row(
		$session->html_phrase( "eprint_fieldname_subjects" ),
		$eprint->render_value( "subjects" ) ) );

	$table->appendChild( $session->render_row(
		$session->html_phrase( "page:id_code" ),
		$eprint->render_value( "eprintid" ) ) );

	my $user = new EPrints::DataObj::User( 
			$eprint->{session},
 			$eprint->get_value( "userid" ) );
	my $usersname;
	if( defined $user )
	{
		$usersname = $session->make_element( "a", 
				href=>$eprint->{session}->get_repository->get_conf( "perl_url" )."/user?userid=".$user->get_value( "userid" ) );
		$usersname->appendChild( 
			$user->render_description() );
	}
	else
	{
		$usersname = $session->html_phrase( "page:invalid_user" );
	}

	$table->appendChild( $session->render_row(
		$session->html_phrase( "page:deposited_by" ),
		$usersname ) );

	if( $eprint->is_set( "datestamp" ) )
	{
		$table->appendChild( $session->render_row(
			$session->html_phrase( "page:deposited_on" ),
			$eprint->render_value( "datestamp" ) ) );
	}

	if( $eprint->is_set( "lastmod" ) )
	{
		$table->appendChild( $session->render_row(
			$session->html_phrase( "eprint_fieldname_lastmod" ),
			$eprint->render_value( "lastmod" ) ) );
	}


	# Now show the version and commentary response threads
	if( $has_multiple_versions )
	{
		$page->appendChild( 
			$session->html_phrase( "page:available_versions" ) );
		$page->appendChild( 
			$eprint->render_version_thread( $succeeds_field ) );
	}
	
	if( $eprint->in_thread( $commentary_field ) )
	{
		$page->appendChild( 
			$session->html_phrase( "page:commentary_threads" ) );
		$page->appendChild( 
			$eprint->render_version_thread( $commentary_field ) );
	}

if(0){	
	# Experimental SFX Link
	my $url ="http://demo.exlibrisgroup.com:9003/demo?";
	#my $url = "http://aire.cab.unipd.it:9003/unipr?";
	$url .= "title=".$eprint->get_value( "title" );
	$url .= "&";
	my $authors = $eprint->get_value( "creators" );
	my $first_author = $authors->[0];
	$url .= "aulast=".$first_author->{name}->{family};
	$url .= "&";
	$url .= "aufirst=".$first_author->{name}->{family};
	$url .= "&";
	$url .= "date=".$eprint->get_value( "date" );
	my $sfx_block = $session->make_element( "p" );
	$page->appendChild( $sfx_block );
	my $sfx_link = $session->render_link( $url );
	$sfx_block->appendChild( $sfx_link );
	$sfx_link->appendChild( $session->make_text( "SFX" ) );
}

if(0){
	# Experimental OVID Link
	my $url ="http://linksolver.ovid.com/OpenUrl/LinkSolver?";
	$url .= "atitle=".$eprint->get_value( "title" );
	$url .= "&";
	my $authors = $eprint->get_value( "creators" );
	my $first_author = $authors->[0];
	$url .= "aulast=".$first_author->{name}->{family};
	$url .= "&";
	$url .= "date=".substr($eprint->get_value( "date" ),0,4);
	if( $eprint->is_set( "issn" ) )
	{
		$url .= "&issn=".$eprint->get_value( "issn" );
	}
	if( $eprint->is_set( "volume" ) )
	{
		$url .= "&volume=".$eprint->get_value( "volume" );
	}
	if( $eprint->is_set( "number" ) )
	{
		$url .= "&issue=".$eprint->get_value( "number" );
	}
	if( $eprint->is_set( "pagerange" ) )
	{
		my $pr = $eprint->get_value( "pagerange" );
		$pr =~ m/^([^-]+)-/;
		$url .= "&spage=$1";
	}

	my $ovid_block = $session->make_element( "p" );
	$page->appendChild( $ovid_block );
	my $ovid_link = $session->render_link( $url );
	$ovid_block->appendChild( $ovid_link );
	$ovid_link->appendChild( $session->make_text( "OVID" ) );
}



	# Add a link to the edit-page for this record. Handy for staff.
	my $edit_para = $session->make_element( "p", align=>"right" );
	$edit_para->appendChild( $session->html_phrase( 
		"page:edit_link",
		link => $session->render_link( $eprint->get_control_url ) ) );
	$page->appendChild( $edit_para );

	my $title = $eprint->render_description();

	my $links = $session->make_doc_fragment();

	$links->appendChild( $session->make_element( 
		"link",
		rel => "schema.DC",
		href => "http://purl.org/DC/elements/1.0/" ) );
	my $dcplugin = $session->plugin( "Export::DC" );
	my $dc = $dcplugin->convert_dataobj( $eprint );
	foreach( @{$dc} )
	{
		$links->appendChild( $session->make_element( 
			"meta",
			name => "DC.".$_->[0],
			content => $_->[1] ) );
	}

	return( $page, $title, $links );
};


