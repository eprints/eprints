######################################################################
#
#  View User Record
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

package EPrints::UserPage;

use EPrints::Session;
use EPrints::SearchExpression;
use EPrints::Utils;
use EPrints::User;

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
	if( EPrints::Utils::is_set( $username ) )
	{
		$user = EPrints::User::user_with_username( $session, $username );
	}
	else
	{
		$user = EPrints::User->new( $session, $userid );
	}


	if( !defined $user )
	{
		$session->render_error( $session->html_phrase( 
				"lib/userpage:unknown_user" ) );
		return;
	}

	return $user;
}

sub process
{
	my( $session, $staff ) = @_;

	my $user = EPrints::UserPage::user_from_param( $session );
	return unless( defined $user );
	
	$userid = $user->get_value( "userid" );

	my( $page );

	$page = $session->make_doc_fragment();

	if( $staff )
	{	
		$page->appendChild( $user->render_full() );
	}
	else
	{
		$page->appendChild( $user->render() );
	}

	$page->appendChild( $session->render_ruler() );

	my $arc_ds = $session->get_archive()->get_dataset( "archive" );
	my $searchexp = new EPrints::SearchExpression(
		session => $session,
		dataset => $arc_ds );

	$searchexp->add_field(
		$arc_ds->get_field( "userid" ),
		"PHR:EQ:$userid" );

	$searchexp->perform_search();
	my $count = $searchexp->count();
	$searchexp->dispose();

	my $url;
	if( $staff )
	{
		$url = $session->get_archive()->get_conf( "perl_url" )."/users/staff/eprint_search?userid=$userid&_action_search=1";
	}
	else
	{
		$url = $session->get_archive()->get_conf( "perl_url" )."/user_eprints?userid=$userid";
	}
	my $link = $session->make_element( "a", href=>$url );	

	$page->appendChild( $session->html_phrase( 
				"lib/userpage:number_of_records",
				n=>$session->make_text( $count ),
				link=>$link ) );

	if( $staff && $session->current_user()->has_priv( "edit-user" ) )
	{
		$page->appendChild( $session->render_input_form(
			buttons=>{
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
		$session->phrase( "lib/userpage:title",
				name=>$user->full_name() ), 
		$page );
	$session->send_page();
}


1;
