package EPrints::Plugin::InputForm::Component::PlaceHolder;

use EPrints::Plugin::InputForm::Component;

@ISA = ( "EPrints::Plugin::InputForm::Component" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "PlaceHolder";
	$self->{visible} = "all";

	return $self;
}

sub render_content
{
	my( $self ) = @_;

	return $self->html_phrase( "content", placeholding => $self->{session}->make_text( $self->{placeholding} ) );
}

sub render_help
{
	my( $self, $surround ) = @_;
	
	return $self->html_phrase( "help", placeholding => $self->{session}->make_text( $self->{placeholding} ) );
}

sub render_title
{
	my( $self, $surround ) = @_;

	return $self->html_phrase( "title", placeholding => $self->{session}->make_text( $self->{placeholding} ) );
}
	
1;





