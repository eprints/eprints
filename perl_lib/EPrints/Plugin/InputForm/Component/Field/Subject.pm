=head1 NAME

EPrints::Plugin::InputForm::Component::Field::Subject

=cut

package EPrints::Plugin::InputForm::Component::Field::Subject;

use EPrints;
use EPrints::Plugin::InputForm::Component::Field;
@ISA = ( "EPrints::Plugin::InputForm::Component::Field" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "Subject";
	$self->{visible} = "all";
	$self->{visdepth} = 1;
	$self->{search_q_style} = ( EPrints::Utils::require_if_exists( "Search::Xapian" ) ) ? "_q" : "q"; # sorry
	return $self;
}

sub parse_config
{
	my( $self, $config_dom ) = @_;

	$self->SUPER::parse_config( $config_dom );
	$self->{config}->{citation} = $config_dom->getAttribute( "citation" );

	return 1;
}

sub update_from_form
{
	my( $self, $processor ) = @_;
	my $field = $self->{config}->{field};

	my $ibutton = $self->get_internal_button;
	return unless defined $ibutton;
	if( $ibutton =~ /^(.+)_add$/ )
	{
		my $subject = $1;
		my $value;
		if( $field->get_property( "multiple" ) )
		{
			my %vals = ();

			my $values = $self->{dataobj}->get_value( $field->get_name );
			foreach my $s ( @$values, $subject )
			{
				$vals{$s} = 1;
			}
			
			$value = [sort keys %vals];
		}
		else
		{
			$value = $subject;
		}
		$self->{dataobj}->set_value( $field->get_name, $value );
		$self->{dataobj}->commit;
	}
	
	if( $ibutton =~ /^(.+)_remove$/ )
	{
		my $subject = $1;
		my $value;
		if( $field->get_property( "multiple" ) )
		{
			my %vals = ();
			
			my $values = $self->{dataobj}->get_value( $field->get_name );
			foreach my $s ( @$values )
			{
				$vals{$s} = 1;
			}
			delete $vals{$subject};
			
			$value = [sort keys %vals];
		}
		else
		{
			$value = undef;
		}
		$self->{dataobj}->set_value( $field->get_name, $value );
		$self->{dataobj}->commit;
	}

	return;
}



sub render_content
{
	my( $self, $surround ) = @_;

	my $session = $self->{session};
	my $field = $self->{config}->{field};
	my $eprint = $self->{workflow}->{item};

	( $self->{subject_map}, $self->{reverse_map} ) = EPrints::DataObj::Subject::get_all( $session );

	my $out = $self->{session}->make_element( "div" );

	$self->{top_subj} = $field->get_top_subject( $session );

	# populate selected and expanded values	

	$self->{expanded} = {};
	$self->{selected} = {};
	$self->{whitelist} = undef;

	my @values;
	if( $field->get_property( "multiple" ) )
	{
		@values = @{$field->get_value( $eprint )};
	}
	elsif( $eprint->is_set( $field->get_name ) )
	{
		push @values, $field->get_value( $eprint );
	}
	foreach my $subj_id ( @values )
	{
		$self->{selected}->{$subj_id} = 1;
		my $subj = $self->{subject_map}->{ $subj_id };
		next if !defined $subj;
		my @paths = $subj->get_paths( $session, $self->{top_subj} );
		foreach my $path ( @paths )
		{
			foreach my $s ( @{$path} )
			{
				$self->{expanded}->{$s->get_id} = 1;
			}
		}
	}

	if( scalar @values )
	{
		$out->appendChild( $self->_format_subjects(
			table_class => "ep_subjectinput_selections",
			subject_class => "ep_subjectinput_selected_subject",
			button_class => "ep_subjectinput_selected_remove",
			button_text => $self->phrase( "remove" ),
			button_id => "remove",
			values => \@values,
			map => $self->{subject_map}
			) );
	}
	
	# Render the search box

	$self->{search} = $self->_prepare_search;
	
	my $ibutton = $session->param( $self->{prefix}."_action" );
	$ibutton = "" unless defined $ibutton;

	if( $ibutton eq "clear" )
	{
		$self->{search}->clear;
	}

	$out->appendChild( $self->_render_search );

	if( !$self->{search}->is_blank )
	{
		my $results = $self->{search}->perform_search;
		
		$self->{whitelist} = {};

		if( !$results->count )
		{
			$out->appendChild( $self->html_phrase(
				"search_no_matches" ) );
		}
		else
		{
			$results->map(sub {
				(undef, undef, my $subject) = @_;

				foreach my $ancestor ( @{$subject->value( "ancestors" )} )
				{	
					$self->{whitelist}->{$ancestor} = 1;
				}
			});
		}
	}

	# if $whitelist is empty $tree will be undef
	my $tree = $self->_tree( $self->{top_subj}, 0, {} );
	if( defined $tree )
	{
		$out->appendChild( $session->xhtml->tree(
			$tree->[1], # don't want the root subject
			prefix => $self->{prefix} . "_tree",
			class => "ep_subjectinput_tree",
			render_value => sub { $self->_render_node( @_ ) },
		) );
	}

	return $out;
}

