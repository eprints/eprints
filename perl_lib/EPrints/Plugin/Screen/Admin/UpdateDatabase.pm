=head1 NAME

EPrints::Plugin::Screen::Admin::UpdateDatabase

=cut

package EPrints::Plugin::Screen::Admin::UpdateDatabase;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ update /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions_config", 
			position => 1248, 
			action => "update",
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/edit/perl" );
}
sub allow_action { shift->can_be_viewed }

sub action_update
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	$self->{processor}->{screenid} = "Admin";

	# force a config (re)load
	my $plugin = $repo->plugin( "Screen::Admin::Reload",
		processor => $self->{processor},
	);
	return if !$plugin->action_reload_config();

	$self->update_datasets;
	$self->update_counters;
}

sub update_datasets
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $db = $repo->database;
	my $processor = $self->{processor};

	my %changes;

	foreach my $datasetid ($repo->get_sql_dataset_ids)
	{
		my $dataset = $repo->dataset( $datasetid );
		if( !$db->has_dataset( $dataset ) )
		{
			if( $db->create_dataset_tables( $dataset ) )
			{
				push @{$changes{dataset}}, $dataset;
			}
			else
			{
				$processor->add_message( "error", $self->html_phrase( "error:dataset",
					dataset => $repo->xml->create_text_node( $datasetid )
				) );
			}
		}
		foreach my $field ($dataset->fields)
		{
			next if defined $field->property( "sub_name" );
			next if $db->has_field( $dataset, $field );
			if( $db->add_field( $dataset, $field ) )
			{
				push @{$changes{field}}, $field;

				$self->migrate_to_multiple_values( $field );
			}
			else
			{
				$processor->add_message( "error", $self->html_phrase( "error:field",
					dataset => $repo->xml->create_text_node( $datasetid ),
					field => $repo->xml->create_text_node( $field->name ),
				) );
			}
		}
	}

	if( %changes )
	{
		$processor->add_message( "message", $self->html_phrase( "updated",
			datasets => $repo->xml->create_text_node( join ', ', map { $_->id } @{$changes{dataset}||[]} ),
			fields => $repo->xml->create_text_node( join ', ', map { $_->name } @{$changes{field}||[]} ),
		) );
	}
	else
	{
		$processor->add_message( "warning", $self->html_phrase( "nochanges" ) );
	}
}

sub update_counters
{
	my( $self ) = @_;
}

sub migrate_to_multiple_values
{
	my( $self, $field ) = @_;

	my $repo = $self->{repository};
	my $db = $repo->database;
	my $processor = $self->{processor};
	my $dataset = $field->dataset;

	# nothing to copy to
	return if !$field->property( "multiple" );

	my $main_table = $dataset->get_sql_table_name;

	my @fields;
	if( $field->isa( "EPrints::MetaField::Compound" ) )
	{
		push @fields, @{ $field->property( "fields_cache" ) };
	}
	elsif( $field->is_virtual )
	{
		return; # odd ?
	}
	else
	{
		push @fields, $field;
	}

	my $rc = 0;

	my $Q_key_col = $db->quote_identifier( $dataset->key_field->get_sql_name );
	my $Q_pos = $db->quote_identifier( "pos" );
	foreach my $field ( @fields )
	{
		# nothing to copy from
		next if !$db->has_column( $main_table, $field->get_sql_name );

		my $table = $dataset->get_sql_sub_table_name( $field );
		my @Q_cols = map { $db->quote_identifier( $_ ) } $field->get_sql_names; # e.g. name parts
		my $sql =
			"INSERT INTO ".$db->quote_identifier( $table ).
			" (".join(',', $Q_key_col, $Q_pos, @Q_cols).")".
			" SELECT ".join(',', $Q_key_col, 0, @Q_cols).
			" FROM ".$db->quote_identifier( $main_table );
		$rc |= $db->do( $sql );
	}

	$processor->add_message( "message", $self->html_phrase( "migrated",
		dataset => $repo->xml->create_text_node( $dataset->id ),
		field => $repo->xml->create_text_node( $field->name ),
	) ) if $rc;
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

=cut
