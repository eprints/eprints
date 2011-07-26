=head1 NAME

EPrints::Plugin::Screen::Subject::Edit

=cut


package EPrints::Plugin::Screen::Subject::Edit;

@ISA = ( 'EPrints::Plugin::Screen::Subject' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ cancel save create link unlink remove /];

	$self->{appears} = [
		{
			place => "admin_actions_config",
			position => 2000,
		},
	];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "subject/edit" );
}

sub allow_cancel { 1 }
sub action_cancel {}

sub allow_save { 1 }
sub allow_create { 1 }
sub allow_link { 1 }
sub allow_unlink { 1 }
sub allow_remove { 1 }

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $subject = $self->{processor}->{subject};

	my $page = $session->make_doc_fragment;

#	$page->appendChild( $self->html_phrase( "subjectid", 
#		id=>$session->make_text( $subject->get_value( "subjectid" ) ) ) );

	$page->appendChild( $self->render_subject_tree );
	if( $subject->get_id ne $EPrints::DataObj::Subject::root_subject )
	{
		$page->appendChild( $self->render_editbox );
	}

	return $page;
}

sub render_editbox
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $subject_ds = $session->dataset( "subject" );
	my $subject = $self->{processor}->{subject};

	my $form = $session->render_form( "post" );
	$form->appendChild( $session->render_hidden_field( "subjectid", $subject->get_id ) );
	$form->appendChild( $session->render_hidden_field( "screen", "Subject::Edit" ) );
	my $table = $self->{session}->make_element( "table", class => "ep_multi" );
	$form->appendChild( $table );
	my $tbody = $self->{session}->make_element( "tbody" );
	$table->appendChild( $tbody );
	my $first = 1;
	my $prefix = "update";
	foreach my $field (
				$subject_ds->get_field( "subjectid" ),
				$subject_ds->get_field( "name" ),
				$subject_ds->get_field( "depositable" )
	) {
		my %parts;
		$parts{class} = "";
		$parts{class} = "ep_first" if $first;
		$first = 0;

		$parts{label} = $field->render_name( $self->{session} );

		if( $field->{required} eq "yes" ) # moj: Handle for_archive
		{
			$parts{label} = $self->{session}->html_phrase( 
				"sys:ep_form_required",
				label=>$parts{label} );
		}
 
		$parts{help} = $field->render_help( $self->{session} );


		# Get the field and its value/default
		my $value;
		if( $subject )
		{
			$value = $subject->get_value( $field->{name} );
		}
		if( $field->get_name eq "depositable" && !EPrints::Utils::is_set($value))
		{
			$value = "FALSE";
		}

		if( $field eq $subject_ds->key_field )
		{
			$parts{field} = $field->render_value( $self->{session}, $value );
		}
		else
		{
			$parts{field} = $field->render_input_field( 
				$self->{session}, 
				$value, 
				undef,
				0,
				undef,
				$subject,
				$prefix,
			  );
		}

		$parts{help_prefix} = $prefix."_help_".$field->get_name;

		$table->appendChild( $self->{session}->render_row_with_help( %parts ) );
	}
        $form->appendChild( $session->render_action_buttons(
                save => $self->phrase( "action_save" ) ) );

	return $self->{session}->render_toolbox( 
		undef,
		$form );
}

sub action_save
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $subject = $self->{processor}->{subject};
	my $subject_ds = $session->dataset( "subject" );
	my $name = $subject_ds->get_field( "name" )->form_value( $session, $subject, "update" );
	$subject->set_value( "name", $name );

	my $depositable = $subject_ds->get_field( "depositable" )->form_value( $session, $subject, "update" );
	$subject->set_value( "depositable", $depositable );
	$self->{processor}->add_message( "message", $self->html_phrase( "saved" ) );

	$subject->commit();
}


###############################

sub render_subject_tree
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $subject = $self->{processor}->{subject};
	my $dataset = $subject->get_dataset;

	my $tree = {
		$EPrints::DataObj::Subject::root_subject => $self->render_subject( $dataset->dataobj( $EPrints::DataObj::Subject::root_subject ), 1 ),
	};

	$self->_render_subject_tree( $tree, $subject );

	return $tree->{$EPrints::DataObj::Subject::root_subject};
}

