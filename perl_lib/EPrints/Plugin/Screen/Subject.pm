
package EPrints::Plugin::Screen::Subject;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{subjectid} = $self->{session}->param( "subjectid" );
	if( !defined $self->{processor}->{subjectid} )
	{
		$self->{processor}->{subjectid} = "ROOT";
	}
	$self->{processor}->{subject} = new EPrints::DataObj::Subject( $self->{session}, $self->{processor}->{subjectid} );

	if( !defined $self->{processor}->{subject} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", 
			$self->html_phrase( "no_such_subject",
			id=>$self->{session}->make_text( $self->{processor}->{subjectid} ) ));
		return;
	}

	$self->{processor}->{dataset} = $self->{processor}->{subject}->get_dataset;

	$self->SUPER::properties_from;
}

sub allow
{
	my( $self, $priv ) = @_;

	my $subject = $self->get_subject;

	return 1 if( $self->{session}->allow_anybody( $priv ) );
	
	return $self->{session}->current_user->allow( $priv, $subject );
}

sub render_tab_title
{
	my( $self ) = @_;

	return $self->html_phrase( "title" );
}


sub get_subject
{
	my( $self ) = @_;

	my $subject = $self->{processor}->{subject};
	if( !defined $self->{processor}->{subjectid} )
	{
		$subject = new EPrints::DataObj::Subject( $self->{session}, "ROOT" );
	}
	return $subject;
}

sub render_title
{
	my( $self ) = @_;

	my $subject = $self->get_subject;

	my $f = $self->{session}->make_doc_fragment;
	$f->appendChild( $self->html_phrase( "title" ) );
	$f->appendChild( $self->{session}->make_text( ": " ) );

	my $title = $subject->render_citation( "screen" );
	$f->appendChild( $title );

	return $f;
}



sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->{session}->render_hidden_field( "subjectid", $self->{processor}->{subjectid} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url."&subjectid=".$self->{processor}->{subjectid};
}

1;

