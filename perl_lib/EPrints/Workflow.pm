######################################################################
#
# EPrints::Workflow
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::Workflow> - Models the submission process used by an repository. 

=head1 DESCRIPTION

The workflow class handles loading the workflow configuration for a 
single repository. 

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{xmldoc}
#     A XML document to hold all the stray DOM elements.
#
######################################################################

package EPrints::Workflow;

use EPrints::Workflow::Stage;

use strict;

######################################################################
=pod

=item $language = EPrints::Workflow->new( $handle, $workflow_id, %params )

Create a new workflow object representing the specification given in
the workflow.xml configuration

# needs more config - about object etc.

=cut
######################################################################

sub new
{
	my( $class , $handle, $workflow_id, %params ) = @_;

	my $self = {};

	bless $self, $class;
	
	$self->{repository} = $handle->get_repository;
	$self->{handle} = $handle;
	$self->{dataset} = $params{item}->get_dataset;
	$self->{item} = $params{item};
	$self->{workflow_id} = $workflow_id;

	$params{handle} = $handle;
	$params{current_user} = $handle->current_user;
	$self->{user} = $params{current_user};

	$params{in} = $self->description;

	$self->{raw_config} = $self->{repository}->get_workflow_config( $self->{dataset}->confid, $workflow_id );

	if( !defined $self->{raw_config} ) 
	{
		EPrints::abort( "Failed to find workflow: ".$self->{dataset}->confid.".$workflow_id" );
	}
	$self->{config} = EPrints::XML::EPC::process( $self->{raw_config}, %params );

	$self->_read_flow;
	$self->_read_stages;

	return( $self );
}

sub get_stage_id
{
	my( $self ) = @_;
	
	if( !defined $self->{stage} )
	{
		$self->{stage} = $self->{handle}->param( "stage" );
	}
	if( !defined $self->{stage} )
	{
		$self->{stage} = $self->get_first_stage_id;
	}

	return $self->{stage};
}

sub description
{
	my( $self ) = @_;

	return "Workflow (".$self->{dataset}->confid.",".$self->{workflow_id}.")";
}

sub _read_flow
{
	my( $self, $doc ) = @_;

	$self->{stage_order} = [];
	$self->{stage_number} = {};

	my $flow = ($self->{config}->getElementsByTagName("flow"))[0];
	if(!defined $flow)
	{
		EPrints::abort( $self->description." - no <flow> element.\n" );
		return;
	}
	my $has_stages = 0; 
	foreach my $element ( $flow->getChildNodes )
	{
		my $name = $element->nodeName;
		if( $name eq "stage" )
		{
			my $ref = $element->getAttribute("ref");
			if( !EPrints::Utils::is_set( $ref ) )
			{
				EPrints::abort( $self->description." - <stage> in <flow> has no ref attribute." );
			}
			push @{$self->{stage_order}}, $ref;
			$has_stages = 1;
		}
	}

	if( $has_stages == 0 )
	{
		EPrints::abort( $self->description." - no stages in <flow> element." );
	}

	# renumber stages
	my $n = 0;
	$self->{stage_number} = {};
	foreach my $stage_id ( @{$self->{stage_order}} )
	{
		$self->{stage_number}->{$stage_id} = $n;
		$n += 1;
	}
}


sub _read_stages
{
	my( $self ) = @_;

	$self->{stages}={};
	$self->{field_stages}={};

	foreach my $element ( $self->{config}->getChildNodes )
	{
		my $e_name = $element->nodeName;
		next unless( $e_name eq "stage" );

		my $stage_id = $element->getAttribute("name");
		if( !EPrints::Utils::is_set( $stage_id ) )
		{
			EPrints::abort( $self->description." - <element> definition has no name attribute.\n".$element->toString );
		}
		$self->{stages}->{$stage_id} = new EPrints::Workflow::Stage( $element, $self, $stage_id );
		foreach my $field_id ( $self->{stages}->{$stage_id}->get_fields_handled )
		{
			$self->{field_stages}->{$field_id} = $stage_id;
		}
	}

	foreach my $stage_id ( @{$self->{stage_order}} )
	{
		if( !defined $self->{stages}->{$stage_id} )
		{
			EPrints::abort( $self->description." - stage $stage_id defined in <flow> but not actually defined in the body of the workflow\n" );
		}
	}
}

