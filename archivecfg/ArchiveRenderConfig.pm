######################################################################
#
#  Site Render Config
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
# __LICENSE__
#
######################################################################
#
# Rendering Routines
#
#   Functions which convert archive data into a human readable form.
#
#   A couple of these routines return UTF8 encoded strings, but the
#   others return DOM structures. See the docs for more information
#   about this.
#   
#   Anywhere text is set, it is requested from the archive phrases
#   XML file, in case you are running the archive in more than one
#   language.
#
#   Hopefully when we are in beta the'll be an alternative version
#   of this config for single language archives.
#
#---------------------------------------------------------------------


######################################################################
#
# $xhtmlfragment = eprint_render( $eprint, $session )
#
######################################################################
# $eprint
# - the EPrints::User to be rendered
# $session
# - the current EPrints::Session
#
# returns: ( $xhtmlfragment, $title, $links )
# - 3 XHTML DOM fragments - the page, the title and (optionally) the
# metadata links to place in the webpage header.
######################################################################
# This subroutine takes an eprint object and renders the XHTML view
# of this eprint for public viewing.
#
######################################################################

sub eprint_render
{
	my( $eprint, $session ) = @_;

	my $succeeds_field = $session->get_archive()->get_dataset( "eprint" )->get_field( "succeeds" );
	my $commentary_field = $session->get_archive()->get_dataset( "eprint" )->get_field( "commentary" );
	my $has_multiple_versions = $eprint->in_thread( $succeeds_field );

	my( $page, $p, $a );

	$page = $session->make_doc_fragment;

	# Citation
	$p = $session->make_element( "p" );
	$p->appendChild( $eprint->render_citation() );
	$page->appendChild( $p );

	# Put in a message describing how this document has other versions
	# in the archive if appropriate
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

	# This is where the cover image, if any, will go
	# we can append stuff to it in a minute.
	my $imagetable = $session->make_element( "table", border=>0 );
	my $imagetr = $session->make_element( "tr" );
	my $imagetd = $session->make_element( "td" );
	my $docstd = $session->make_element( "td" );
	
	$page->appendChild( $imagetable );
	$imagetable->appendChild( $imagetr );
	$imagetr->appendChild( $imagetd );
	$imagetr->appendChild( $docstd );

	# Available documents
	my @documents = $eprint->get_all_documents();

	$p = $session->make_element( "p" );
	$p->appendChild( $session->html_phrase( "page:fulltext" ) );
	foreach( @documents )
	{
		if( $_->get_value( "format" ) eq "coverimage" )
		{
			$imagetd->appendChild( $session->make_element(
				"img",
				align=>"left",
				src=>$_->get_url(),
				alt=>$_->get_value( "formatdesc" ) ) );
			next;
		}
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $_->render_citation_link() );
	}
	$docstd->appendChild( $p );


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
	
	my( $table, $tr, $td, $th );	# this table needs more class cjg
	$table = $session->make_element( "table",
					border=>"0",
					cellpadding=>"3" );
	$page->appendChild( $table );

	# Commentary
	if( $eprint->is_set( "commentary" ) )
	{
		my $target = EPrints::EPrint->new( 
			$session,
			$eprint->get_value( "commentary" ),
			$session->get_archive()->get_dataset( "archive" ) );
		if( defined $target )
		{
			$table->appendChild( _render_row(
				$session,
				$session->html_phrase( 
					"eprint_fieldname_commentary" ),
				$target->render_citation_link() ) );
		}
	}

	# Keywords
	if( $eprint->is_set( "keywords" ) )
	{
		$table->appendChild( _render_row(
			$session,
			$session->html_phrase( "eprint_fieldname_keywords" ),
			$eprint->render_value( "keywords" ) ) );
	}

	# Subjects...
	$table->appendChild( _render_row(
		$session,
		$session->html_phrase( "eprint_fieldname_subjects" ),
		$eprint->render_value( "subjects" ) ) );

	$table->appendChild( _render_row(
		$session,
		$session->html_phrase( "page:id_code" ),
		$eprint->render_value( "eprintid" ) ) );

	my $user = new EPrints::User( 
			$eprint->{session},
 			$eprint->get_value( "userid" ) );
	my $usersname;
	if( defined $user )
	{
		$usersname = $session->make_element( "a", 
				href=>$eprint->{session}->get_archive()->get_conf( "perl_url" )."/user?userid=".$user->get_value( "userid" ) );
		$usersname->appendChild( 
			$user->render_description() );
	}
	else
	{
		$usersname = $session->html_phrase( "page:invalid_user" );
	}

	$table->appendChild( _render_row(
		$session,
		$session->html_phrase( "page:deposited_by" ),
		$usersname ) );

	$table->appendChild( _render_row(
		$session,
		$session->html_phrase( "page:deposited_on" ),
		$eprint->render_value( "datestamp" ) ) );

	# Alternative locations
	if( $eprint->is_set( "altloc" ) )
	{
		$table->appendChild( _render_row(
			$session,
			$session->html_phrase( "eprint_fieldname_altloc" ),
			$eprint->render_value( "altloc" ) ) );
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

	my $title = $eprint->render_description();

	my $links = $session->make_doc_fragment();
	# This function is in ArchiveOAIConfig.pm, but using it here
	# saves duplicating code.
	$links->appendChild( $session->make_element( 
		"link",
		rel => "schema.DC",
		href => "http://purl.org/DC/elements/1.0/" ) );
	my @dc = eprint_to_unqualified_dc( $eprint, $session );
	foreach( @dc )
	{
		$links->appendChild( $session->make_element( 
			"meta",
			name => "DC.".$_->[0],
			content => $_->[1] ) );
	}

	return( $page, $title, $links );
}