sub _render_subject_tree
{
	my( $self, $tree, $current ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $subject = $self->{processor}->{subject};
	my $dataset = $subject->get_dataset;

	my $ul;

	my $first = 1;
	foreach my $parent ($current->get_parents)
	{
		my $container = $tree->{$parent->id};
		if( !defined $container )
		{
			$container = $self->_render_subject_tree( $tree, $parent );
			$tree->{$parent->id} = $container;
		}
		# ul -> li
		$container->firstChild->appendChild( $ul = $self->render_subject( $current, $first ) );
		$first = 0;
	}

	return defined $ul ? $ul : $self->render_subject( $current );
}

sub render_subject
{
	my( $self, $current, $show_children ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $subject = $self->{processor}->{subject};
	my $dataset = $subject->get_dataset;

	my $ul = $xml->create_element( "ul" );

	my $li = $ul->appendChild( $xml->create_element( "li" ) );
	if( $current->id eq $subject->id )
	{
		$li->appendChild( $xml->create_data_element( "strong",
			$current->render_citation( "edit",
				pindata => {
					inserts => {
						n => $xml->create_text_node( $current->count_eprints( $repo->dataset( "eprint" ) ) )
					},
				},
			)
		) );
		$li->appendChild( $self->render_children )
			if $show_children;
	}
	else
	{
		my $url = $repo->current_url( path => "cgi", "users/home" );
		$url->query_form(
			$self->hidden_bits,
			subjectid => $current->id,
		);
		$li->appendChild( $current->render_citation( "edit",
			url => $url,
			pindata => {
				inserts => {
					n => $xml->create_text_node( $current->count_eprints( $repo->dataset( "eprint" ) ) )
				},
			},
		) );
	}

	return $ul;
}

sub render_children
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $subject = $self->{processor}->{subject};
	my $dataset = $subject->get_dataset;

	my $table = $xml->create_element( "table" );

	# child subjects
	foreach my $child ($subject->get_children)
	{
		my $tr = $table->appendChild( $xml->create_element( "tr", class => "ep_row" ) );
		my $url = $repo->current_url( path => "cgi", "users/home" );
		$url->query_form(
			$self->hidden_bits,
			subjectid => $child->id,
		);
		my $td = $tr->appendChild( $xml->create_element( "td", class => "ep_row" ) );
		$td->appendChild( $child->render_citation( "edit",
			url => $url,
		) );
		$td = $tr->appendChild( $xml->create_element( "td", class => "ep_row", style => "text-align: right" ) );
		$td->appendChild( $xml->create_text_node( $child->count_eprints( $repo->dataset( "eprint" ) ) ) );
		$td = $tr->appendChild( $xml->create_element( "td", class => "ep_row" ) );
		my $form = $td->appendChild( $self->render_form );
		$form->appendChild( $xhtml->hidden_field( childid => $child->id ) );
		$form->appendChild( $xhtml->action_button(
			unlink => $self->phrase( "action_unlink" )
		) );
	}

	# create new child
	{
		my $tr = $table->appendChild( $xml->create_element( "tr", class => "ep_row" ) );
		my $td = $tr->appendChild( $xml->create_element( "td", class => "ep_row", colspan => 3 ) );
		my $form = $td->appendChild( $self->render_form );
		$form->appendChild( $dataset->field( "subjectid" )->render_name );
		$form->appendChild( $xml->create_text_node( ": " ) );
		$form->appendChild( $xhtml->input_field( childid => undef ) );
		$form->appendChild( $xhtml->action_button(
			create => $repo->phrase( "lib/submissionform:action_create" )
		) );
	}

	# link existing child
	{
		my $tr = $table->appendChild( $xml->create_element( "tr", class => "ep_row" ) );
		my $td = $tr->appendChild( $xml->create_element( "td", class => "ep_row", colspan => 3 ) );
		my $form = $td->appendChild( $self->render_form );
		my $select = $form->appendChild( $xml->create_element( "select",
			name => "childid",
		) );
		$subject->get_dataset->search->map(sub {
			my( undef, undef, $child ) = @_;

			$select->appendChild( $xml->create_data_element( "option",
				$child->id,
				value => $child->id,
			) );
		});
		$form->appendChild( $xhtml->action_button(
			link => $self->phrase( "action_link" )
		) );
	}

	return $table;
}

sub _render_children
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	
	my @labels;
	my @panels;

	push @labels, $self->html_phrase( "children" );
	push @panels, $self->render_subject_children;

	push @labels, $self->html_phrase( "action_link" );
	push @panels, $self->render_link_child;

	push @labels, $self->html_phrase( "action_add" );
	push @panels, $self->render_subject_add_node;

	return $repo->xhtml->tabs(
		\@labels,
		\@panels,
	);
}

