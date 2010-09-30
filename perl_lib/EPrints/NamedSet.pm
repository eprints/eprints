######################################################################
#
# EPrints::NamedSet
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2010 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::NamedSet> - Repository Configuration

=head1 SYNOPSIS

	$namedset = EPrints::NamedSet->new( "eprint",
		repository => $repository
	);
	
	$namedset->add_option( "performance" );
	$namedset->remove_option( "thesis" );
	
	$namedset->write;

=head1 DESCRIPTION

A utility class to manipulate named sets. 

=head1 METHODS

=over 4

=cut

package EPrints::NamedSet;

use strict;

=item $namedset = EPrints::NamedSet->new( $id, %opts )

=cut

sub new
{
	my( $class, $id, %self ) = @_;

	$self{id} = $id;
	@{$self{options}} = $self{repository}->get_types( $id );

	my $self = bless \%self, $class;

	return $self;
}

=item $namedset->add_option( $option [, $index ] )

Add an option to the named set.

=cut

sub add_option
{
	my( $self, $option, $index ) = @_;

	for(@{$self->{options}})
	{
		return if $_ eq $option;
	}

	if( @_ == 2 )
	{
		push @{$self->{options}}, $option;
	}
	else
	{
		splice(@{$self->{options}}, $index, 0, $option);
	}
}

=item $namedset->remove_option( $option )

Remove an option from the named set.

=cut

sub remove_option
{
	my( $self, $option ) = @_;

	@{$self->{options}} = grep { $_ ne $option } @{$self->{options}};
}

=item $ok = $namedset->write

Writes the current options list to the named set.

=cut

sub write
{
	my( $self ) = @_;

	my $dir = $self->{repository}->config( "config_path" )."/namedsets";

	my $path = $dir . "/" . $self->{id};
        
	EPrints->system->mkdir( $dir );

	open(my $fh, ">", $path)
		or return 0;
	print $fh map { "$_\n" } @{$self->{options}};
	close($fh);

	return 1;
}

=item $ok = $namedset->remove

Remove the namedset from the file system.

=cut

sub remove
{
	my( $self ) = @_;

	my $dir = $self->{repository}->config( "config_path" )."/namedsets";

	my $path = $dir . "/" . $self->{id};
        
	return unlink( $path );
}

1;
