
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
	my $filter_div = $self->{session}->make_element( "div" );
	$filter_div->appendChild( $self->{session}->make_text( "Filters {lang}: " ) );
	foreach my $f ( qw/ inbox buffer archive deletion / )
	{
		my %f2 = %filters;
		$f2{$f} = 1-$f2{$f};
		my $url = "?screen=Items";
		foreach my $inner_f ( qw/ inbox buffer archive deletion / )
		{
			$url.= "&show_$inner_f=".$f2{$inner_f};
		}
		my $a = $self->{session}->render_link( $url );
		if( $filters{$f} )
		{
			$a->appendChild( $self->{session}->make_text( "Showing " ) );
		}
		else
		{
			$a->appendChild( $self->{session}->make_text( "Concealing " ) );
		}
		$a->appendChild( $self->{session}->html_phrase( "dataset_fieldopt_dataset_$f" ) );
		$filter_div->appendChild( $a );
		$filter_div->appendChild( $self->{session}->make_text( ". " ) );
	}
	$chunk->appendChild( $filter_div );		

	my $table = $self->{session}->make_element( "table", cellspacing=>0, width => "100%" );
	my $tr = $self->{session}->make_element( "tr", class=>"header_plain" );
	$table->appendChild( $tr );

	# Columns displayed according to user preference
	my $cols = $self->{session}->current_user->get_value( "items_fields" );
	for( @$cols )
	{
		my $th = $self->{session}->make_element( "th" );
		$th->appendChild( $ds->get_field( $_ )->render_name( $self->{session} ) );
		$tr->appendChild( $th );
	}

	my %opts = (
		params => {
			screen => "Items",
			show_inbox=>$filters{inbox},
			show_buffer=>$filters{buffer},
			show_archive=>$filters{archive},
			show_deletion=>$filters{deletion},
		},
		container => $table,
		pins => {
			searchdesc => $self->html_phrase( "list_desc" ),
		},
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

			my $cols = $self->{session}->current_user->get_value( "items_fields" );
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
	$chunk->appendChild( EPrints::Paginate->paginate_list( $self->{session}, "_buffer", $list, %opts ) );

	# TODO: alt phrase for empty list e.g. "cgi/users/home:no_pending"

	return $chunk;
}


1;
