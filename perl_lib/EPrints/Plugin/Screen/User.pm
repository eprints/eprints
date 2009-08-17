
package EPrints::Plugin::Screen::User;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	# sets userid and user to the current user, if any
	$self->SUPER::properties_from;

	my $userid = $self->{handle}->param( "userid" );
	if( defined $userid )
	{
		$self->{processor}->{userid} = $userid;
		$self->{processor}->{user} = new EPrints::DataObj::User( 
						$self->{handle}, 
						$userid );
	}

	if( !defined $self->{processor}->{user} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", 
			$self->html_phrase(
				"no_such_user",
				id => $self->{handle}->make_text( 
						$self->{processor}->{userid} ) ) );
		return;
	}

	$self->{processor}->{dataset} = 
		$self->{processor}->{user}->get_dataset;

}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url."&userid=".$self->{processor}->{userid};
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "user/view" );
}

sub allow
{
	my( $self, $priv ) = @_;

	return 0 unless defined $self->{processor}->{user};

	return 1 if( $self->{handle}->allow_anybody( $priv ) );

	return 0 if( !defined $self->{handle}->current_user );

	return $self->{handle}->current_user->allow( $priv, $self->{processor}->{user} );
}

sub register_furniture
{
	my( $self ) = @_;

	$self->SUPER::register_furniture;

	my $f = $self->{handle}->make_doc_fragment;

	my $cuser = $self->{handle}->current_user;

	if( $cuser->get_id eq $self->{processor}->{userid} )
	{
		return $f;
	}

	my $h2 = $self->{handle}->make_element( "h2", style=>"margin: 0px" );
	my $title = $self->{processor}->{user}->render_citation( "screen" );
	my $a = $self->{handle}->render_link( "?screen=User::View&userid=".$self->{processor}->{userid} );
	$f->appendChild( $h2 );
	$h2->appendChild( $a );
	$a->appendChild( $title );

	$self->{processor}->before_messages( $f );
}


sub workflow
{
	my( $self, $staff ) = @_;

	my $cache_id = "workflow";
	$cache_id.= "_staff" if( $staff ); 

	if( !defined $self->{processor}->{$cache_id} )
	{
		my %opts = ( 
			item => $self->{processor}->{user},
			handle => $self->{handle} );
		$opts{STAFF_ONLY} = [$staff ? "TRUE" : "FALSE","BOOLEAN"];
 		$self->{processor}->{$cache_id} = EPrints::Workflow->new( 
			$self->{handle}, 
			"default", 
			%opts );
	}

	return $self->{processor}->{$cache_id};
}

sub uncache_workflow
{
	my( $self ) = @_;

	delete $self->{processor}->{workflow};
	delete $self->{processor}->{workflow_staff};
}



sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{handle}->make_doc_fragment;

	$chunk->appendChild( $self->{handle}->render_hidden_field( "userid", $self->{processor}->{userid} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}

1;