sub render_link_child
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $subject_ds = $repo->dataset( "subject" );
	my $subject = $self->{processor}->{subject};

	my $form = $self->render_form;

	my $ancestors = $subject->value( "ancestors" );
	$form->appendChild( EPrints::MetaField->new(
		name => "subjectid",
		type => "subject",
		dataset => $subject->get_dataset,
		repository => $repo,
		top => $ancestors->[$#$ancestors - 1],
		input_rows => 8,
		showall => 1,
	)->render_input_field(
			$repo,
			undef,
			undef,
			0,
			undef,
			undef,
			"oldnode"
	) );

	$form->appendChild( $repo->render_action_buttons(
				link => $self->phrase( "action_link" ) ) );

	return $form;
}
	
sub render_subject_children
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $archive_ds = $session->dataset( "archive" );
	my $buffer_ds = $session->dataset( "buffer" );
	my $subject_ds = $session->dataset( "subject" );
	my $subject = $self->{processor}->{subject};

	my $page = $session->make_doc_fragment();

	my $form = $session->render_form( "post" );
	$form->appendChild( $self->render_hidden_bits );
	$form->appendChild( $session->render_hidden_field( "_action_unlink", "1" ) );
	$page->appendChild( $form );

	my( $table, $tr, $td, $th, $a );
	$table = $session->make_element( "table", border=>1, cellpadding=>4, cellspacing=>0 );

	$tr = $session->make_element( "tr" );
	
	$th = $session->make_element( "th" );
	$th->appendChild( $self->html_phrase( "subject" ) );
	$tr->appendChild( $th );

	$th = $session->make_element( "th" );
	$th->appendChild( $self->html_phrase( "inarchive" ) );
	$tr->appendChild( $th );

#	$th = $session->make_element( "th" );
#	$th->appendChild( $self->html_phrase( "cgi/users/edit_subject:inbuffer" ) );
#	$tr->appendChild( $th );

	$th = $session->make_element( "th" );
	$th->appendChild( $self->html_phrase( "nparents" ) );
	$tr->appendChild( $th );

	$th = $session->make_element( "th" );
	$th->appendChild( $self->html_phrase( "nchildren" ) );
	$tr->appendChild( $th );

	$table->appendChild( $tr );


	foreach( $subject->get_children )
	{
		$tr = $session->make_element( "tr" );

		$td = $session->make_element( "td", align=>"left");
		$a = $session->render_link( "?screen=Subject::Edit&subjectid=".$_->get_value( "subjectid" ) );
		$a->appendChild( $_->render_description() );
		$td->appendChild( $a );
		$tr->appendChild( $td );
		
		$td = $session->make_element( "td", align=>"center");
		$td->appendChild( $session->make_text( $_->count_eprints( $archive_ds ) ) );
		$tr->appendChild( $td );

#		$td = $session->make_element( "td", align=>"center");
#		$td->appendChild( $session->make_text( $_->count_eprints( $buffer_ds ) ) );
#		$tr->appendChild( $td );

		my $parents_n = scalar @{$_->get_value( "parents" )};
		my $children_n = scalar $_->get_children;

		$td = $session->make_element( "td", align=>"center");
		$td->appendChild( $session->make_text( $parents_n ) );
		$tr->appendChild( $td );
		
		$td = $session->make_element( "td", align=>"center");
		$td->appendChild( $session->make_text( $children_n ) );
		$tr->appendChild( $td );
		
		$td = $session->make_element( "td" );
		$td->appendChild( $session->render_action_buttons( 
				"unlink_".$_->id => $self->phrase( "action_unlink" ) ) );
		$tr->appendChild( $td );
		$table->appendChild( $tr );
	}
	$form->appendChild( $table );

	return $form;
}


