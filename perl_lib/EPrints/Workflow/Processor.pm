######################################################################
#
# EPrints::Workflow::Processor
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

B<EPrints::Workflow::Processor> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

package EPrints::Workflow::Processor;

use EPrints;

use strict;

######################################################################
=pod

=item $thing = EPrints::WorkflowProc->new( $handle, $redirect, $staff, $dataset, $formtarget )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $handle, $workflow_id ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{handle} = $handle;

	# Use user configured order for stages or...
	# $self->{workflow} = $handle->get_repository->get_workflow( $workflow_id );

	return( $self );
}

sub _pre_process
{
	my( $self ) = @_;

	$self->{action}    = $self->{handle}->get_action_button();
	$self->{stage}     = $self->{handle}->param( "stage" );

	print STDERR $self->{action}."\n";

	if( $self->{action} eq "next" )
	{
		$self->{stage} = $self->{workflow}->get_next_stage( $self->{stage} );
	}
	elsif( $self->{action} eq "prev" )
	{
		$self->{stage} = $self->{workflow}->get_prev_stage( $self->{stage} );
	}

	$self->{eprintid}  = $self->{handle}->param( "eprintid" );
	$self->{user}      = $self->{handle}->current_user();
	
	print STDERR $self->{stage}."\n";

}

######################################################################
=pod

=item $foo = $thing->render

undocumented

=cut
######################################################################

sub render
{
	my( $self, $stage ) = @_;
	
	my $arc = $self->{handle}->get_repository;
	$self->{dataset} = $arc->get_dataset( "archive" );
	$self->{workflow} = $arc->{workflow};

	$self->_pre_process();
	
	if( !defined $self->{stage} )
	{
		$self->{stage} = $self->{workflow}->get_first_stage();
	}
	elsif( defined $stage )
	{
		$self->{stage} = $stage;
	}


	$self->{eprintid} = 100;

	$self->{eprint} = $self->{dataset}->get_object( $self->{eprintid} );

	my $curr_stage = $self->{workflow}->get_stage($self->{stage});
	$self->{handle}->prepare_page(
		{
			title=>$self->{handle}->html_phrase(
				"lib/submissionform:title_meta",
				type => $self->{eprint}->render_value( "type" ),
				eprintid => $self->{eprint}->render_value( "eprintid" ),
				desc => $self->{eprint}->render_description ),
			page=>$curr_stage->render( $self->{handle}, $arc->{workflow}, $self->{eprint} ), 
		},
		page_id=>"submission_metadata" );

	$self->{handle}->send_page();

	return( 1 );
}

sub DESTROY
{
	my( $self ) = @_;

	EPrints::Utils::destroy( $self );
}

1;

######################################################################
=pod

=back

=cut
