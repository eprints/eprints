
package EPrints::Plugin::Screen::Subject::Edit;

@ISA = ( 'EPrints::Plugin::Screen::Subject' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ save add /];

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


sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $subject = $self->{processor}->{subject};

	my $page = $session->make_doc_fragment;

	$page->appendChild( $self->html_phrase( "subjectid", 
		id=>$session->make_text( $subject->get_value( "subjectid" ) ) ) );

	if( $subject->get_id ne $EPrints::DataObj::Subject::root_subject )
	{
		$page->appendChild( $self->render_editbox );
	}
	$page->appendChild( $self->render_links );
	$page->appendChild( $self->render_subject_tree );
	$page->appendChild( $self->render_subject_children );
	$page->appendChild( $self->render_subject_add_node );

	return $page;
}

sub render_editbox
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $subject_ds = $session->get_repository->get_dataset( "subject" );
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

		$parts{field} = $field->render_input_field( 
			$self->{session}, 
			$value, 
			undef,
			0,
			undef,
			$subject,
			$prefix,
		  );

		$parts{help_prefix} = $prefix."_help_".$field->get_name;

		$table->appendChild( $self->{session}->render_row_with_help( %parts ) );
	}
        $form->appendChild( $session->render_action_buttons(
                save => $self->phrase( "action_save" ) ) );

	return $self->{session}->render_toolbox( 
		$self->html_phrase( "modify" ),
		$form );
}

sub allow_save { 1 };

sub action_save
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $subject = $self->{processor}->{subject};
	my $subject_ds = $session->get_repository->get_dataset( "subject" );
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

	my $session = $self->{session};

	my $subject = $self->{processor}->{subject};

	my $page = $session->make_doc_fragment();

	my @ids = @{$subject->get_value( "ancestors" )};
	foreach( $subject->get_children )
	{
		push @ids, $_->get_value( "subjectid" );
	}
	return $session->render_toolbox( 
		$self->html_phrase( "location" ),
		$session->render_subjects( \@ids, undef, $subject->get_id, 1 ) );
}

sub render_subject_children
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $archive_ds = $session->get_repository->get_dataset( "archive" );
	my $buffer_ds = $session->get_repository->get_dataset( "buffer" );
	my $subject_ds = $session->get_repository->get_dataset( "subject" );
	my $subject = $self->{processor}->{subject};

	my $page = $session->make_doc_fragment();

	my $form = $session->render_form( "post" );
	$form->appendChild( $session->render_hidden_field( "subjectid", $subject->get_id ) );
	$form->appendChild( $session->render_hidden_field( "screen", "Subject::Edit" ) );
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
		if( $children_n == 0 )
		{
			$td->appendChild( $session->render_action_buttons( 
				"unlink_".$_->get_value( "subjectid" ) =>
					$self->phrase( "action_".($parents_n == 1?"delete":"unlink") ) ) );
		}
		$tr->appendChild( $td );
		$table->appendChild( $tr );
	}
	$form->appendChild( $table );

	return $session->render_toolbox(
		$self->html_phrase( "children" ),
		$form );
}


sub render_subject_add_node
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $subject_ds = $session->get_repository->get_dataset( "subject" );
	my $subject = $self->{processor}->{subject};

	my $form = $session->render_form( "post" );
	$form->appendChild( $session->render_hidden_field( "subjectid", $subject->get_id ) );
	$form->appendChild( $session->render_hidden_field( "screen", "Subject::Edit" ) );

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

	return $self->{session}->render_toolbox( 
		$self->html_phrase( "add_child", subid=>$subject->render_value( "subjectid" ) ),
		$form );
}

sub allow_add { 1 };

sub action_add
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $newid = $session->param( "newnode_subjectid" );
	my $subject_ds = $session->get_repository->get_dataset( "subject" );
	my $subject = $self->{processor}->{subject};
	
	if( !EPrints::Utils::is_set( $newid ) )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "problem_noid" ) );
		return;
	}

	my $newchild = EPrints::DataObj::Subject->new( $session, $newid );
	if( defined $newchild )
	{
		if( grep( /^$newid$/, @{$subject->get_value( "ancestors" )} ) )
		{
			$self->{processor}->add_message( "error", $self->html_phrase( "problem_ancestor" ) );
			return;
		}

		my @parents = @{$newchild->get_value( "parents" )}; 
		push @parents, $subject->get_value( "subjectid" );
		$newchild->set_value( "parents", \@parents );
		$newchild->commit();

		$self->{processor}->add_message( "message", $self->html_phrase( "linked", newchild=>$newchild->render_description ) );
		return;
	}

	# new subject node
	my $newsubject = $subject_ds->create_object( $session, {
		subjectid => $newid,
		parents => [ $subject->get_value( "subjectid" ) ],
		depositable => 1 } );
	$newsubject->commit;

	$self->{processor}->add_message( "message", $self->html_phrase( "added", newchild=>$newsubject->render_value( "subjectid" ) ) );
	$self->{processor}->{subject} = $newsubject;
	$self->{processor}->{subjectid} = $newid;
}



sub redirect_to_me_url
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $subject_ds = $session->get_repository->get_dataset( "subject" );
	my $field = $subject_ds->get_field( "name" );
	return $self->SUPER::redirect_to_me_url.$field->get_state_params( $self->{session} );
}


sub from
{
	my( $self ) = @_;


	if( defined $self->{processor}->{internal} )
	{
		$self->action_save;
		return;
	}

	my $session = $self->{session};
	my $action = $session->get_action_button();
	if( defined $action && $action =~ m/^unlink_(.*)$/ )
	{
		my $victimid = $1;
		my $victim = EPrints::DataObj::Subject->new( $session, $victimid );
#		foreach( @{$victim->get_value( "parents" )} )
#		{
#		}
		if( !defined $victim )
		{
			$self->{processor}->add_message( "error", $self->html_phrase( "error_badsubject" ) );
			return;
		}
		elsif( scalar @{$victim->get_value( "parents" )}==1 )
		{
			$victim->remove();
			$self->{processor}->add_message( "message", $self->html_phrase( "removed" ) );
		}
		else
		{
			my @newparents = ();
			foreach( @{$victim->get_value( "parents" )} )
			{
				push @newparents,$_ if($_ ne $self->{processor}->{subject}->get_value("subjectid"));
			}
			$victim->set_value( "parents", \@newparents );
			$victim->commit();
			$self->{processor}->add_message( "message", $self->html_phrase( "unlinked" ) );
		}
		return;
	}

	$self->EPrints::Plugin::Screen::from;
}




























#######################################################

sub mkpage_editsubject
{
	my( $self, $session, $subid ) = @_;

	my $subject_ds = $session->get_repository->get_dataset( "subject" );

	my $subject;	
	
	my( $title );
	my $page = $session->make_doc_fragment();

	my $action = $session->get_action_button();
	my @problems = ();

	if( defined $action )
	{
		if( $action eq "add" )
		{
		}
	}
	if( scalar @problems )
	{	
		my $probdiv = $session->make_element( "div", class=>"problems" );
		my $ul = $session->make_element( "ul" );
		$probdiv->appendChild( $self->html_phrase( "problems" ) );
		$probdiv->appendChild( $ul );
		foreach( @problems )
		{
			my $li = $session->make_element( "li" );
			$li->appendChild( $_ );
			$ul->appendChild( $li );
		}
		$page->appendChild( $probdiv );
	}
}		
		
