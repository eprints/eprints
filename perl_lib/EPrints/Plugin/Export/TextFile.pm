package EPrints::Plugin::Export::TextFile;

# Insert a byte-order mark into the output

our @ISA = qw( EPrints::Plugin::Export );

use File::BOM;

sub byte_order_mark
{
	return $File::BOM::enc2bom{"utf8"};
}

1;
