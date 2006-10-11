package EPrints::Plugin::Screen::EPrint::EditLink;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 400,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/edit" );
}

# total ugly code. This is just here to be replaced
# easily in the sub class.
sub things
{
	my( $self ) = @_;

	return( "EPrint::Edit", $self->workflow );
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{processor}->{session};
	my $eprint = $self->{processor}->{eprint};
	my( $escreen, $workflow ) = $self->things;
	my $ul = $session->make_element( "ul" );
	foreach my $stage_id ( $workflow->get_stage_ids )
	{
		my $li = $session->make_element( "li" );
		my $a = $session->render_link( "?eprintid=".$self->{processor}->{eprintid}."&screen=$escreen&stage=$stage_id" );
		$li->appendChild( $a );
		$a->appendChild( $session->html_phrase( "metapage_title_".$stage_id ) );
		$ul->appendChild( $li );
	}

	return $ul;
}	


1;
