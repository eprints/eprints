######################################################################
#
# EPrints::UserPage
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

B<EPrints::UserPage> - Render information about user records.

=head1 DESCRIPTION

This module contains methods for rendering the EPrints::User
object into a webpage.

=over 4

=cut

package EPrints::UserPage;

use strict;


######################################################################
=pod

=item $user = EPrints::UserPage::user_from_param( $session )

Return the EPrints::DataObj::User object that we want to render. If the
CGI parameter "userid" is set then that is used to identify the user.
If it is not set then the CGI parameter "username" is used to 
identify them.

If neither parameter is set or the user can't be found then a
page with an error message is sent to the browser.

=cut
######################################################################

sub user_from_param
{
	my( $session ) = @_;

	my $username = $session->param( "username" );
	my $userid = $session->param( "userid" );

	if( !EPrints::Utils::is_set( $username ) && !EPrints::Utils::is_set( $userid ) )
	{
		$session->render_error( $session->html_phrase( 
				"lib/userpage:no_user" ) );
		return;
	}
	my $user;
	if( EPrints::Utils::is_set( $userid ) )
	{
		$user = EPrints::DataObj::User->new( 
				$session, 
				$userid );
	}
	else
	{
		$user = EPrints::DataObj::User::user_with_username( 
				$session, 
				$username );
	}


	if( !defined $user )
	{
		$session->render_error( $session->html_phrase( 
				"lib/userpage:unknown_user" ) );
		return;
	}

	return $user;
}


######################################################################
=pod

=item EPrints::UserPage::process( $session, $staff )

Render a webpage with the information about a certain user. The
user rendered is decided by the parameters, see user_with_param.

If $staff is set then eprint_render_full is used rather than 
eprint_render.

=cut
######################################################################

sub process
{
	my( $session, $staff ) = @_;

	my $user = EPrints::UserPage::user_from_param( $session );
	return unless( defined $user );
	
	my $userid = $user->get_value( "userid" );

	my( $page );

	$page = $session->make_doc_fragment();

	my( $userdesc, $title );
	if( $staff )
	{
		( $userdesc, $title ) = $user->render_full();	
	}
	else
	{
		( $userdesc, $title ) = $user->render();	
	}
	$page->appendChild( $userdesc );

	$page->appendChild( $session->render_ruler() );

	my $arc_ds = $session->get_repository->get_dataset( "archive" );
	my $searchexp = new EPrints::Search(
		session => $session,
		dataset => $arc_ds );

	$searchexp->add_field(
		$arc_ds->get_field( "userid" ),
		$userid );

	$searchexp->perform_search();
	my $count = $searchexp->count();
	$searchexp->dispose();

	my $url;
	if( $staff )
	{
		$url = $session->get_repository->get_conf( "perl_url" )."/users/search/archive?userid=$userid&_action_search=1";
	}
	else
	{
		$url = $session->get_repository->get_conf( "perl_url" )."/user_eprints?userid=$userid";
	}
	my $link = $session->render_link( $url );	

	$page->appendChild( $session->html_phrase( 
				"lib/userpage:number_of_records",
				n=>$session->make_text( $count ),
				link=>$link ) );

	if( $staff && $session->current_user()->has_priv( "edit-user" ) )
	{
		$page->appendChild( $session->render_input_form(
			# no input fields so no need for a default
			buttons=>{
				_order => [ "edit", "delete" ],
				edit=>$session->phrase( "lib/userpage:action_edit" ),
				delete=>$session->phrase( "lib/userpage:action_delete" )
			},
			hidden_fields=>{
				userid=>$user->get_value( "userid" )
			},
			dest=>"edit_user"
		) );			
	}	
	

	$session->build_page(
		$session->html_phrase( "lib/userpage:title",
				name=>$user->render_description() ), 
		$page,
		"userpage" );
	$session->send_page();
}


1;

######################################################################
=pod

=back

=cut

