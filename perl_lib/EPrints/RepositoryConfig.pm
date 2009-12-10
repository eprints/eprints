######################################################################
#
# EPrints::RepositoryConfig
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::RepositoryConfig> - Repository Configuration

=head1 DESCRIPTION

This provides methods for reading and setting a repository configuration.
Setter methods may only be used in the configuration.

=head1 METHODS

=head2 Setter Methods

=over 4

=cut

package EPrints::RepositoryConfig;

use warnings;
use strict;

=pod

=item $c->add_trigger( $event_id, $fn, [$priority] )

Register a new trigger to occur when a certain event happens.

$priority can be used to cause this trigger to happen early or later than other tirggers on the same event. 0 is default. -100 is very early. 100 is very late. 

=cut

sub add_trigger
{
	my( $self, $event_id, $fn, $priority ) = @_;

	if( $self->read_only ) { EPrints::abort( "Configuration is read-only." ); }

	if( !defined $priority ) { $priority = 0; }

	push @{$self->{triggers}->{$event_id}->{$priority}}, $fn;
}

=pod

=back

=cut 

# Non advertised methods!

sub set_read_only
{
	my( $self ) = @_;
	$self->{".read_only"} = 1;	
}

sub unset_read_only
{
	my( $self ) = @_;
	$self->{".read_only"} = 0;	
}

sub read_only
{
	my( $self ) = @_;

	return( defined $self->{".read_only"} && $self->{".read_only"} );
}

1;
