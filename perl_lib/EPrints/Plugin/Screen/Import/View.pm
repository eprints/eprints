package EPrints::Plugin::Screen::Import::View;

@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub get_dataset_id { "import" }

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_view.png";

	$self->{appears} = [
		{
			place => "import_item_actions",
			position => 200,
		},
	];

	$self->{actions} = [qw/ /];

	return $self;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $dataobj = $self->{processor}->{dataobj};

	my $page = $session->make_doc_fragment;

	my $ul = $session->make_element( "ul" );
	$page->appendChild( $ul );

	$dataobj->map(sub {
		my( undef, undef, $item ) = @_;

		my $li = $session->make_element( "li" );
		$ul->appendChild( $li );

		$li->appendChild( $item->render_citation_link() );
	});

	return $page;
}

1;