sub validate
{
	my( $self, $processor ) = @_;

	my @problems = ();
	foreach my $stage_id ( $self->get_stage_ids )
	{
		my $stage_obj = $self->get_stage( $stage_id );
		push @problems, $stage_obj->validate;
	}

	return @problems;
}

sub get_stage_ids
{
	my( $self ) = @_;

	return @{$self->{stage_order}};
}

# note - this can return a stage not in the flow, but defined in the body.
sub get_stage
{
	my( $self, $stage_id ) = @_;
  
	return $self->{stages}->{$stage_id};
}

sub get_first_stage_id
{
	my( $self ) = @_;

	return $self->{stage_order}->[0];
}

sub get_last_stage_id
{
	my( $self ) = @_;

	return $self->{stage_order}->[-1];
}

sub get_next_stage_id
{
	my( $self ) = @_;

	my $num = $self->{stage_number}->{$self->get_stage_id};

	if( $num == scalar @{$self->{stage_order}}-1 )
	{
		return undef;
	}

	return $self->{stage_order}->[$num+1];
}

# return false if it fails to set the stage
sub set_stage
{
	my( $self, $stage_id ) = @_;

	return 0 if( !defined $self->{stages}->{$stage_id} );

	$self->{stage} = $stage_id;
	
	return 1;
}


sub next
{
	my( $self ) = @_;

	$self->{stage} = $self->get_next_stage_id;
}

sub get_prev_stage_id
{
	my( $self ) = @_;

	my $num = $self->{stage_number}->{$self->get_stage_id};

	if( $num == 0 )
	{
		return undef;
	}

	return $self->{stage_order}->[$num-1];
}

sub prev
{
	my( $self ) = @_;

	$self->{stage} = $self->get_prev_stage_id;
}

# only set new_stage if we're going there for real
# if an error stalls us then leave it undef.

sub update_from_form
{
	my( $self, $processor, $new_stage, $quiet ) = @_;
		
	# Process data from previous stage

	# If we don't have an item then something's
	# gone wrong.
	if( !defined $self->{item} )
	{
		$self->_corrupt_err;
		return( 0 );
	}

	if( !defined $self->{stages}->{$self->get_stage_id} )
	{
		# Not a valid stage
		$self->_corrupt_err;
		return( 0 );
	}
	
	my $stage_obj = $self->get_stage( $self->get_stage_id );

	$stage_obj->update_from_form( $processor );

	return if $quiet;

	# Deposit performs a full validation, so don't repeat any warnings here
	return if $new_stage eq 'deposit';

	my @problems = $stage_obj->validate( $processor );

	return 1 unless scalar @problems;
 
	my $warnings = $self->{handle}->make_element( "ul" );
	foreach my $problem_xhtml ( @problems )
	{
		my $li = $self->{handle}->make_element( "li" );
		$li->appendChild( $problem_xhtml );
		$warnings->appendChild( $li );
	}
	$self->link_problem_xhtml( $warnings, $processor->{screenid}, $new_stage );
	$processor->add_message( "warning", $warnings );

	return 0;
}


# return a fragement of a form.

sub render
{
	my ( $self) = @_;

#	if( $self->{handle}->get_repository->get_conf( 'log_submission_timing' ) )
#	{
#		if( $stage ne "meta" )
#		{
#			$self->log_submission_stage($stage);
#		}
#		# meta gets logged after pageid is worked out
#	}
	
	my $fragment = $self->{handle}->make_doc_fragment;
		
	my $hidden_fields = {
		stage => $self->get_stage_id,
	};

	foreach my $name ( keys %$hidden_fields )
	{
		$fragment->appendChild( $self->{handle}->render_hidden_field(
		$name,
		$hidden_fields->{$name} ) );
	}

	# Add the stage components

	my $stage_obj = $self->get_stage( $self->get_stage_id );
	my $stage_dom = $stage_obj->render( $self->{handle}, $self );

	$fragment->appendChild( $stage_dom );
	
	return $fragment;
}


