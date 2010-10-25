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

=item $language = EPrints::Workflow->new( $session, $workflow_id, %params )

Create a new workflow object representing the specification given in
the workflow.xml configuration

# needs more config - about object etc.

=cut
######################################################################

sub new
{
	my( $class , $session, $workflow_id, %params ) = @_;

	my $self = {};

	bless $self, $class;
	
	$self->{repository} = $session->get_repository;
	$self->{session} = $session;
	$self->{dataset} = $params{item}->get_dataset;
	$self->{item} = $params{item};
	$self->{workflow_id} = $workflow_id;
	$self->{processor} = $params{processor};

	$params{session} = $session;
	$params{current_user} = $session->current_user;
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
		$self->{stage} = $self->{session}->param( "stage" );
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
	return if defined $new_stage && $new_stage eq 'deposit';

	my @problems = $stage_obj->validate( $processor );

	return 1 unless scalar @problems;
 
	my $warnings = $self->{session}->make_element( "ul" );
	foreach my $problem_xhtml ( @problems )
	{
		my $li = $self->{session}->make_element( "li" );
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

#	if( $self->{session}->get_repository->get_conf( 'log_submission_timing' ) )
#	{
#		if( $stage ne "meta" )
#		{
#			$self->log_submission_stage($stage);
#		}
#		# meta gets logged after pageid is worked out
#	}
	
	my $fragment = $self->{session}->make_doc_fragment;
		
	my $hidden_fields = {
		stage => $self->get_stage_id,
	};

	foreach my $name ( keys %$hidden_fields )
	{
		$fragment->appendChild( $self->{session}->render_hidden_field(
		$name,
		$hidden_fields->{$name} ) );
	}

	# Add the stage components

	my $stage_obj = $self->get_stage( $self->get_stage_id );
	my $stage_dom = $stage_obj->render( $self->{session}, $self );

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

	$self->{session}->render_error( 
		$self->{session}->html_phrase( 
			"lib/submissionform:corrupt_err",
			line_no => 
				$self->{session}->make_text( (caller())[2] ) ),
		$self->{session}->get_repository->get_conf( "userhome" ) );

}

######################################################################
# 
# $s_form->_database_err
#
######################################################################

sub _database_err
{
	my( $self ) = @_;

	$self->{session}->render_error( 
		$self->{session}->html_phrase( 
			"lib/submissionform:database_err",
			line_no => 
				$self->{session}->make_text( (caller())[2] ) ),
		$self->{session}->get_repository->get_conf( "userhome" ) );
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
		if( $class && $class=~m/^ep_problem_field:(.*)$/ )
		{
			my $stage = $self->{field_stages}->{$1};
			return if( !defined $stage );
			my $keyfield = $self->{dataset}->get_key_field();
			my $kf_sql = $keyfield->get_sql_name;
			my $url = URI->new( $self->{session}->current_url );
			$url->query_form(
				screen => $screenid,
				dataset => $self->{dataset}->id,
				dataobj => $self->{item}->id,
				$kf_sql => $self->{item}->id,
				stage => $stage
			);
			$url->fragment( $1 );
			if( defined $new_stage && $new_stage eq $stage )
			{
				$url = "#$1";
			}
			
			my $newnode = $self->{session}->render_link( $url );
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
	closedir( $dh );
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


sub _children_contain_class
{
	my ( $xml, $id, $ignor ) = @_;
	
	my $found = 0;
	foreach my $element ( $xml->getChildNodes ) {
		my $name = $element->nodeName();
		next if ($name eq $ignor);
		if ($element->hasAttributes) {
			my @attrs = $element->getAttributes();
			foreach my $at (@attrs) 
			{
				if ($at->getName() eq "required_by")
				{
					my $id_string = $at->getValue();
					my @ids = split(/ /,$id_string);
					foreach my $sids(@ids)
					{
						return 1 if ($sids eq $id);
					}
				}
			}
		}
		if ($found > 0) {
			return $found;
		}
		if ($element->hasChildNodes) 
		{
			$found = _children_contain_class($element,$id);
		}
		if ($found > 0) {
			return $found;
		}
	}

	return $found;

}

sub _remove_required_nodes
{
	my ( $xml, $id ) = @_;
	
	my $found = 0;
	foreach my $element ( $xml->getChildNodes ) {
		my $name = $element->nodeName();
		if ($element->hasAttributes) {
			my @attrs = $element->getAttributes();
			foreach my $at (@attrs) 
			{
				if ($at->getName() eq "required_by")
				{
					my $id_string = $at->getValue();
					my @ids = split(/ /,$id_string);
					my $flag = 1;
					my $out_ids;
					foreach my $sids(@ids)
					{
						if (!($sids eq $id)) 
						{
							$out_ids .= $sids . " ";	
							$flag = 0;
						}
					}
					if ($flag == 1) {
						$xml->removeChild($element);
					} else {
						$element->setAttribute("required_by",trim($out_ids));
					}
				}
			}
		}
		if ($element->hasChildNodes) 
		{
			$found = _remove_required_nodes($element,$id);
		}
	}

	return 0;

}

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub _remove_blank_nodes
{
	my ( $xml_handler, $node ) = @_;

	foreach my $element ( $node->getChildNodes ) {
	 	$node->removeChild($element);
		my $name = $element->nodeName();
		my $value = $element->nodeValue();
		unless (trim($name) eq "#text" && trim($value) eq "") {
			$node->addChild($element);
		}
		if ($element->hasChildNodes) 
		{
			$node->appendChild(_remove_blank_nodes($xml_handler,$element));
		}
	}
	
	return $node;

}

sub _children_contain_node
{
	my ( $xml_handler, $xml, $node, $id, $depth ) = @_;
	
	$xml = _remove_blank_nodes($xml_handler,$xml);
	$node = _remove_blank_nodes($xml_handler,$node);

	$depth++;
	foreach my $element ( $xml->getChildNodes ) {
		next unless ($element->nodeName eq $node->nodeName);
		next unless ($element->getAttribute("ref") eq $node->getAttribute("ref"));
		next unless ($element->getAttribute("test") eq $node->getAttribute("test"));
		next unless ($element->nodeValue eq $node->nodeValue);
		my @nodes = $node->childNodes();
		my $child_node_count = @nodes;
		@nodes = $element->childNodes();
		my $child_node_count2 = @nodes;
		return 0 unless ($child_node_count == $child_node_count2);
		my $good_children = 0;
		foreach my $child_node ( $node->getChildNodes ) {
			$good_children += _children_contain_node($xml_handler,$element,$child_node,$id,$depth);
		}
		return 0 unless ($good_children == $child_node_count);
		if ($depth == 1) {
			my $flag = 0;
			if ($element->hasAttribute("required_by")) {
				my $id_string = $element->getAttribute("required_by");
				my @ids = split(/ /,$id_string);
				foreach my $sids(@ids)
				{
					$flag = 1 if ($sids eq $id);
				}
				if ($flag < 1) 
				{
					$id_string .= " $id";
					$element->setAttribute("required_by",$id_string);
				}
			}
		}
		return 1;
	}

	return 0;
}

sub _remove_orphaned_chooses
{
	my ( $xml ) = @_;
	
	$xml = _remove_blank_nodes(undef,$xml);
	
	foreach my $element ( $xml->getChildNodes ) {
		my $name = $element->nodeName;
		my @preserve_nodes;
		if ($name eq "epc:choose") {
			if ($element->firstChild->nodeName eq "epc:otherwise")
			{
				foreach my $child ($element->firstChild->getChildNodes) 
				{
					$xml->appendChild($child);
				}
				$xml->removeChild($element);
			}
		}
		if ($element->hasChildNodes) 
		{
			_remove_orphaned_chooses($element);
		}
	}

	return 0;

}

sub _add_xml_to_workflow
{
	my ( $workflow, $node, $id, $depth ) = @_;
	
	my $ret = 0;

	foreach my $element ($workflow->getChildNodes())
	{
		next unless (defined $element->nodeName);
		next unless ($element->nodeName eq $node->nodeName);
		next unless ($element->getAttribute("name") eq $node->getAttribute("name"));
		next unless ($element->getAttribute("ref") eq $node->getAttribute("ref"));
		next unless ($element->getAttribute("test") eq $node->getAttribute("test"));
		next unless ($element->getAttribute("type") eq $node->getAttribute("type"));
		next unless ($element->nodeValue eq $node->nodeValue);
		$depth++;
		if (!$node->hasChildNodes) {
			if ($element->hasAttribute("required_by")) {
				my $id_string = $element->getAttribute("required_by");
				$id_string .= " $id";
				$element->setAttribute("required_by",$id_string);
				return 1;
			} else {
				return 2;
			}
		} 
		foreach my $child_node ( $node->getChildNodes ) {
			$ret = _add_xml_to_workflow($element,$child_node,$id,$depth);
			if ($ret == 2) {
				if ($element->hasAttribute("required_by")) {
					my $id_string = $element->getAttribute("required_by");
					$id_string .= " $id";
					$element->setAttribute("required_by",$id_string);
					return 1;
				} else {
					return 2;
				}
			}
		}
		
	}
	if ($ret == 2) {
		if ($node->hasAttribute("required_by")) {
			my $id_string = $node->getAttribute("required_by");
			$id_string .= " $id";
			$node->setAttribute("required_by",$id_string);
		} else {
			return 1;
		}
	}

	if ($depth > 0 and $ret < 1) {
		$node->setAttribute("required_by",$id);
		$workflow->addChild($node);
		return 1;
	}

	return $ret;
}

=item $repository->add_xml_to_workflow( $workflowid, $id, $xml )

Adds all the children $xml to the workflow

=cut

sub add_xml_to_workflow
{
	my( $repository, $workflowid, $id, $xml ) = @_;
	
	my $workflow = $repository->{workflows}->{$workflowid}->{default}->{workflow};
	
	my $xml_handler = EPrints::XML->new(
		$repository,
		doc=>$workflow->ownerDocument()
		);
	
	return 1 if (_children_contain_class($workflow,$id,"flow") > 0);

	my $ret;
	foreach my $element ( $xml->getChildNodes ) 
	{
		$ret = _add_xml_to_workflow($workflow,$element,$id,0);
		if (!$ret) {
			$element->setAttribute("required_by",$id);
			$workflow->appendChild($element);
		}
	}

	return _write_xml($repository,$workflowid,$workflow);
	
	return 0;

}

=item $repository->add_workflow_flow( $workflowid, $id, $types, $stages )

Add a flow to the workflow which is applicable for the types in types and contains the stages in stages. 

The $id is used to remove everything relating to this is from the workflow. 

=cut

sub add_workflow_flow
{
	my( $repository, $workflowid, $id, $types, $stages ) = @_;

	my $workflow = $repository->{workflows}->{$workflowid}->{default}->{workflow};
	
	my $flow = ($workflow->getElementsByTagName("flow"))[0];
	if(!defined $flow)
	{
		return 1;
	} 
	
	return 1 if (_children_contain_class($flow,$id));
	
        my $xml_handler = EPrints::XML->new(
		$repository,
		doc=>$workflow->ownerDocument()
		);
	
	my $test = "type";
	if (!(ref($types) eq 'ARRAY')) 
	{
		$test .= "='".$types."'";	
	}
	else
	{
		$test .= ".one_of(";
		foreach my $type(@{$types}) 
		{
			$test .= "'$type',";
		}
		$test = substr $test, 0,-1;
		$test .=')';
	}
	
	my $stages_dom = $xml_handler->create_document_fragment;
	if (!(ref($stages) eq 'ARRAY')) 
	{
		my $stage_node = $xml_handler->create_element("stage",ref=>"$stages");
		$stages_dom->appendChild($stage_node);
	}
	else
	{
		foreach my $stage(@{$stages}) 
		{
			my $stage_node = $xml_handler->create_element("stage",ref=>"$stage");
			$stages_dom->appendChild($stage_node);
		}
	}

	my $count = 0;
	my $replace = 0;
	my $when_node = $xml_handler->create_element("epc:when",test=>$test,required_by=>$id);
	$when_node->appendChild($stages_dom);
	
	my $choose_node = $xml_handler->create_element("epc:choose");
	my $otherwise_node = $xml_handler->create_element("epc:otherwise");
	
	foreach my $element ( $flow->getChildNodes ) {
		my $name = $element->nodeName;
		if ($name eq "stage" && $count < 1) {
			$flow->appendChild($choose_node);
			$choose_node->appendChild($when_node);
			$choose_node->appendChild($otherwise_node);
			$replace = 1;
			$count++;
		} elsif ($name eq "epc:choose" && $count < 1) {
			unless (_children_contain_node($xml_handler,$element,$when_node,$id,0)) 
			{
				$count++;
				my $blank_node = $xml_handler->create_document_fragment;
				$blank_node->appendChild($when_node);
				foreach my $sub_node ( $element->getChildNodes ) {
					$blank_node->appendChild($sub_node);
					$element->removeChild($sub_node);
				}
				$element->appendChild($blank_node);
			}
		}
		if ($replace) {
			$flow->removeChild($element);
			$otherwise_node->appendChild($element);
		}
	}
	
	return _write_xml($repository,$workflowid,$workflow);

}

=item $repository->remove_required_workflow( $workflowid, $id )

=cut

sub remove_required_workflow
{
	my( $repository, $workflowid, $id ) = @_;
	
	my $workflow = $repository->{workflows}->{$workflowid}->{default}->{workflow};

	my $ret = _remove_required_nodes($workflow,$id);
	$ret = _remove_orphaned_chooses($workflow);
	
	return _write_xml($repository,$workflowid,$workflow);

}

sub _write_xml 
{
	my( $repository, $workflowid, $workflow ) = @_;
	
	my $dir = $repository->config( "config_path" )."/workflows/$workflowid/";

	my $path = $dir . "default.xml";

	EPrints->system->mkdir( $dir );
	
	$workflow = _remove_blank_nodes(undef,$workflow);

	my $xml_string = $workflow->toString();

	use XML::Twig;
	use XML::Parser;
	my $xml = XML::Twig->new(pretty_print => 'indented');
	$xml->parse($xml_string);
	$workflow = $xml;

	open(my $fh, ">", $path)
		or return 0;
	
	print $fh '<?xml version="1.0" encoding="utf-8"?>' . "\n\n";
	print $fh $workflow->toString();

	close($fh);

	return 0;
}

1;

######################################################################
=pod

=back

=cut

