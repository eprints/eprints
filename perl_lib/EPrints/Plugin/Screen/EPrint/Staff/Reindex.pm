package EPrints::Plugin::Screen::EPrint::Staff::Reindex;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	#	$self->{priv} = # no specific priv - one per action

	$self->{actions} = [qw/ reindex /];

	$self->{appears} = [ {
		place => "eprint_actions",
		action => "reindex",
		position => 1850,
	}, ];

	return $self;
}

sub obtain_lock
{
	my( $self ) = @_;

	return $self->obtain_eprint_lock;
}

sub about_to_render 
{
	my( $self ) = @_;

	$self->EPrints::Plugin::Screen::EPrint::View::about_to_render;
}

sub allow_reindex
{
	my( $self ) = @_;

	return 0 unless $self->could_obtain_eprint_lock;
	return $self->allow( "eprint/staff/edit" );
}
sub action_reindex
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $eprint = $self->{processor}->{eprint};

	$eprint->queue_all();

	# Remove all document index files to force re-texting them
	foreach my $doc ($eprint->get_all_documents())
	{
		$doc->remove_indexcodes();
	}

	# Redo the fulltext-index
	$eprint->queue_fulltext();

	$self->add_result_message( 1 );
}

sub add_result_message
{
	my( $self, $ok ) = @_;

	if( $ok )
	{
		$self->{processor}->add_message( "message",
			$self->html_phrase( "reindexing" ) );
	}
	else
	{
		# Error?
		$self->{processor}->add_message( "error" );
	}

	$self->{processor}->{screenid} = "EPrint::View";
}

1;
