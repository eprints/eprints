package EPrints::Plugin::Screen::Search;

@ISA = ( 'EPrints::Plugin::Screen::AbstractSearch' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "admin_actions_editorial",
			position => 600,
		},
	];

	return $self;
}

sub search_dataset
{
	my( $self ) = @_;

	return $self->{processor}->{dataset};
}

sub search_filters
{
	my( $self ) = @_;

	return;
}

sub allow_export { &can_be_viewed }
sub allow_export_redir { &can_be_viewed }
sub can_be_viewed
{
	my( $self ) = @_;

	return
		defined $self->{processor}->{dataset} &&
		$self->allow( $self->{processor}->{dataset}->id . "/search" );
}

sub properties_from
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $self->{session};

	my $datasetid = $session->param( "dataset" );

	my $dataset = $processor->{dataset};
	$dataset = $session->dataset( $datasetid ) if !defined $dataset;
	if( !defined $dataset )
	{
		$processor->{screenid} = "Error";
		$processor->add_message( "error", $self->html_phrase(
					"no_such_dataset",
					datasetid=>$session->make_text( $datasetid ),
					) );
		return;
	}

	$processor->{dataset} = $dataset;
	$processor->{sconf} = $session->config( "datasets", $dataset->id, "search", "advanced" );

	$self->SUPER::properties_from;
}

sub get_controls_before
{
	my( $self ) = @_;

	return $self->get_basic_controls_before;	
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $frag = $session->make_doc_fragment;

	$frag->appendChild( $self->SUPER::render_hidden_bits );
	$frag->appendChild( $session->xhtml->hidden_field( dataset => $self->{processor}->{dataset}->id ) );

	return $frag;
}

1;
