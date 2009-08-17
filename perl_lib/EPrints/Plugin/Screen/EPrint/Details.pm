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

	my $r_name = $field->render_name( $eprint->{handle} );
	my $name = $field->get_name;
	my $stage = $self->_find_stage( $eprint, $name );

	return $r_name if( !defined $stage );

	my $url = "?eprintid=".$eprint->get_id."&screen=".$self->edit_screen_id."&stage=$stage#$name";
	my $link = $eprint->{handle}->render_link( $url );
	$link->appendChild( $r_name );
	return $link;
}

sub edit_screen_id { return "EPrint::Edit"; }

sub edit_ok
{
	my( $self ) = @_;

	return $self->allow( "eprint/edit" ) & 4;
}


sub _find_stage
{
	my( $self, $eprint, $name ) = @_;

	return undef unless $self->edit_ok;
	my $workflow = $self->workflow;

	return $workflow->{field_stages}->{$name};
}

sub render
{
	my( $self ) = @_;

	my $eprint = $self->{processor}->{eprint};
	my $handle = $eprint->{handle};

	my $unspec_fields = $handle->make_doc_fragment;
	my $unspec_first = 1;

	my $page = $handle->make_doc_fragment;
	# Show all the fields
	my $table = $handle->make_element( "table",
					border=>"0",
					cellpadding=>"3" );
	$page->appendChild( $table );

	my @fields = $eprint->get_dataset->get_fields;
	foreach my $field ( @fields )
	{
		next unless( $field->get_property( "show_in_html" ) );
		next if( $field->is_type( "subobject" ) );

		my $r_name = $self->_render_name_maybe_with_link( $eprint, $field );

		my $name = $field->get_name();
		if( $eprint->is_set( $name ) )
		{
			$table->appendChild( $handle->render_row(
				$r_name,
				$eprint->render_value( $field->get_name(), 1 ) ) );
			next;
		}

		# unspecified value, add it to the list
		if( $unspec_first )
		{
			$unspec_first = 0;
		}
		else
		{
			$unspec_fields->appendChild( 
				$handle->make_text( ", " ) );
		}
		$unspec_fields->appendChild( $self->_render_name_maybe_with_link( $eprint, $field ) );
	}

	my @docs = $eprint->get_all_documents;
	if( scalar @docs )
	{
		my $stage = $self->_find_stage( $eprint, 'documents' );
	
		foreach my $doc (@docs)
		{
			my $tr = $handle->make_element( "tr" );
			$table->appendChild( $tr );
			my $th = $handle->make_element( "th", class=>"ep_row" );
			$tr->appendChild( $th );
			my $td = $handle->make_element( "td", class=>"ep_row" );
			$tr->appendChild( $td );

			if( defined $stage )
			{
				my $url = "?eprintid=".$eprint->get_id."&screen=".$self->edit_screen_id."&stage=$stage&docid=".$doc->get_id."#documents";
				my $a = $handle->render_link( $url );
				$a->appendChild( $doc->render_description );
				$th->appendChild( $handle->html_phrase( 
					"lib/dataobj:document_title",
					doc=>$a ) );
			}
			else
			{
				$th->appendChild( $handle->html_phrase( 
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
				my $strong = $handle->make_element( "strong" );
				$td->appendChild( $strong );
				$strong->appendChild( $field->render_name( $handle ) );
				$strong->appendChild( $handle->make_text( ": " ) );
				$td->appendChild( $doc->render_value( $name ) );
				$td->appendChild( $handle->make_text( ". " ) );
			}
			my $ul = $handle->make_element( "ul" );
			$td->appendChild( $ul );
			foreach my $file ( keys %files )
			{
				my $li = $handle->make_element( "li" );
				$ul->appendChild( $li );
				my $a = $handle->render_link( $doc->get_url( $file ) );
				$a->appendChild( $handle->make_text( $file ) );
				$li->appendChild( $a );
			}
		}
	}	
	my $h3 = $handle->make_element( "h3" );
	$page->appendChild( $h3 );
	$h3->appendChild( $handle->html_phrase( "lib/dataobj:unspecified" ) );
	$page->appendChild( $unspec_fields );

	return $page;
}




1;
