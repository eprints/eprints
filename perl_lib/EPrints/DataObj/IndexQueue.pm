package EPrints::DataObj::IndexQueue;

=head1 NAME

EPrints::DataObj::IndexQueue - Indexer queue

=cut

use strict;
use warnings;

our @ISA = qw( EPrints::DataObj );

use EPrints::Utils;

use constant {
	ALL => "_all_",
	FULLTEXT => "_fulltext_",
};

sub get_system_field_info
{
	return (
		{ name => "indexqueueid", type => "int", required => 1, sql_counter => "indexqueueid" },
		{ name => "datestamp", type => "time", required => 1, },
		{ name => "datasetid", type => "text", text_index => 0, required => 1, },
		{ name => "objectid", type => "text", text_index => 0, required => 1, },
		{ name => "fieldid", type => "text", text_index => 0, required => 1, },
	);
}

sub get_defaults
{
	my( $class, $session, $data, $dataset ) = @_;

	$data = $class->SUPER::get_defaults( $session, $data, $dataset );

	$data->{"datestamp"} = EPrints::Time::get_iso_timestamp();

	return $data;
}

1;
