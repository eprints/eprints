=head1 NAME

EPrints::Plugin::Screen::User

=cut


package EPrints::Plugin::Screen::User;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	# sets userid and user to the current user, if any
	$self->SUPER::properties_from;

	my $userid = $self->{session}->param( "userid" );
	if( defined $userid )
	{
		$self->{processor}->{userid} = $userid;
		$self->{processor}->{user} = new EPrints::DataObj::User( 
						$self->{session}, 
						$userid );
	}

	if( !defined $self->{processor}->{user} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", 
			$self->html_phrase(
				"no_such_user",
				id => $self->{session}->make_text( 
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

	return 1 if( $self->{session}->allow_anybody( $priv ) );

	return 0 if( !defined $self->{session}->current_user );

	return $self->{session}->current_user->allow( $priv, $self->{processor}->{user} );
}

sub register_furniture
{
	my( $self ) = @_;

	$self->SUPER::register_furniture;

	my $f = $self->{session}->make_doc_fragment;

	my $cuser = $self->{session}->current_user;

	if( $cuser->get_id eq $self->{processor}->{userid} )
	{
		return $f;
	}

	my $h2 = $self->{session}->make_element( "h2", style=>"margin: 0px" );
	my $title = $self->{processor}->{user}->render_citation( "screen" );
	my $a = $self->{session}->render_link( "?screen=User::View&userid=".$self->{processor}->{userid} );
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
			session => $self->{session} );
		$opts{STAFF_ONLY} = [$staff ? "TRUE" : "FALSE","BOOLEAN"];
 		$self->{processor}->{$cache_id} = EPrints::Workflow->new( 
			$self->{session}, 
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

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->{session}->render_hidden_field( "userid", $self->{processor}->{userid} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}

1;


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