sub _render_node
{
	my( $self, $subject, $children ) = @_;

	my $session = $self->{session};

	my $frag = $session->make_doc_fragment;

	my $title;
	if( $self->{config}->{citation} )
	{
		$title = $subject->render_citation( $self->{config}->{citation} );
	}
	else
	{
		$title = $subject->render_description;
	}

	# clickable
	if( defined $children )
	{
		$title = $session->xml->create_data_element( "a",
			$title,
		);
	}

	# selected
	if( $self->{selected}->{$subject->id} )
	{
		$frag->appendChild( $session->xml->create_data_element( "span",
			$title,
			class => "ep_subjectinput_selected",
		) );
	}
	# can be selected
	elsif( $subject->can_post )
	{
		$frag->appendChild( $session->render_button(
			class=> "ep_subjectinput_add_button",
			name => join('_', '_internal', $self->{prefix}, $subject->id, 'add'),
			value => $self->phrase( "add" ) ) );
		$frag->appendChild( $session->make_text( " " ) );
		$frag->appendChild( $title );
	}
	else
	{
		$frag->appendChild( $title );
	}

	return $frag;
}

sub _prepare_search
{
	my( $self ) = @_;
	my $session = $self->{session};
	
	my $dataset = $session->dataset( "subject" );

	my $sconf = $session->config( "datasets", "subject", "search", "simple" );

	# default search over subject name
	$sconf = {
		search_fields => [{
			id => "q",
			meta_fields => [qw( name )],
		}],
	} if !defined $sconf;

	my $searchexp = $session->plugin( "Search" )->plugins(
		{
			dataset => $dataset,
			prefix => $self->{prefix},
			filters => [
				{ meta_fields => [qw( ancestors )], value => $self->{top_subj}->id },
			],
			%$sconf,
		},
		can_search => "simple/subject",
	);

	$searchexp->from_form;

	return $searchexp;
}

# Params:
# table_class: Class for the table
# subject_class: Class for the subject cell
# button_class: Class for the button cell
# button_text: Text for the button
# button_id: postfix for the button name
# subjects: array of subjects
# hide_selected: If 1, hides any already selected subjects.

sub _format_subjects
{
	my( $self, %params ) = @_;

	my $session = $self->{session};
	my $field = $self->{config}->{field};
	my $table = $session->make_element( "table", class=>$params{table_class} );
	my $first = 1;
	foreach my $subject_id (@{$params{values}})
	{
		my $subject = $params{map}{$subject_id};

		next if $params{hide_selected} && $self->{selected}->{ $subject_id };
		my $prefix = $self->{prefix}."_".$subject_id;
		my $tr = $session->make_element( "tr" );
		
		my $td1 = $session->make_element( "td" );
		my $remove_button = $session->render_button(
			class=> "ep_subjectinput_remove_button",
			name => "_internal_".$prefix."_".$params{button_id},
			value => $params{button_text} );
		$td1->appendChild( $remove_button );
		my $td2 = $session->make_element( "td" );
		if( defined $subject )
		{
			$td2->appendChild( $subject->render_description );
		}
		else
		{
			$td2->appendChild( $field->render_single_value( $session, $subject_id ) );
		}
		
		my @td1_attr = ( $params{subject_class} );
		my @td2_attr = ( $params{button_class} );
		if( $first )
		{
			push @td1_attr, "ep_first";
			push @td2_attr, "ep_first";
			$first = 0;
		}
		$td1->setAttribute( "class", join(" ", @td1_attr ) );
		$td2->setAttribute( "class", join(" ", @td2_attr ) );
					
		$tr->appendChild( $td1 ); 
		$tr->appendChild( $td2 );
		
		$table->appendChild( $tr );
	}
	return $table;
}

sub _render_search
{
	my( $self ) = @_;
	my $prefix = $self->{prefix};
	my $session = $self->{session};
	my $field = $self->{config}->{field};
	my $bar = $self->html_phrase(
		$field->get_name."_search_bar",
		input => $self->{search}->render_simple_fields(
			noenter => 0,
			size => 40,
		),
		search_button=>$session->render_button( 
			name=>"_internal_".$prefix."_search",
			id=>"_internal_".$prefix."_search",
			value=>$self->phrase( "search_search_button" ) ),
		clear_button=>$session->render_button(
			name=>"_internal_".$prefix."_clear",
			value=>$self->phrase( "search_clear_button" ) ),
		);
	return $bar;
}

# builds a tree that XHTML can render from the subject tree
sub _tree
{
	my( $self, $top, $depth, $seen ) = @_;

	my $id = $top->id;

	# infinite loop protection
##this prevents multi parent node to be rendered, hence commented out
#	return if $seen->{$id}++;

	return if defined($self->{whitelist}) && !$self->{whitelist}->{$id};

	my $children = $self->{reverse_map}->{$id};
	return $top if !@$children;

	my $node = [$top,
		[ map { $self->_tree( $_, $depth + 1, $seen ) } @$children ],
		show => (
			defined($self->{whitelist}) ||
			$depth < $self->{visdepth} ||
			$self->{expanded}->{$id}
		),
	];

	return $node;
}

sub get_state_params
{
	my( $self ) = @_;

	my $params = "";
	foreach my $id ( $self->{prefix}.$self->{search_q_style} )
	{
		my $v = $self->{session}->param( $id );
		next unless defined $v;
		$params.= "&$id=$v";
	}

	if( defined $self->{session}->param( "_internal_".$self->{prefix}."_search" ) )
	{
		$params .= "&".$self->{prefix}."_action=search";
	}
	elsif( defined $self->{session}->param( "_internal_".$self->{prefix}."_clear" ) )
	{
		$params .= "&".$self->{prefix}."_action=clear";
	}

	return $params;	
}

1;

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