######################################################################
#
# $xhtmlfragment = eprint_render_full( $eprint, $session )
#
######################################################################
# $eprint
# - the EPrints::User to be rendered
# $session
# - the current EPrints::Session
#
# returns: $xhtmlfragment
# - a pair of XHTML DOM fragments - the page and the title.
######################################################################
# This subroutine takes an eprint object and renders the XHTML view
# of this eprint for viewing by editors and the person depositing
# it. It should show all fields so they can be approved/checked.
# 
# By default it uses eprint_render to generate a view of the normal
# abstract page.
#
######################################################################

sub eprint_render_full
{
	my( $eprint, $session ) = @_;

	my( $page, $p, $a );
	$page = $session->make_doc_fragment;

	$page->appendChild( $session->html_phrase( 
		"page:abstract_intro" ) );

	my( $table, $tr, $td );
	$table = $session->make_element( "table", border=>1, cellpadding=>20 );
	$page->appendChild( $table );
	my( $abstractpage, $title ) = eprint_render( $eprint, $session );

	$tr = $session->make_element( "tr" );
	$td = $session->make_element( "td", bgcolor=>"#e0e0e0" );
	$table->appendChild( $tr );
	$tr->appendChild( $td );
	$td->appendChild( $abstractpage );


	if( $eprint->is_set( "suggestions" ) )
	{
		$table = $session->make_element( "table", border=>1, cellpadding=>20 );
		$page->appendChild( $session->html_phrase( "page:suggestions_intro" ) );
		$page->appendChild( $table );
	
		$tr = $session->make_element( "tr" );
		$td = $session->make_element( "td" );
		$table->appendChild( $tr );
		$tr->appendChild( $td );
		$td->appendChild( $eprint->render_value( "suggestions" ) );
	}



	# Show all the other fields
	$page->appendChild( $session->html_phrase( 
		"page:allfields_intro" ) );
	$table = $session->make_element( "table",
				border=>"0",
				cellpadding=>"3" );
	$page->appendChild( $table );
	my $field;
	foreach $field ( $eprint->get_dataset()->get_type_fields(
		  $eprint->get_value( "type" ) ) )
	{
		$table->appendChild( _render_row(
			$session,
			$session->make_text( 
				$field->display_name( $session ) ),	
			$eprint->render_value( 
				$field->get_name(), 
				1 ) ) );

	}

	return( $page, $title );			
}

######################################################################
#
# $dom_tr = _render_row( $session, $key, $value )
#
######################################################################
# Used by eprint_render, user_render_full and eprint_render_full to 
# turn a key and value into an html table row. 
#
# Returns DOM representing:
# <tr><th>$key:</th><td>$value</td></tr>
#
######################################################################

sub _render_row
{
	my( $session, $key, $value ) = @_;

	my( $tr, $th, $td );

	$tr = $session->make_element( "tr" );

	$th = $session->make_element( "th" ); 
	$th->appendChild( $key );
	$th->appendChild( $session->make_text( ":" ) );
	$tr->appendChild( $th );

	$td = $session->make_element( "td" ); 
	$td->appendChild( $value );
	$tr->appendChild( $td );

	return $tr;
}



######################################################################
#
# $xhtmlfragment = user_render( $user, $session )
#
######################################################################
# $user
# - the EPrints::User to be rendered
# $session
# - the current EPrints::Session
#
# returns: $xhtmlfragment
# - a XHTML DOM fragment 
######################################################################
# This subroutine takes a user object and renders the XHTML view
# of this user for public viewing.
#
######################################################################


