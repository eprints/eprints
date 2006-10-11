package EPrints::Plugin::Screen::EPrint::Actions;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 300,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless scalar $self->action_list;

	return $self->who_filter;
}

sub who_filter { return 4; }

sub action_list
{
	my( $self ) = @_;

	my @list = ();
	foreach my $item ( $self->list_items( "eprint_actions" ) )
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

		next unless( $who_allowed & $self->who_filter );

		push @list, $item;
	}

	return @list;
}


sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $table = $session->make_element( "table" );
	foreach my $item ( $self->action_list )
	{
		my $tr = $session->make_element( "tr" );
		$table->appendChild( $tr );

		my $td = $session->make_element( "td" );
		$tr->appendChild( $td );

		my $form = $session->render_form( "form" );
		$td->appendChild( $form );
		$form->appendChild( $session->render_hidden_field( "eprintid", $self->{processor}->{eprintid} ) );

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
	
	return $table;
}

1;
