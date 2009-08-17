
package EPrints::Plugin::Screen::User::SavedSearch;

use EPrints::Plugin::Screen::User;

@ISA = ( 'EPrints::Plugin::Screen::User' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	# sets userid and user to the current user, if any
	$self->SUPER::properties_from;

	my $searchid = $self->{handle}->param( "savedsearchid" );
	$self->{processor}->{savedsearchid} = $searchid;
	$self->{processor}->{savedsearch} = new EPrints::DataObj::SavedSearch( 
					$self->{handle}, $searchid );

	if( !defined $self->{processor}->{savedsearch} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", 
			$self->html_phrase(
				"no_such_saved_search",
				id => $self->{handle}->make_text( 
						$self->{processor}->{savedsearchid} ) ) );
		return;
	}

}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url."&savedsearchid=".$self->{processor}->{savedsearchid};
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

	return 1 if( $self->{handle}->allow_anybody( $priv ) );
	return 0 if( !defined $self->{handle}->current_user );
	return $self->{handle}->current_user->allow( $priv, $self->{processor}->{savedsearch} );
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
			handle => $self->{handle} );
		$opts{STAFF_ONLY} = [$staff ? "TRUE" : "FALSE","BOOLEAN"];
 		$self->{processor}->{$cache_id} = EPrints::Workflow->new( 
			$self->{handle}, 
			"default", 
			%opts );
	}

	return $self->{processor}->{$cache_id};
}



sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{handle}->make_doc_fragment;

	$chunk->appendChild( $self->{handle}->render_hidden_field( "savedsearchid", $self->{processor}->{savedsearchid} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}


sub render_title
{
	my( $self ) = @_;

	my $f = $self->{handle}->make_doc_fragment;
	$f->appendChild( $self->html_phrase( "title" ) );
	$f->appendChild( $self->{handle}->make_text( ": " ));
	$f->appendChild( $self->{processor}->{savedsearch}->render_description );
	return $f;
}


1;

