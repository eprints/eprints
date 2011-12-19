#!/usr/bin/perl

use FindBin;
use encoding 'utf8';

use lib "$FindBin::Bin/../perl_lib";

use EPrints;

die "Usage: $0 [archiveid] [datasetid]\n" if @ARGV != 2;

my $repo = EPrints->repository( $ARGV[0] );
my $dataset = $repo->dataset( $ARGV[1] );
my $db = $repo->database;

&csv(
	"Source",
	"ID",
	"type",
	"Volatile",
	"Name",
	"Description",
	"Records",
);

foreach my $field (sort { $a->name cmp $b->name } $dataset->fields)
{
	next if $field->property( "sub_name" );
	next if $field->isa( "EPrints::MetaField::Subobject" );
	my @row;
	push @row, $field->has_property( "provenance" ) ?
		$field->property( "provenance" ) :
		"N/A";
	push @row, $field->name;
	push @row, $field->type;
	if( $field->isa( "EPrints::MetaField::Compound" ) )
	{
		$row[-1] .= "(" . join(',', map { $_->name } @{$field->property( "fields_cache" )} ) . ")";
	}
	push @row, $field->property( "volatile" ) ? 'Y' : 'N';
	push @row, $repo->xhtml->to_text_dump( $field->render_name );
	push @row, $repo->xhtml->to_text_dump( $field->render_help );
	{
		my $db_field = $field;
		if( $db_field->has_property( "fields_cache" ) )
		{
			$db_field = $db_field->property( "fields_cache" )->[0];
		}
		my $sql;
		my $Q_field = $db->quote_identifier( ($db_field->get_sql_names)[0] );
		my $Q_keyfield = $db->quote_identifier( $dataset->key_field->get_sql_name );
		if( $db_field->property( "multiple" ) )
		{
			my $table = $dataset->get_sql_sub_table_name( $db_field );
			$sql = "SELECT COUNT(DISTINCT $Q_keyfield) FROM ".
				$db->quote_identifier( $table );
		}
		else
		{
			my $table = $dataset->get_sql_table_name;
			$sql = "SELECT COUNT(DISTINCT $Q_keyfield) FROM ".
				$db->quote_identifier($table).
				" WHERE $Q_field IS NOT NULL AND $Q_field != ''";
		}
		my $sth = $db->prepare( $sql );
		$sth->execute or die "Error in SQL: $sql";
		push @row, $sth->fetch->[0];
	}
	&csv( @row );
}

sub csv
{
	my( @row ) = @_;

	for(@row)
	{
		s/"/""/g;
	}

	print join(',', map { "\"$_\"" } @row) . "\n";
}
