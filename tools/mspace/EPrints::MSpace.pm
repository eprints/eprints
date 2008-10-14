#!/usr/bin/perl -w -I/opt/eprints3/perl_lib 

package EPrints::MSpace;

use EPrints;
use EPrints::Database;

use strict;

sub add_eprint
{
	my( $eprint ) = @_;

	my $session = $eprint->get_session;
	my $dataset = $eprint->get_dataset;
	my $id = $eprint->get_id;
	my $db = $session->get_database;

	FIELD: foreach my $field ( $dataset->get_fields )
	{
		next if $field->is_virtual;

		my $table_name = "mspace_".$field->{name};
 		next FIELD if !$eprint->is_set( $field->get_name );
		my $v = $eprint->get_value( $field->get_name );
		if( $field->get_property( "multiple" ) )
		{
			foreach my $s ( @{$v} )
			{
				my $desc = $field->render_value_no_multiple( $session, $s, 0, 1, $eprint );
				my $vid = $field->get_id_from_value( $session, $s );
				EPrints::MSpace::add_row( $db, $table_name, $id, $vid, $desc );
			}	
		}
		else
		{
			my $desc = $field->render_value_no_multiple( $session, $v, 0, 1, $eprint );
			my $vid = $field->get_id_from_value( $session, $v );
			EPrints::MSpace::add_row( $db, $table_name, $id, $vid, $desc );
		}
	}

	my $citation = EPrints::XML::to_string( $eprint->render_citation_link, "utf-8", 1 );
	$db->insert( 'mspace_citation', ['eprintid','citation'], [$id,$citation] );
}

sub add_row
{
	my( $db, $table_name, $id, $value, $rendered_xml ) = @_;

	my $desc = EPrints::XML::to_string( $rendered_xml, "utf-8", 1 );

	$db->insert( $table_name, ['eprintid','value','desc'], [$id,$value,$desc] );
}

sub remove_eprint
{
	my( $eprint ) = @_;

	my $session = $eprint->get_session;
	my $dataset = $eprint->get_dataset;
	my $id = $eprint->get_id;
	my $db = $session->get_database;

	FIELD: foreach my $field ( $dataset->get_fields )
	{
		next if $field->is_virtual;

		my $table_name = "mspace_".$field->{name};
		$db->delete_from( $table_name, ['eprintid'], [$id] )
	}
	$db->delete_from( 'mspace_citation', ['eprintid'], [$id] )
}

1;
