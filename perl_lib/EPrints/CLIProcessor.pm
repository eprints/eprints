######################################################################
#
# EPrints::CLIProcessor
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

=head1 NAME

EPrints::CLIProcessor - utility module supporting command-line scripts

=head1 DESCRIPTION

Currently this module is just a 'handler' for import scripts. In future it may do more things to support the CLI (Command-Line Interface) to EPrints.

=head1 METHODS

=over 4

=cut

package EPrints::CLIProcessor;

use strict;

use vars qw( %COLORS );

eval "use Term::ANSIColor qw()";
unless( $@ )
{
	%COLORS = (
		reset => "reset",
		error => "bold red",
		warning => "bold yellow",
	);
}

sub color
{
	my( $type ) = @_;

	return exists $COLORS{$type} ? Term::ANSIColor::color( $COLORS{$type} ) : "";
}

=item $processor = EPrints::CLIProcessor->new( handle => $handle, %opts )

Create a new processor object. Supported options:

  scripted - backwards compatibility for import scripted interface

=cut

sub new
{
    my( $class, %self ) = @_;

    $self{wrote} = 0;
    $self{parsed} = 0;
	$self{ids} = [];

    bless \%self, $class;
}

=item $processor->add_message( TYPE, MESSAGE )

Add a message for the user. TYPE is 'error', 'warning' or 'message'. MESSAGE is an XHTML fragment.

=cut

*add_message = \&message;
sub message
{
    my( $self, $type, $msg ) = @_;

	print STDERR color($type);
	$msg = EPrints::Utils::tree_to_utf8( $msg );
	print STDERR "\u$type! $msg\n";
	print STDERR color('reset');
}

=item $processor->parsed( [ $epdata ] )

Register a parsed event, optionally with $epdata.

=cut

sub parsed
{
    my( $self, $epdata ) = @_;

    $self->{parsed}++;

	if( $self->{scripted} )
	{
		print "EPRINTS_IMPORT: ITEM_PARSED\n";
	}
}

=item $processor->object( DATASET, DATAOBJ )

Register a new object event in DATASET with new object DATAOBJ.

=cut

sub object
{
    my( $self, $dataset, $dataobj ) = @_;

    $self->{wrote}++;

	push @{$self->{ids}}, $dataobj->get_id;

	if( $self->{handle}->get_noise > 1 )
	{
		print STDERR "Imported ".$dataset->id." ".$dataobj->get_id."\n";
	}

	if( $self->{scripted} )
	{
		print "EPRINTS_IMPORT: ITEM_IMPORTED ".$dataobj->get_id."\n";
	}
}

1;
