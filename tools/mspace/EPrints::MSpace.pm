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
	my $eprintid = $eprint->get_id;
	my $db = $session->get_database;

	FIELD: foreach my $field ( $dataset->get_fields )
	{
		next if $field->is_virtual;

		my $table_name = "mspace_".$field->{name};
 		next FIELD if !$eprint->is_set( $field->get_name );
		my $v = $eprint->get_value( $field->get_name );
		my $add_fn = \&EPrints::MSpace::add_row;
		if( $field->is_type( "date", "time") )
		{
			$add_fn = \&EPrints::MSpace::add_date_rows;
		}
		if( $field->get_property( "multiple" ) )
		{
			foreach my $s ( @{$v} )
			{
				&{$add_fn}( $db, $table_name, $eprintid, $s, $eprint, $field );
			}	
		}
		else
		{
			&{$add_fn}( $db, $table_name, $eprintid, $v, $eprint, $field );
		}
	}

	my $citation = EPrints::XML::to_string( $eprint->render_citation_link, "utf-8", 1 );
	my $short = EPrints::Utils::tree_to_utf8( $eprint->render_citation('brief') );
	my $url = $eprint->get_url;
	$db->insert( 'mspace_citation', ['eprintid','citation','short','url'], [$eprintid,$citation,$short,$url] );

	my @docs = $eprint->get_all_documents;
	foreach my $doc ( @docs )
	{
		my @k = ();
		my @v = ();

		push @k, "eprintid";
		push @v, $eprintid;
	
		push @k, "documentid";
		push @v, $doc->get_id;
		
		push @k, "formatid";
		push @v, $doc->get_value( "format" );
		
		push @k, "formatdesc";
		push @v, EPrints::Utils::tree_to_utf8( $doc->render_value( "format" ) );
		
		push @k, "contentid";
		push @v, $doc->get_value( "content" );
		
		push @k, "contentdesc";
		push @v, EPrints::Utils::tree_to_utf8( $doc->render_value( "content" ) );
		
		push @k, "url";
		push @v, $doc->get_url;
		
		push @k, "iconurl";
		push @v, $doc->icon_url;
	
		$db->insert( 'mspace_documents', \@k, \@v );
	}


}

sub add_date_rows
{
	my( $db, $table_name, $eprintid, $value, $eprint, $field ) = @_;

	add_row( $db, $table_name, $eprintid, $value, $eprint, $field );
	add_row( $db, $table_name."_day", $eprintid, substr( $value, 0, 10 ), $eprint, $field );
	add_row( $db, $table_name."_month", $eprintid, substr( $value, 0, 6 ), $eprint, $field );
	add_row( $db, $table_name."_year", $eprintid, substr( $value, 0, 4 ), $eprint, $field );
	my $decade = substr( $value, 0, 3 )."0s";
	$db->insert( $table_name."_decade", ['eprintid','value','desc'], [$eprintid,$decade,$decade] );
}


sub add_row
{
	my( $db, $table_name, $eprintid, $value, $eprint, $field ) = @_;

	my $session = $eprint->get_session;
	my $desc_xml = $field->render_value_no_multiple( $session, $value, 0, 1, $eprint );
	my $vid = $field->get_id_from_value( $session, $value );

	my $desc = EPrints::Utils::tree_to_utf8( $desc_xml );

	$db->insert( $table_name, ['eprintid','value','desc'], [$eprintid,$vid,$desc] );
}

sub remove_eprint
{
	my( $eprint ) = @_;

	my $session = $eprint->get_session;
	my $dataset = $eprint->get_dataset;
	my $eprintid = $eprint->get_id;
	my $db = $session->get_database;

	FIELD: foreach my $field ( $dataset->get_fields )
	{
		next if $field->is_virtual;

		my $table_name = "mspace_".$field->{name};
		$db->delete_from( $table_name, ['eprintid'], [$eprintid] );
		if( $field->is_type( "date", "time" ) )
		{
			$db->delete_from( $table_name."_day", ['eprintid'], [$eprintid] );
			$db->delete_from( $table_name."_month", ['eprintid'], [$eprintid] );
			$db->delete_from( $table_name."_year", ['eprintid'], [$eprintid] );
			$db->delete_from( $table_name."_decade", ['eprintid'], [$eprintid] );
		}
		
	}
	$db->delete_from( 'mspace_citation', ['eprintid'], [$eprintid] );
	$db->delete_from( 'mspace_documents', ['eprintid'], [$eprintid] );
}

1;
