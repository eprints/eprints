=head1 NAME

EPrints::Plugin::Screen::EPrint::Staff::Reindex

=cut

package EPrints::Plugin::Screen::EPrint::Staff::Reindex;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	#	$self->{priv} = # no specific priv - one per action

	$self->{actions} = [qw/ reindex /];

	$self->{appears} = [ {
		place => "eprint_editor_actions",
		action => "reindex",
		position => 1850,
	}, ];

	return $self;
}

sub obtain_lock
{
	my( $self ) = @_;

	return $self->could_obtain_eprint_lock;
}

sub about_to_render 
{
	my( $self ) = @_;

	$self->EPrints::Plugin::Screen::EPrint::View::about_to_render;
}

sub allow_reindex
{
	my( $self ) = @_;

	return 0 unless $self->could_obtain_eprint_lock;
	return $self->allow( "eprint/edit:editor" );
}
sub action_reindex
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $eprint = $self->{processor}->{eprint};

	$eprint->queue_all();

	# Remove all document index files to force re-texting them
	foreach my $doc ($eprint->get_all_documents())
	{
		$doc->remove_indexcodes();
	}

	# Redo the fulltext-index
	$eprint->queue_fulltext();

	$self->add_result_message( 1 );
}

sub add_result_message
{
	my( $self, $ok ) = @_;

	if( $ok )
	{
		$self->{processor}->add_message( "message",
			$self->html_phrase( "reindexing" ) );
	}
	else
	{
		# Error?
		$self->{processor}->add_message( "error" );
	}

	$self->{processor}->{screenid} = "EPrint::View";
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

