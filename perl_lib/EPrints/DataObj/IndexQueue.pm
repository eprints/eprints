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
		{ name => "indexqueueid", type => "counter", required => 1, sql_counter => "indexqueueid" },
		{ name => "datestamp", type => "timestamp", required => 1, },
		{ name => "datasetid", type => "text", text_index => 0, required => 1, },
		{ name => "objectid", type => "text", text_index => 0, required => 1, },
		{ name => "fieldid", type => "text", text_index => 0, required => 1, },
	);
}

1;
