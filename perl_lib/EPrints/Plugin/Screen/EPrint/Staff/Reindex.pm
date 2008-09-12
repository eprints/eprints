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

sub about_to_render 
{
	my( $self ) = @_;

	$self->EPrints::Plugin::Screen::EPrint::View::about_to_render;
}

sub allow_reindex
{
	my( $self ) = @_;

	return $self->allow( "eprint/staff/edit" );
}
sub action_reindex
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $eprint = $self->{processor}->{eprint};
	my $dataset = $eprint->{dataset};

	my $database = $session->get_database;

	foreach my $field ( $dataset->get_fields )
	{
		next unless $field->get_property( "text_index" );
		$database->index_queue(
			'eprint',
			$eprint->get_id,
			$field->get_name );
	}

	# Remove all document index files to force re-texting them
	foreach my $doc ($eprint->get_all_documents())
	{
		my $docs = $doc->get_related_objects(
				EPrints::Utils::make_relation( "hasIndexCodesVersion" )
			);
		$_->remove() for @$docs;
		$doc->commit() if scalar @$docs; # commit the change in relation
	}

	# Redo the fulltext-index
	$database->index_queue(
		'eprint',
		$eprint->get_id,
		$EPrints::Utils::FULLTEXT
	);

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
