
package EPrints::Plugin::Screen::User::View;

use EPrints::Plugin::Screen::User;

@ISA = ( 'EPrints::Plugin::Screen::User' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "key_tools",
			position => 200,
		},
	];

	return $self;
}



sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $page = $session->make_doc_fragment();

	my ($data,$title) = $self->{processor}->{user}->render; 

	$page->appendChild( $data );

	my $table = $session->make_element( "table" );
	foreach my $item ( $self->action_list )
	{
		my $tr = $session->make_element( "tr" );
		$table->appendChild( $tr );

		my $td = $session->make_element( "td" );
		$tr->appendChild( $td );

		my $form = $session->render_form( "form" );
		$td->appendChild( $form );
		$form->appendChild( $session->render_hidden_field( "userid", $self->{processor}->{userid} ) );

		$form->appendChild( $session->render_hidden_field( "screen", substr( $item->{screen_id}, 8 ) ) );
		my( $action, $title, $description );
		if( defined $item->{action} )
		{
			$action = $item->{action};
			$title = $item->{screen}->phrase( "action:$action:title" );
			$description = $item->{screen}->html_phrase( "action:$action:description" );
		}
		else
		{
			$action = "null";
			$title = $item->{screen}->phrase( "title" );
			$description = $item->{screen}->html_phrase( "description" );
		}
		$form->appendChild( 
			$session->make_element( 
				"input", 
				type=>"submit",
				class=>"ep_form_action_button",
				name=>"_action_$action", 
				value=>$title ));

		my $td2 = $session->make_element( "td" );
		$tr->appendChild( $td2 );

		$td2->appendChild( $description );
	}
	
	$page->appendChild( $table );

	return $page;
}


sub action_list
{
	my( $self ) = @_;

	my @list = ();
	foreach my $item ( $self->list_items( "user_actions" ) )
	{
		my $who_allowed;
		if( defined $item->{action} )
		{
 			$who_allowed = $item->{screen}->allow_action( $item->{action} );
		}
		else
		{
			$who_allowed = $item->{screen}->can_be_viewed;
		}

		#next unless( $who_allowed & $self->who_filter );
		next unless( $who_allowed );

		push @list, $item;
	}

	return @list;
}



sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "user/view" );
}


1;

