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

sub process
{
	my( $session, $staff ) = @_;

	
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

	$userid = $user->get_value( "userid" );

	my $dataset = $user->get_dataset();

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

	my $searchexp = new EPrints::SearchExpression(
		session => $session,
		dataset => $dataset );

	$searchexp->add_field(
		$dataset->get_field( "userid" ),
		"PHR:EQ:$userid" );

	$searchexp->perform_search();
	my $count = $searchexp->count();
	$searchexp->dispose();

	
	#print "<P><A HREF=\"user_eprints?username=$userid\">";
	#<                       "HREF=\"eprint_search?username=$userid\&submit=Search\">".
	my $url;
	if( $staff )
	{
		$url = $session->get_archive()->get_conf( "server_perl_root" )."/users/staff/eprint_search?userid=$userid&_action_search=1";
	}
	else
	{
		$url = $session->get_archive()->get_conf( "server_perl_root" )."/user_eprints?userid=$userid";
	}
	my $link = $session->make_element( "a", href=>$url );	

	$page->appendChild( $session->html_phrase( 
				"lib/userpage:number_of_records",
				n=>$session->make_text( $count ),
				link=>$link ) );




#		print $session->{render}->start_form( "edit_user" );
#		print "<CENTER><P>";
#		print $session->{render}->hidden_field( "username", $userid );
#		print $session->{render}->submit_buttons( [ "Edit User",
#		                                            "Delete User" ] );
#		print "</P></CENTER>\n";


	$session->build_page(
		$session->phrase( "lib/userpage:title",
				name=>$user->full_name() ), 
		$page );
	$session->send_page();
}


1;
