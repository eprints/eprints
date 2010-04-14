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
			table => $session->make_element( "table",
					border=>"0",
					cellpadding=>"3" ),
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

		my $table = $stages{$stage}->{table};
		my $unspec = $stages{$stage}->{unspec};
		$stages{$stage}->{count}++;

		my $r_name = $self->_render_name_maybe_with_link( $eprint, $field );

		if( $eprint->is_set( $name ) )
		{
			if( !$field->isa( "EPrints::MetaField::Subobject" ) )
			{
				$table->appendChild( $session->render_row(
					$r_name,
					$eprint->render_value( $field->get_name(), 1 ) ) );
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

		my $table = $stages{$stage}->{table};
		$stages{$stage}->{count}++;

		foreach my $doc (@docs)
		{
			my $tr = $session->make_element( "tr" );
			$table->appendChild( $tr );
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
			my $ul = $session->make_element( "ul" );
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

	foreach my $stage ($self->workflow->get_stage_ids, "")
	{
		my $table = $stages{$stage}->{table};
		my $unspec = $stages{$stage}->{unspec};
		next if $stages{$stage}->{count} == 0;

		my $url = URI->new( $session->current_url );
		$url->query_form(
			screen => $self->edit_screen_id,
			eprintid => $eprint->id,
			stage => $stage
		);

		my $div = $session->make_element( "div" );
		$page->appendChild( $div );
		my $h3 = $session->make_element( "h3" );
		$div->appendChild( $h3 );
		if( $stage eq "" )
		{
			$h3->appendChild( $self->html_phrase( "other" ) );
		}
		else
		{
#			$h3->appendChild( $edit_screen->html_phrase( "title" ) );
#			$h3->appendChild( $session->make_text( ": " ) );
			$h3->appendChild( $session->html_phrase( "metapage_title_$stage" ) );
		}

		$div->appendChild( $table );

		if( $stage ne "" && $unspec->hasChildNodes )
		{
			$table->appendChild( $session->render_row(
				$session->html_phrase( "lib/dataobj:unspecified" ),
				$unspec ) );
		}

		if( $stage ne "" && $self->edit_ok )
		{
			my $form = $session->render_form;
			$div->appendChild( $form );
			$form->appendChild( $session->render_hidden_field(
				screen => substr($edit_screen->{id},8)
				) );
			$form->appendChild( $session->render_hidden_field(
				eprintid => $eprint->id
				) );
			$form->appendChild( $session->render_hidden_field(
				stage => $stage
				) );
			my $button = $session->make_element( "input",
				type => "submit",
				value => $edit_screen->phrase( "title" ).": ".$session->phrase( "metapage_title_$stage" ),
				class => "ep_blister_node" );
			$form->appendChild( $button );
		}
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

sub workflow
{
	my( $self ) = @_;

	my $staff = $self->allow( "eprint/edit:editor" );

	return $self->SUPER::workflow( $staff );
}

1;
