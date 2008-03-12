
package EPrints::Plugin::Screen::Items;

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
			position => 100,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "items" );
}

sub get_filters
{
	my( $self ) = @_;

	my %f = ( inbox=>1, buffer=>1, archive=>0, deletion=>0 );

	foreach my $filter ( keys %f )
	{
		my $v = $self->{session}->param( "show_$filter" );
		$f{$filter} = $v if defined $v;
	}	

	return %f;
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

	my $chunk = $self->{session}->make_doc_fragment;

	my $user = $self->{session}->current_user;

	if( $self->{session}->get_lang->has_phrase( $self->html_phrase_id( "intro" ) ) )
	{
		my $intro_div_outer = $self->{session}->make_element( "div", class => "ep_toolbox" );
		my $intro_div = $self->{session}->make_element( "div", class => "ep_toolbox_content" );
		$intro_div->appendChild( $self->html_phrase( "intro" ) );
		$intro_div_outer->appendChild( $intro_div );
		$chunk->appendChild( $intro_div_outer );
	}

	$chunk->appendChild( $self->render_action_list_bar( "item_tools" ) );

	my %filters = $self->get_filters;
	my @l = ();
	foreach( keys %filters ) { push @l, $_ if $filters{$_}; }

	### Get the items owned by the current user
	my $ds = $self->{session}->get_repository->get_dataset( "eprint" );
	my $list = $self->{session}->current_user->get_owned_eprints( $ds );
	$list = $list->reorder( "-status_changed" );

	my $searchexp = new EPrints::Search(
		session=>$self->{session},
		dataset=>$ds );
	$searchexp->add_field(
		$ds->get_field( "eprint_status" ),
		join( " ", @l ),
		"EQ",
		"ANY" );
	$list = $list->intersect( $searchexp->perform_search, "-eprintid" );
	my $filter_div = $self->{session}->make_element( "div", class=>"ep_items_filters" );
	foreach my $f ( qw/ inbox buffer archive deletion / )
	{
		my %f2 = %filters;
		$f2{$f} = 1-$f2{$f};
		my $url = "?screen=Items";
		foreach my $inner_f ( qw/ inbox buffer archive deletion / )
		{
			$url.= "&show_$inner_f=".$f2{$inner_f};
		}
		my $a = $self->{session}->render_link( $url,  );
		my $imagesurl = $self->{session}->get_repository->get_conf( "rel_path" )."/style/images";
		if( $filters{$f} )
		{
			$a->appendChild( $self->{session}->make_element(
				"img",
				src=> "$imagesurl/checkbox_tick.png",
				alt=>"Showing" ) );
		}
		else
		{
			$a->appendChild( $self->{session}->make_element(
				"img",
				src=> "$imagesurl/checkbox_empty.png",
				alt=>"Not showing" ) );
		}
		$a->appendChild( $self->{session}->make_text( " " ) );
		$a->appendChild( $self->{session}->html_phrase( "eprint_fieldopt_eprint_status_$f" ) );
		$filter_div->appendChild( $a );
		$filter_div->appendChild( $self->{session}->make_text( ". " ) );
	}

	my $columns = $self->{session}->current_user->get_value( "items_fields" );
	if( !EPrints::Utils::is_set( $columns ) )
	{
		$columns = [ "eprintid","type","eprint_status","lastmod" ];
	}

	# Paginate list
	my %opts = (
		params => {
			screen => "Items",
			show_inbox=>$filters{inbox},
			show_buffer=>$filters{buffer},
			show_archive=>$filters{archive},
			show_deletion=>$filters{deletion},
		},
		columns => $columns,
		above_results => $filter_div,
		render_result => sub {
			my( $session, $e ) = @_;

			my $tr = $session->make_element( "tr" );

			my $status = $e->get_value( "eprint_status" );

			my $first = 1;
			for( @$columns )
			{
				my $td = $session->make_element( "td", class=>"ep_columns_cell_$status".($first?" ep_columns_cell_first":"")." ep_columns_cell_$_"  );
				$first = 0;
				$tr->appendChild( $td );
				$td->appendChild( $e->render_value( $_ ) );
			}

			$self->{processor}->{eprint} = $e;
			$self->{processor}->{eprintid} = $e->get_id;
			my $td = $session->make_element( "td", class=>"ep_columns_cell", align=>"left" );
			$tr->appendChild( $td );
			$td->appendChild( 
				$self->render_action_list_icons( "eprint_item_actions", ['eprintid'] ) );
			delete $self->{processor}->{eprint};

			return $tr;
		},
	);
#	my $h2 = $self->{session}->make_element( "h2",class=>"ep_search_desc" );
##	$h2->appendChild( $self->html_phrase( "list_desc" ) );
#	$chunk->appendChild( $h2 );
	$chunk->appendChild( EPrints::Paginate::Columns->paginate_list( $self->{session}, "_buffer", $list, %opts ) );

	# TODO: alt phrase for empty list e.g. "cgi/users/home:no_pending"

	return $chunk;
}


1;
