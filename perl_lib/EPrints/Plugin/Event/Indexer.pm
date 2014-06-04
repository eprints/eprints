=head1 NAME

EPrints::Plugin::Event::Indexer

=cut

package EPrints::Plugin::Event::Indexer;

@ISA = qw( EPrints::Plugin::Event );

use strict;

sub index
{
	my( $self, $dataobj, @fieldnames ) = @_;

	return if !defined $dataobj;
	my $dataset = $dataobj->get_dataset;

	my @fields;
	for(@fieldnames)
	{
		next unless $dataset->has_field( $_ );
		push @fields, $dataset->get_field( $_ );
	}

	return $self->_index_fields( $dataobj, \@fields );
}

sub index_all
{
	my( $self, $dataobj ) = @_;

	return if !defined $dataobj;
	my $dataset = $dataobj->get_dataset;

	return $self->_index_fields( $dataobj, [$dataset->get_fields] );
}

sub removed
{
	my( $self, $datasetid, $id ) = @_;

	my $dataset = $self->{session}->dataset( $datasetid );
	return if !defined $dataset;

	my $rc = $self->{session}->run_trigger( EPrints::Const::EP_TRIGGER_INDEX_REMOVED,
		dataset => $dataset,
		id => $id,
	);
	return if defined $rc && $rc eq EPrints::Const::EP_TRIGGER_DONE;

	return;
}

sub _index_fields
{
	my( $self, $dataobj, $fields ) = @_;

	my $session = $self->{session};
	my $dataset = $dataobj->get_dataset;

	my $rc = $session->run_trigger( EPrints::Const::EP_TRIGGER_INDEX_FIELDS,
		dataobj => $dataobj,
		fields => $fields,
	);
	return if defined $rc && $rc eq EPrints::Const::EP_TRIGGER_DONE;

	return;
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

