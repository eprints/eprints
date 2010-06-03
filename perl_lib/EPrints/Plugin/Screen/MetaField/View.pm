package EPrints::Plugin::Screen::MetaField::View;

use EPrints::Plugin::Screen::Workflow::View;
@ISA = qw( EPrints::Plugin::Screen::Workflow::View );

sub edit_screen { "MetaField::Edit" }
sub view_screen { "MetaField::View" }
sub listing_screen { "MetaField::Listing" }
sub can_be_viewed { shift->allow( "config/edit/perl" ) }

sub render_title
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $screen = $self->view_screen();

	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};

	my $url = URI->new( $session->current_url );
	$url->query_form(
		screen => $self->listing_screen,
		dataset => $dataobj->value( "mfdatasetid" ),
	);
	my $listing = $session->render_link( $url );
	$listing->appendChild( $dataset->render_name( $session ) );

	my $desc = $dataobj->render_description();
	if( $self->{id} ne "Screen::$screen" )
	{
		$url->query_form(
			screen => $screen,
			dataset => $dataset->id,
			dataobj => $dataobj->id
		);
		my $link = $session->render_link( $url );
		$link->appendChild( $desc );
	}

	return $self->html_phrase( "page_title",
		listing => $listing,
		desc => $desc,
	);
}

1;