sub user_render
{
	my( $user, $session ) = @_;

	my $html;	

	my( $info, $p, $a );
	$info = $session->make_doc_fragment;

	# Render the public information about this user.
	$p = $session->make_element( "p" );
	$p->appendChild( $user->render_description() );
	# Address, Starting with dept. and organisation...
	if( $user->is_set( "dept" ) )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $user->render_value( "dept" ) );
	}
	if( $user->is_set( "org" ) )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $user->render_value( "org" ) );
	}
	if( $user->is_set( "address" ) )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $user->render_value( "address" ) );
	}
	if( $user->is_set( "country" ) )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $user->render_value( "country" ) );
	}
	$info->appendChild( $p );
	

	## E-mail and URL last, if available.
	if( $user->get_value( "hideemail" ) ne "TRUE" )
	{
		if( $user->is_set( "email" ) )
		{
			$p = $session->make_element( "p" );
			$p->appendChild( $user->render_value( "email" ) );
			$info->appendChild( $p );
		}
	}

	if( $user->is_set( "url" ) )
	{
		$p = $session->make_element( "p" );
		$p->appendChild( $user->render_value( "url" ) );
		$info->appendChild( $p );
	}
		

	return( $info );
}

######################################################################
#
# $xhtmlfragment = user_render_full( $user, $session )
#
######################################################################
# $user
# - the EPrints::User to be rendered
# $session
# - the current EPrints::Session
#
# returns: $xhtmlfragment
# - a XHTML DOM fragment 
######################################################################
# This subroutine takes a user object and renders the XHTML view
# of this user for viewing by system admins. It should show all
# the information.
#
######################################################################


sub user_render_full
{
	my( $user, $session ) = @_;

	my $html;	

	my( $info, $p, $a );
	$info = $session->make_doc_fragment;

	# Show all the fields
	my( $table );
	$table = $session->make_element( "table",
					border=>"0",
					cellpadding=>"3" );

	my @fields = $user->get_dataset()->get_fields( $user->get_value( "usertype" ) );
	my $field;
	foreach $field ( @fields )
	{
		my $name = $field->get_name();
		# Skip fields which are only used by eprints internals
		# and would just confuse the issue to print
		next if( $name eq "newemail" );
		next if( $name eq "newpassword" );
		next if( $name eq "pin" );
		next if( $name eq "pinsettime" );
		$table->appendChild( _render_row(
			$session,
			$session->make_text( 
				$field->display_name( $session ) ),	
			$user->render_value( $field->get_name(), 1 ) ) );

	}
	$info->appendChild( $table );
	
	return $info;
}

######################################################################
#
# $xhtmlfragment = render_value_with_id( $field, $session, $value,
#			$alllangs, $rendered );
#
######################################################################
# $field 
# - the EPrints::MetaField to which this value belongs
# $session
# - the current EPrints::Session
# $value
# - the metadata value structure (see docs)
# $alllangs
# - boolean flag (1 or 0) - are we rendering for just the current
# session language or showing all the data in the value.
# - $rendered
# XHTML DOM fragment containing the value rendered without any
# attention to the ID.
#
# returns: $xhtmlfragment
# - An XHTML DOM fragment containing the value rendered with 
# attention to the ID (or by default just $rendered)
#
######################################################################
# This function is used to madify how a field with an ID is rendered,
# By default it just returns the rendered value as it was passed. The
# most likely use for this function is to wrap the rendered value in
# an anchor ( <a href="foo"> </a> ), generating the URL as appropriate
# from the value's ID part.
#
######################################################################

sub render_value_with_id
{
	my( $field, $session, $value, $alllangs, $rendered ) = @_;

	# You might want to wrap the rendered value in an anchor, 
	# eg if the ID is a staff username
	# you may wish to link to their homepage. 

#cjg Link Baton?

# Simple Example:
#
#	if( $field->get_name() eq "SOMENAME" ) 
#	{	
#		my $fragment = $session->make_doc_fragment();
#		$fragment->appendChild( $rendered );
#		$fragment->appendChild( 
#			$session->make_text( " (".$value->{id}.")" ) );
#		return( $fragment );
#	}

	return( $rendered );
}


######################################################################
#
# $label = id_label( $field, $session, $id );
#
######################################################################
# $field 
# - the EPrints::MetaField to which this ID belongs
# $session
# - the current EPrints::Session
# $id
# - ID part of a single metadata value 
#
# returns: $label
# - XHTML DOM fragment describing human readable version of the ID.
#
######################################################################
# Used when browsing by an ID field, this is used to convert the ID
# to a displayable label. 
# 
# For example, if you are creating a browse-by for the authors ID
# then you might want them displayed as the authors name. How you do 
# this, if at all, depends very much on your data. By default it
# just returns the value of the ID it was passed.
#
# It will almost always just contain text. It could in theory contain
# an image. It will usually be wrapped in an anchor <a> </a> so it
# should not have any links in.
#
######################################################################

sub id_label
{
	my( $field, $session, $id ) = @_;

	return $session->make_text( $id );
}

# Return true to indicate the module loaded OK.
1;
