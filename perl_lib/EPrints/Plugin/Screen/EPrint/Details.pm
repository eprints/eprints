package EPrints::Plugin::Screen::EPrint::Details;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 100,
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;
		
	return $self->allow( "eprint/details" );
}

sub _render_name_maybe_with_link
{
	my( $self, $eprint, $field ) = @_;

	my $r_name = $field->render_name( $eprint->{session} );

	return $r_name if !$self->edit_ok;

	my $name = $field->get_name;
	my $stage = $self->_find_stage( $eprint, $name );

	return $r_name if( !defined $stage );

	my $url = "?eprintid=".$eprint->get_id."&screen=".$self->edit_screen_id."&stage=$stage#$name";
	my $link = $eprint->{session}->render_link( $url );
	$link->setAttribute( title => $self->phrase( "edit_field_link",
			field => $self->{session}->xhtml->to_text_dump( $r_name )
		) );
	$link->appendChild( $r_name );
	return $link;
}

sub edit_screen_id { return "EPrint::Edit"; }

sub edit_ok
{
	my( $self ) = @_;

	return $self->{edit_ok};
}


sub _find_stage
{
	my( $self, $eprint, $name ) = @_;

	my $workflow = $self->workflow;

	return $workflow->{field_stages}->{$name};
}

sub render
{
	my( $self ) = @_;

	my $eprint = $self->{processor}->{eprint};
	my $session = $eprint->{session};
	my $workflow = $self->workflow;

	my $page = $session->make_doc_fragment;

	$self->{edit_ok} = $self->could_obtain_eprint_lock;
	$self->{edit_ok} &&= $self->allow( "eprint/edit" );

	my %stages;
	foreach my $stage ("", keys %{$workflow->{stages}})
	{
		$stages{$stage} = {
			count => 0,
			rows => [],
			unspec => $session->make_doc_fragment,
		};
	}

	my @fields = $eprint->get_dataset->get_fields;
	foreach my $field ( @fields )
	{
		next unless( $field->get_property( "show_in_html" ) );

		my $name = $field->get_name();

		my $stage = $self->_find_stage( $eprint, $name );
		$stage = "" if !defined $stage;

		my $rows = $stages{$stage}->{rows};
		my $unspec = $stages{$stage}->{unspec};
		$stages{$stage}->{count}++;

		my $r_name = $self->_render_name_maybe_with_link( $eprint, $field );

		if( $eprint->is_set( $name ) )
		{
			if( !$field->isa( "EPrints::MetaField::Subobject" ) )
			{
				push @$rows, $session->render_row(
					$r_name,
					$eprint->render_value( $field->get_name(), 1 ) );
			}
		}
		else
		{
			if( $unspec->hasChildNodes )
			{
				$unspec->appendChild( $session->make_text( ", " ) );
			}
			$unspec->appendChild( $r_name );
		}
	}

	my @docs = $eprint->get_all_documents;
	if( scalar @docs )
	{
		my $stage = $self->_find_stage( $eprint, 'documents' );
		$stage = "" if !defined $stage;

		my $rows = $stages{$stage}->{rows};
		$stages{$stage}->{count}++;

		foreach my $doc (@docs)
		{
			my $tr = $session->make_element( "tr" );
			push @$rows, $tr;
			my $th = $session->make_element( "th", class=>"ep_row" );
			$tr->appendChild( $th );
			my $td = $session->make_element( "td", class=>"ep_row" );
			$tr->appendChild( $td );

			if( $stage ne "" && $self->edit_ok )
			{
				my $url = "?eprintid=".$eprint->get_id."&screen=".$self->edit_screen_id."&stage=$stage&docid=".$doc->get_id."#documents";
				my $a = $session->render_link( $url );
				$a->appendChild( $doc->render_description );
				$th->appendChild( $session->html_phrase( 
					"lib/dataobj:document_title",
					doc=>$a ) );
			}
			else
			{
				$th->appendChild( $session->html_phrase( 
					"lib/dataobj:document_title",
					doc=>$doc->render_description ) );
			}
			
	
			
			my %files = $doc->files;	
			my @list = (
				"format", 
				"formatdesc", 
				"language", 
				"security",
				"license",
				"date_embargo",
			);
			if( scalar keys %files > 1 )
			{
				push @list, "main";
			}
			foreach my $name ( @list )
			{
				next if( !$doc->is_set( $name ) );
			
				my $field = $doc->get_dataset->get_field( $name );
				my $strong = $session->make_element( "strong" );
				$td->appendChild( $strong );
				$strong->appendChild( $field->render_name( $session ) );
				$strong->appendChild( $session->make_text( ": " ) );
				$td->appendChild( $doc->render_value( $name ) );
				$td->appendChild( $session->make_text( ". " ) );
			}
			my $ul = $session->make_element( "ul", style=>"margin-top: 0.2em; margin-bottom:0.2em" );
			$td->appendChild( $ul );
			foreach my $file ( keys %files )
			{
				my $li = $session->make_element( "li" );
				$ul->appendChild( $li );
				my $a = $session->render_link( $doc->get_url( $file ) );
				$a->appendChild( $session->make_text( $file ) );
				$li->appendChild( $a );
			}
		}
	}

	my $edit_screen = $session->plugin(
		"Screen::".$self->edit_screen_id,
		processor => $self->{processor} );

	my $table = $session->make_element( "table",
			border => "0",
			cellpadding => "3" );
	$page->appendChild( $table );

	foreach my $stage ($self->workflow->get_stage_ids, "")
	{
		my $unspec = $stages{$stage}->{unspec};
		next if $stages{$stage}->{count} == 0;

		my( $tr, $th, $td );

		my $rows = $stages{$stage}->{rows};

		my $url = URI->new( $session->current_url );
		$url->query_form(
			screen => $self->edit_screen_id,
			eprintid => $eprint->id,
			stage => $stage
		);

		$tr = $session->make_element( "tr" );
		$table->appendChild( $tr );
		$th = $session->make_element( "th", colspan => 2, class => "ep_title_row" );

		$tr->appendChild( $th );

		if( $stage eq "" )
		{
			$th->appendChild( $self->html_phrase( "other" ) );
		}
		else
		{
			my $title = $session->html_phrase( "metapage_title_$stage" );
			my $table_inner = $session->make_element( "table", style=>'width:100%' );
			my $tr_inner = $session->make_element( "tr" );
			my $td_inner_1 = $session->make_element( "td", style=>'text-align:left;margin-right:1em' );
			$th->appendChild( $table_inner );
			$table_inner->appendChild( $tr_inner );
			$tr_inner->appendChild( $td_inner_1 );
			$td_inner_1->appendChild( $title );
			if( $self->edit_ok )
			{
				my $td_inner_2  = $session->make_element( "td",style=>'text-align:right;font-size:80%' );
				$tr_inner->appendChild( $td_inner_2 );
				$td_inner_2->appendChild( $self->render_edit_button( $stage ) );
			}
		}

		if( $stage ne "" )
		{
			$tr = $session->make_element( "tr" );
			$table->appendChild( $tr );
			$td = $session->make_element( "td", colspan => 2 );
			$td->appendChild( $self->render_stage_warnings( $stage ) );
		}

		foreach $tr (@$rows)
		{
			$table->appendChild( $tr );
		}

		if( $stage ne "" && $unspec->hasChildNodes )
		{
			$table->appendChild( $session->render_row(
				$session->html_phrase( "lib/dataobj:unspecified" ),
				$unspec ) );
		}

		$tr = $session->make_element( "tr" );
		$table->appendChild( $tr );
		$td = $session->make_element( "td", colspan => 2, style=>'height: 1em' );
		$tr->appendChild( $td );
	}

	return $page;
}

