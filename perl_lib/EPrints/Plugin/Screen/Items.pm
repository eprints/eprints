
package EPrints::Plugin::Screen::Items;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ create /];

	$self->{appears} = [
		{
			place => "key_tools",
			position => 100,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "items" );
}

sub allow_create
{
	my ( $self ) = @_;

	return $self->allow( "create_eprint" );
}

sub action_create
{
	my( $self ) = @_;

	my $ds = $self->{processor}->{session}->get_repository->get_dataset( "inbox" );

	my $user = $self->{session}->current_user;

	$self->{processor}->{eprint} = $ds->create_object( $self->{session}, { 
		userid => $user->get_value( "userid" ) } );

	if( !defined $self->{processor}->{eprint} )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{processor}->{session}->get_repository->log( "Database Error: $db_error" );
		$self->{processor}->add_message( 
			"error",
			$self->html_phrase( "db_error" ) );
		return;
	}

	$self->{processor}->{eprintid} = $self->{processor}->{eprint}->get_id;
	$self->{processor}->{screenid} = "EPrint::Edit";

}





sub render
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	my $user = $self->{session}->current_user;

	my $sb = $self->{session}->get_repository->get_conf( "skip_buffer" );	

	my $dt;
	my $dd;

	my $dl =  $self->{session}->make_element( "dl" );

	$dt = $self->{session}->make_element( "dt" );
	$dd = $self->{session}->make_element( "dd" );
	$a = $self->{session}->render_link( "?screen=Items&_action_create=1" );
	$a->appendChild( $self->{session}->html_phrase( "cgi/users/home:new_item_link" ) );
	$dt->appendChild( $a );
	$dd->appendChild( $self->{session}->html_phrase( "cgi/users/home:new_item_info" ) );
	$dl->appendChild( $dt );
	$dl->appendChild( $dd );

	$dt = $self->{session}->make_element( "dt" );
	$dd = $self->{session}->make_element( "dd" );
	$a = $self->{session}->render_link( "?screen=Items::Import" );
	$a->appendChild( $self->{session}->html_phrase( "cgi/users/home:import_item_link" ) );
	$dt->appendChild( $a );
	$dd->appendChild( $self->{session}->html_phrase( "cgi/users/home:import_item_info" ) );
	$dl->appendChild( $dt );
	$dl->appendChild( $dd );


	$chunk->appendChild( $dl );	

	### Get the items in the buffer
	my $ds = $self->{session}->get_repository->get_dataset( "eprint" );
	my $list = $self->{session}->current_user->get_owned_eprints( $ds );
	$list = $list->reorder( "-status_changed" );

	my $table = $self->{session}->make_element( "table", cellspacing=>0, width => "100%" );
	my $tr = $self->{session}->make_element( "tr", class=>"header_plain" );
	$table->appendChild( $tr );

	my $th = $self->{session}->make_element( "th" );
	$th->appendChild( $ds->get_field( "eprint_status" )->render_name( $self->{session} ) );
	$tr->appendChild( $th );

	$th = $self->{session}->make_element( "th" );
	$th->appendChild( $ds->get_field( "lastmod" )->render_name( $self->{session} ) );
	$tr->appendChild( $th );

	$th = $self->{session}->make_element( "th" );
	$th->appendChild( $ds->get_field( "title" )->render_name( $self->{session} ) );
	$tr->appendChild( $th );

	my %opts = (
		params => {
			screen => "Items",
		},
		container => $table,
		pins => {
			searchdesc => $self->{session}->make_doc_fragment,
		},
		render_result => sub {
			my( $session, $e ) = @_;

			my $tr = $session->make_element( "tr" );

			my $style = "";
			my $status = $e->get_value( "eprint_status" );

			if( $status eq "inbox" )
			{
				$style="background-color: #ffc;";
			}
			if( $status eq "buffer" )
			{
				$style="background-color: #ddf;";
			}
			if( $status eq "archive" )
			{
				$style="background-color: #cfc;";
			}
			if( $status eq "deletion" )
			{
				$style="background-color: #ccc;";
			}
			$style.=" border-bottom: 1px solid #888; padding: 4px;";

			my $td;

			$td = $session->make_element( "td", style=>$style." text-align: center;" );
			$tr->appendChild( $td );
			$td->appendChild( $e->render_value( "eprint_status" ) );

			$td = $session->make_element( "td", style=>$style );
			$tr->appendChild( $td );
			$td->appendChild( $e->render_value( "lastmod" ) );

			$td = $session->make_element( "td", style=>$style );
			$tr->appendChild( $td );
			my $a = $session->render_link( "?eprintid=".$e->get_id."&screen=EPrint::View::Owner" );
			$a->appendChild( $e->render_description() );
			$td->appendChild( $a );
			
			return $tr;
		},
	); 
	$chunk->appendChild( EPrints::Paginate->paginate_list( $self->{session}, "_buffer", $list, %opts ) );

	# TODO: alt phrase for empty list e.g. "cgi/users/home:no_pending"

	return $chunk;
}


1;