sub render_subject_add_node
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $subject_ds = $session->dataset( "subject" );
	my $subject = $self->{processor}->{subject};

	my $form = $self->render_form;

	my $field = $subject_ds->get_field( "subjectid" );

	my $table = $session->make_element( "table", width=>"100%" );
	$form->appendChild( $table );
	my $prefix = "newnode";

	my %parts;
	$parts{class} = "ep_first";
	$parts{label} = $field->render_name( $self->{session} );
	$parts{help} = $field->render_help( $self->{session} );

	$parts{field} = $field->render_input_field( 
		$self->{session}, 
		undef, 
		undef,
		0,
		undef,
		undef,
		$prefix,
	  );

	$parts{help_prefix} = $prefix."_help_".$field->get_name;

	$table->appendChild( $self->{session}->render_row_with_help( %parts ) );

        $form->appendChild( $session->render_action_buttons(
                add => $self->phrase( "action_add" ) ) );

	return $form;
}

sub action_create
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $subject_ds = $session->dataset( "subject" );
	my $subject = $self->{processor}->{subject};
	
	my $childid = $session->param( "childid" );
	return if !EPrints::Utils::is_set( $childid );

	my $child = $subject_ds->dataobj( $childid );
	if( defined $child )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "exists" ) );
		return;
	}

	# new subject node
	$child = $subject_ds->create_dataobj( {
		subjectid => $childid,
		parents => [ $subject->id ],
		depositable => 1 } );

	$self->{processor}->add_message( "message", $self->html_phrase( "added", newchild=>$child->render_value( "subjectid" ) ) );
	$self->{processor}->{subject} = $child;
	$self->{processor}->{subjectid} = $child->id;
}

sub action_link
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $subject_ds = $session->dataset( "subject" );
	my $subject = $self->{processor}->{subject};
	
	my $childid = $session->param( "childid" );
	return if !EPrints::Utils::is_set( $childid );

	my $child = $subject_ds->dataobj( $childid );

	if( grep { $_ eq $childid } @{$subject->get_value( "ancestors" )} )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "problem_ancestor" ) );
		return;
	}

	$child->set_value( "parents", [
		@{$child->value( "parents" )},
		$subject->id,
	]);
	$child->commit();

	$self->{processor}->add_message( "message", $self->html_phrase( "linked", newchild=>$child->render_description ) );
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $subject_ds = $session->dataset( "subject" );
	my $field = $subject_ds->get_field( "name" );
	return $self->SUPER::redirect_to_me_url.$field->get_state_params( $self->{session} );
}

sub action_unlink
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $subject_ds = $repo->dataset( "subject" );
	my $subject = $self->{processor}->{subject};
	
	my $childid = $repo->param( "childid" );

	# already deleted?
	my $child = $subject_ds->dataobj( $childid );
	return if !defined $child;

	# already unlinked?
	return if !grep { $_ eq $subject->id } @{$child->value( "ancestors" )};

	# are we deleting?
	if( @{$child->value( "parents" )} < 2 )
	{
		my $form = $self->render_form;
		$form->appendChild( $repo->xhtml->hidden_field( childid => $childid ) );
		$form->appendChild( $repo->render_action_buttons(
			remove => $repo->phrase( "lib/submissionform:action_remove" ),
			cancel => $repo->phrase( "lib/submissionform:action_cancel" ),
			_order => [qw( remove cancel )],
		) );
		$self->{processor}->add_message( "warning", $self->html_phrase( "confirm_form",
			form => $form,
		) );
		return;
	}

	$child->set_value( "parents", [
		grep { $_ ne $subject->id } @{$child->value( "parents" )}
		]);
	$child->commit;
	$self->{processor}->add_message( "message", $self->html_phrase( "unlinked" ) );
}

sub action_remove
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $subject_ds = $repo->dataset( "subject" );
	my $subject = $self->{processor}->{subject};
	my $childid = $repo->param( "childid" );
	
	my $child = $subject_ds->dataobj( $childid );

	# already removed?
	return if !defined $child;

	$child->remove();
	$self->{processor}->add_message( "message", $self->html_phrase( "removed" ) );
}

sub from
{
	my( $self ) = @_;


	if( defined $self->{processor}->{internal} )
	{
		$self->action_save;
		return;
	}

	$self->EPrints::Plugin::Screen::from;
}

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