sub render_edit_button
{
	my( $self, $stage ) = @_;

	my $session = $self->{session};

	my $div = $session->make_element( "div", class => "ep_act_list" );

	local $self->{processor}->{stage} = $stage;

	my $button = $self->render_action_button({
		screen => $session->plugin( "Screen::".$self->edit_screen_id,
			processor => $self->{processor},
		),
		screen_id => "Screen::".$self->edit_screen_id,
		hidden => [qw( eprintid stage )],
	});
	$div->appendChild( $button );

	return $div;
}

sub render_stage_warnings
{
	my( $self, $stage_id ) = @_;

	my $session = $self->{session};

	my $stage = $self->workflow->get_stage( $stage_id );

	my @problems = $stage->validate( $self->{processor} );

	return $session->make_doc_fragment if !scalar @problems;
 
	my $ul = $session->make_element( "ul" );
	foreach my $problem ( @problems )
	{
		my $li = $session->make_element( "li" );
		$li->appendChild( $problem );
		$ul->appendChild( $li );
	}
	$self->workflow->link_problem_xhtml( $ul, $self->edit_screen_id, $stage );

	return $session->render_message( "warning", $ul );
}

sub workflow
{
	my( $self ) = @_;

	my $staff = $self->allow( "eprint/edit:editor" );

	return $self->SUPER::workflow( $staff );
}

1;
