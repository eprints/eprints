######################################################################
#
# EPrints::Workflow::Processor
#
######################################################################
#
#  This file is part of GNU EPrints 2.
#  
#  Copyright (c) 2000-2004 University of Southampton, UK. SO17 1BJ.
#  
#  EPrints 2 is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  EPrints 2 is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with EPrints 2; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
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

######################################################################
#
#  EPrints Submission uploading/editing forms
#
######################################################################
#
#  This file is part of GNU EPrints 2.
#  
#  Copyright (c) 2000-2004 University of Southampton, UK. SO17 1BJ.
#  
#  EPrints 2 is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  EPrints 2 is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with EPrints 2; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
######################################################################

package EPrints::Workflow::Processor;

use EPrints;

use Unicode::String qw(utf8 latin1);
use strict;

######################################################################
=pod

=item $thing = EPrints::WorkflowProc->new( $session, $redirect, $staff, $dataset, $formtarget )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $session, $workflow_id ) = @_;

	my $self = {};
	bless $self, $class;

	$self->{session} = $session;

	# Use user configured order for stages or...
	# $self->{workflow} = $session->get_repository->get_workflow( $workflow_id );

	return( $self );
}

sub _pre_process
{
	my( $self ) = @_;

	$self->{action}    = $self->{session}->get_action_button();
	$self->{stage}     = $self->{session}->param( "stage" );

	print STDERR $self->{action}."\n";

	if( $self->{action} eq "next" )
	{
		$self->{stage} = $self->{workflow}->get_next_stage( $self->{stage} );
	}
	elsif( $self->{action} eq "prev" )
	{
		$self->{stage} = $self->{workflow}->get_prev_stage( $self->{stage} );
	}

	$self->{eprintid}  = $self->{session}->param( "eprintid" );
	$self->{user}      = $self->{session}->current_user();
	
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
	
	my $arc = $self->{session}->get_repository;
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

	$self->{eprint} = EPrints::DataObj::EPrint->new(
	$self->{session},
	$self->{eprintid},
	$self->{dataset} );

	my $curr_stage = $self->{workflow}->get_stage($self->{stage});
	$self->{session}->build_page(
		$self->{session}->html_phrase(
		"lib/submissionform:title_meta",
		type => $self->{eprint}->render_value( "type" ),
		eprintid => $self->{eprint}->render_value( "eprintid" ),
		desc => $self->{eprint}->render_description ),
		$curr_stage->render( $self->{session}, $arc->{workflow}, $self->{eprint} ), 
		"submission_metadata" );

	$self->{session}->send_page();

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
