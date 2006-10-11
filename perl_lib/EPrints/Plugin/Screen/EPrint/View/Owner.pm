
package EPrints::Plugin::Screen::EPrint::View::Owner;

use EPrints::Plugin::Screen::EPrint::View;

@ISA = ( 'EPrints::Plugin::Screen::EPrint::View' );

use strict;



sub who_filter { return 4; }

sub render_status
{
	my( $self ) = @_;

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	my $status_fragment = $self->{session}->make_doc_fragment;
	$status_fragment->appendChild( $self->{session}->html_phrase( "cgi/users/edit_eprint:item_is_in_".$status ) );

	if( $self->allow( "action/eprint/deposit" ) )
	{
		# clean up
		my $deposit_div = $self->{session}->make_element( "div", id=>"controlpage_deposit_link" );
		my $a = $self->{session}->make_element( "a", href=>"?screen=EPrint::Deposit&eprintid=".$self->{processor}->{eprintid} );
		$a->appendChild( $self->html_phrase( "deposit" ) );
		$deposit_div->appendChild( $a );
		$status_fragment->appendChild( $deposit_div );
	}

	return $status_fragment;
#	return $self->{session}->render_toolbox( 
#			$self->{session}->make_text( "Status" ),
#			$status_fragment );
}



# don't do what view does 
sub about_to_render 
{
}

1;

