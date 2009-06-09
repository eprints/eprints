package EPrints::DataObj::VFS;

=head1 NAME

EPrints::DataObj::VFS - Virtual File System paths

=cut

use strict;
use warnings;

our @ISA = qw( EPrints::DataObj );

sub get_system_field_info
{
	return (
		{ name => "path", type => "text", required => 1, },
		{ name => "userid", type => "itemref", datasetid => "user", },
		{ name => "datestamp", type => "timestamp", },
		{ name => "type", type => "set", options => [qw( file directory deletion )], },
		{ name => "target", type => "text", },
	);
}

1;
