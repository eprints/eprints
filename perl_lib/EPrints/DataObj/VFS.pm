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
		{ name => "datestamp", type => "time", },
		{ name => "type", type => "set", options => [qw( file directory deletion )], },
		{ name => "target", type => "text", },
	);
}

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	$data->{"datestamp"} = EPrints::Time::get_iso_timestamp();

	return $data;
}

1;
