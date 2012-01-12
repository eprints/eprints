=head1 NAME

EPrints::Plugin::Issues::ExactTitleDups

=cut

package EPrints::Plugin::Issues::ExactTitleDups;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Issues" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Exact title duplicates";
	$self->{accept} = [qw( list/eprint )];

	return $self;
}

sub process_dataobj
{
	my( $self, $eprint, %opts ) = @_;

	my $title = $eprint->value( "title" );
	return if !defined $title;

	push @{$self->{titles}->{$title}}, $eprint->id;
}

sub finish
{
	my( $self, %opts ) = @_;

	my $repo = $self->{session};

	foreach my $set (values %{$self->{titles}})
	{
		next if @$set == 1;
		foreach my $item (@$set)
		{
			$item = $repo->eprint( $item );
		}
		foreach my $item (@$set)
		{
			foreach my $dupe (@$set)
			{
				next if $item->id eq $dupe->id;
				my $desc = $self->html_phrase( "duplicate",
						duplicate => $dupe->render_citation_link_staff( 'brief' ),
					);
				$self->create_issue( $item, {
					type => $self->get_subtype,
					description => $repo->xhtml->to_xhtml( $desc ),
				});
			}
		}
		@$set = (); # free objects
	}

	delete $self->{titles};
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

