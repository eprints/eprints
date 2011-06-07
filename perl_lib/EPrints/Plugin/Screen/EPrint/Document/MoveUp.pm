=head1 NAME

EPrints::Plugin::Screen::EPrint::Document::MoveUp

=cut

package EPrints::Plugin::Screen::EPrint::Document::MoveUp;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint::Document' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_up.png";

	$self->{appears} = [
		{
			place => "document_item_actions",
			position => 1000,
		},
	];
	
	$self->{actions} = [qw//];

	$self->{ajax} = "automatic";

	return $self;
}

sub from
{
	my( $self ) = @_;

	my $eprint = $self->{processor}->{eprint};
	my $doc = $self->{processor}->{document};
	my @docs = $eprint->get_all_documents;

	if( $doc )
	{
		my $i;
		for($i = 0; $i < @docs; ++$i)
		{
			last if $doc->id == $docs[$i]->id;
		}
		if( $i == 0 )
		{
			my $t = $docs[$#docs]->value( "placement" );
			for($i = $#docs; $i > 0; --$i)
			{
				$docs[$i]->set_value( "placement",
					$docs[$i-1]->value( "placement" ) );
			}
			$docs[0]->set_value( "placement", $t );
			$_->commit for @docs;
			return;
		}
		my( $left, $right ) = @docs[($i-1)%@docs, $i];
		my $t = $left->value( "placement" );
		$left->set_value( "placement", $right->value( "placement" ) );
		$right->set_value( "placement", $t );
		$left->commit;
		$right->commit;
		push @{$self->{processor}->{docids}},
			$left->id,
			$right->id;
	}

	$self->{processor}->{redirect} = $self->{processor}->{return_to};
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

