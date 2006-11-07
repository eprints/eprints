
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
	

sub render
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	my $user = $self->{session}->current_user;

	$chunk->appendChild( $self->render_action_list( "item_tools" ) );

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
		my $imagesurl = $self->{session}->get_repository->get_conf( "base_url" )."/style/images";
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
	$chunk->appendChild( $filter_div );

	# Paginate list
	my %opts = (
		params => {
			screen => "Items",
			show_inbox=>$filters{inbox},
			show_buffer=>$filters{buffer},
			show_archive=>$filters{archive},
			show_deletion=>$filters{deletion},
		},
		pins => {
			searchdesc => $self->html_phrase( "list_desc" ),
		},
		columns => $self->{session}->current_user->get_value( "items_fields" ),
		render_result => sub {
			my( $session, $e ) = @_;

			my $tr = $session->make_element( "tr" );

			my $style = "";
			my $status = $e->get_value( "eprint_status" );

			if( $status eq "inbox" ) { $style="background-color: #ffc;"; }
			if( $status eq "buffer" ) { $style="background-color: #ddf;"; }
			if( $status eq "archive" ) { $style="background-color: #cfc;"; }
			if( $status eq "deletion" ) { $style="background-color: #ccc;"; }
			$style.=" border-bottom: 1px solid #888; padding: 4px;";

			my $cols = $session->current_user->get_value( "items_fields" );
			for( @$cols )
			{
				my $td = $session->make_element( "td", style=> $style . "border-right: 1px dashed #ccc;" );
				$tr->appendChild( $td );
				my $a = $session->render_link( "?eprintid=".$e->get_id."&screen=EPrint::View::Owner" );
				$td->appendChild( $a );
				$a->appendChild( $e->render_value( $_ ) );
			}

			return $tr;
		},
	);
	$chunk->appendChild( EPrints::Paginate->paginate_list_with_columns( $self->{session}, "_buffer", $list, %opts ) );

	# TODO: alt phrase for empty list e.g. "cgi/users/home:no_pending"

	return $chunk;
}


1;
