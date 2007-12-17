
package EPrints::Plugin::Screen::Review;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "key_tools",
			position => 400,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "editorial_review" );
}

sub render_links
{
	my( $self ) = @_;

	my $style = $self->{session}->make_element( "style", type=>"text/css" );
	$style->appendChild( $self->{session}->make_text( ".ep_tm_main { width: 90%; }" ) );

	return $style;
}


sub render
{
	my( $self ) = @_;

	my $user = $self->{session}->current_user;
	my $page = $self->{session}->make_doc_fragment();

	# Get EPrints in the submission buffer
	my $list = $user->get_editable_eprints();

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );
	$page->appendChild( $div );

	if( $user->is_set( "editperms" ) )
	{
		$div->appendChild( $self->{session}->html_phrase( 
			"cgi/users/buffer:buffer_scope",
			scope=>$user->render_value( "editperms" ) ) );
	}

	if( $list->count > 0 )
	{
		$div->appendChild( $self->{session}->html_phrase( 
			"cgi/users/buffer:buffer_blurb" ));
	}
	
	my $columns = $self->{session}->current_user->get_value( "review_fields" );
	if( !EPrints::Utils::is_set( $columns ) )
	{
		$columns = [ "eprintid","type","status_changed", "userid" ];
	}

	# Paginate list
	my %opts = (
		params => {
			screen => "Review",
		},
		columns => $columns,
		render_result_params => {
			row => 1,
		},
		render_result => sub {
			my( $session, $e, $info ) = @_;

			my $tr = $session->make_element( "tr", class=>"row_".($info->{row}%2?"b":"a") );

 			my $cols = $columns,

			my $first = 1;
			for( @$cols )
			{
				my $td = $session->make_element( "td", class=>"ep_columns_cell".($first?" ep_columns_cell_first":"")." ep_columns_cell_$_"  );
				$first = 0;
				$tr->appendChild( $td );
				$td->appendChild( $e->render_value( $_ ) );
			}

			$self->{processor}->{eprint} = $e;
			$self->{processor}->{eprintid} = $e->get_id;
			my $td = $session->make_element( "td", class=>"ep_columns_cell", align=>"left" );
			$tr->appendChild( $td );
			$td->appendChild( 
				$self->render_action_list_icons( "eprint_review_actions", ['eprintid'] ) );
			delete $self->{processor}->{eprint};


			++$info->{row};

			return $tr;
		},
	);
#	my $h2 = $self->{session}->make_element( "h2",class=>"ep_search_desc" );
#	$h2->appendChild( $self->html_phrase( "list_desc" ) );
#	$page->appendChild( $h2 );
	$page->appendChild( EPrints::Paginate::Columns->paginate_list( $self->{session}, "_review", $list, %opts ) );

	return $page;
}


# ignore the form. We're screwed at this point, and are just reporting.
sub from
{
	my( $self ) = @_;

	return;
}




1;
