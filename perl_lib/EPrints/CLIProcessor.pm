######################################################################
#
# EPrints::CLIProcessor
#
######################################################################
#
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

=item $processor = EPrints::CLIProcessor->new( session => $session, %opts )

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

	if( $self->{session}->get_noise > 1 )
	{
		print STDERR "Imported ".$dataset->id." ".$dataobj->get_id."\n";
	}

	if( $self->{scripted} )
	{
		print "EPRINTS_IMPORT: ITEM_IMPORTED ".$dataobj->get_id."\n";
	}
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