######################################################################
# 
# $s_form->_corrupt_err
#
######################################################################

sub _corrupt_err
{
	my( $self ) = @_;

	$self->{handle}->render_error( 
		$self->{handle}->html_phrase( 
			"lib/submissionform:corrupt_err",
			line_no => 
				$self->{handle}->make_text( (caller())[2] ) ),
		$self->{handle}->get_repository->get_conf( "userhome" ) );

}

######################################################################
# 
# $s_form->_database_err
#
######################################################################

sub _database_err
{
	my( $self ) = @_;

	$self->{handle}->render_error( 
		$self->{handle}->html_phrase( 
			"lib/submissionform:database_err",
			line_no => 
				$self->{handle}->make_text( (caller())[2] ) ),
		$self->{handle}->get_repository->get_conf( "userhome" ) );
}

# return "&foo=bar"  style paramlist to add to url to maintain state

sub get_state_params
{
	my( $self, $processor ) = @_;

	my $stage = $self->get_stage( $self->get_stage_id );

	return "&stage=".$self->get_stage_id.$stage->get_state_params( $processor );
}

# add links to fields in problem-report xhtml chunks.
sub link_problem_xhtml
{
	my( $self, $node, $screenid, $new_stage ) = @_;

	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $class = $node->getAttribute( "class" );
		if( $class=~m/^ep_problem_field:(.*)$/ )
		{
			my $stage = $self->{field_stages}->{$1};
			return if( !defined $stage );
			my $keyfield = $self->{dataset}->get_key_field();
			my $kf_sql = $keyfield->get_sql_name;
			my $url = "?screen=$screenid&$kf_sql=".$self->{item}->get_id."&stage=$stage#$1";
			if( defined $new_stage && $new_stage eq $stage )
			{
				$url = "#$1";
			}
			
			my $newnode = $self->{handle}->render_link( $url );
			foreach my $kid ( $node->getChildNodes )
			{
				$node->removeChild( $kid );
				$newnode->appendChild( $kid );
			}
			$node->getParentNode->replaceChild( $newnode, $node ); 
			return;
		}

		foreach my $kid ( $node->getChildNodes )
		{
			$self->link_problem_xhtml( $kid, $screenid, $new_stage );
		}
	}


}





# static method to return all workflow documents for a single repository

sub load_all
{
	my( $path, $confhash ) = @_;

	my $dh;
	opendir( $dh, $path ) || die "Could not open $path";
	# This sorts the directory such that directories are last
	my @filenames = sort { -d "$path/$a" <=> -d "$path/$b" } readdir( $dh );
	foreach my $fn ( @filenames )
	{
		next if( $fn =~ m/^\./ );
		next if( $fn eq "CVS" );
		next if( $fn eq ".svn" );
		my $filename = "$path/$fn";
		if( -d $filename )
		{
			$confhash->{$fn} = {} if( !defined $confhash->{$fn} );
			load_all( $filename, $confhash->{$fn} );
			next;
		}
		if( $fn=~m/^(.*)\.xml$/ )
		{
			my $id = $1;
			load_workflow_file( $filename, $id, $confhash );
		}
	}
}

sub load_workflow_file
{
	my( $file, $id, $confhash ) = @_;

	my $doc = EPrints::XML::parse_xml( $file );
	$confhash->{$id}->{workflow} = $doc->documentElement();
	# assign id attributes to every component
	my $i = 1;
	foreach my $component ( $confhash->{$id}->{workflow}->getElementsByTagName( "component" ) )
	{
		next if $component->hasAttribute( "id" );
		$component->setAttribute( "id", "c".$i );
		++$i;
	}

	$confhash->{$id}->{file} = $file;
	$confhash->{$id}->{mtime} = EPrints::Utils::mtime( $file );
}

sub get_workflow_config
{
	my( $id, $confhash ) = @_;

	my $file = $confhash->{$id}->{file};

	my $mtime = EPrints::Utils::mtime( $file );

	if( $mtime > $confhash->{$id}->{mtime} )
	{
		load_workflow_file( $file, $id, $confhash );
	}

	return $confhash->{$id}->{workflow};
}


1;

######################################################################
=pod

=back

=cut

