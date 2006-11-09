
package EPrints::Plugin::Screen::User::SavedSearch;

use EPrints::Plugin::Screen::User;

@ISA = ( 'EPrints::Plugin::Screen::User' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	# sets userid and user to the current user, if any
	$self->SUPER::properties_from;

	my $searchid = $self->{session}->param( "savedsearchid" );
	$self->{processor}->{savedsearchid} = $searchid;
	$self->{processor}->{savedsearch} = new EPrints::DataObj::SavedSearch( 
					$self->{session}, $searchid );

	if( !defined $self->{processor}->{savedsearch} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", 
			$self->html_phrase(
				"no_such_saved_search",
				id => $self->{session}->make_text( 
						$self->{processor}->{savedsearchid} ) ) );
		return;
	}

}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "saved_search/view" );
}

sub allow
{
	my( $self, $priv ) = @_;

	return 0 unless defined $self->{processor}->{savedsearch};

	return 1 if( $self->{session}->allow_anybody( $priv ) );
	return 0 if( !defined $self->{session}->current_user );
	return $self->{session}->current_user->allow( $priv, $self->{processor}->{savedsearch} );
}

sub workflow
{
	my( $self, $staff ) = @_;

	my $cache_id = "savedsearch_workflow";

	if( !defined $self->{processor}->{$cache_id} )
	{
		my %opts = ( 
			item => $self->{processor}->{savedsearch},
			search_description=>[$self->{processor}->{savedsearch}->render_value( "spec" ),"XHTML"],
			session => $self->{session} );
		if( $staff ) { $opts{STAFF_ONLY} = ["TRUE","BOOLEAN"]; }
 		$self->{processor}->{$cache_id} = EPrints::Workflow->new( 
			$self->{session}, 
			"default", 
			%opts );
	}

	return $self->{processor}->{$cache_id};
}



sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->{session}->render_hidden_field( "savedsearchid", $self->{processor}->{savedsearchid} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}

sub register_furniture
{
	my( $self ) = @_;

	$self->SUPER::register_furniture;

	my $h3 = $self->{session}->make_element( "h3", style=>"margin: 0px" );
	$h3->appendChild( $self->{processor}->{savedsearch}->render_description );

	$self->{processor}->before_messages( $h3 );
}


1;

