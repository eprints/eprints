=head1 NAME

EPrints::Plugin::Screen::DataSets

=cut

package EPrints::Plugin::Screen::DataSets;

use EPrints::Plugin::Screen;
@ISA = qw( EPrints::Plugin::Screen );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "key_tools",
			position => 150,
		}
	];

	$self->{actions} = [qw/ /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "datasets" );
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{session};
	my $xml = $repo->xml;
	my $user = $repo->current_user;
	my $imagesurl = $repo->config( "rel_path" )."/style/images";
	my @datasets = $self->datasets;

	my $html = $xml->create_document_fragment;

	if( $repo->get_lang->has_phrase( $self->html_phrase_id( "intro" ), $repo ) )
	{
		my $intro_div_outer = $xml->create_element( "div", class => "ep_toolbox" );
		my $intro_div = $xml->create_element( "div", class => "ep_toolbox_content" );
		$intro_div->appendChild( $self->html_phrase( "intro" ) );
		$intro_div_outer->appendChild( $intro_div );
		$html->appendChild( $intro_div_outer );
	}

	my $table = $xml->create_element( "table" );
	$html->appendChild( $table );

	foreach my $dataset (@datasets)
	{
		my $link = $xml->create_element( "a", href => $self->listing( $dataset ) );
		$link->appendChild( $dataset->render_name( $repo ) );
		$table->appendChild( $repo->render_row(
			$link,
			$repo->html_phrase( "datasethelp_".$dataset->id ) ) );
	}

	return $html;
}

sub datasets
{
	my( $self ) = @_;

	return @{$self->{processor}->{datasets}}
		if defined $self->{processor}->{datasets};

	my @datasets;
	
	foreach my $datasetid ($self->{session}->get_dataset_ids)
	{
		my $dataset = $self->{session}->dataset( $datasetid );
		push @datasets, $dataset
			if
				$self->allow( $dataset->id . "/view" ) ||
				$self->allow( $dataset->id . "/view:owner" ) ||
				$self->allow( $dataset->id . "/view:editor" );
	}

	@datasets = sort { $a->base_id cmp $b->base_id || $a->id cmp $b->id } @datasets;

	$self->{processor}->{datasets} = \@datasets;

	return @datasets;
}

sub listing
{
	my( $self, $dataset ) = @_;

	my $url = URI->new( $self->{session}->current_url() );
	$url->query_form(
		screen => "Listing",
		dataset => $dataset->base_id
		);

	return $url;
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

