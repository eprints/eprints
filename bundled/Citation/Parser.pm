package Citation::Parser;
use Paracite::Search;
use strict;

sub new
{
	my($class) = @_;
	my $self = {};
	return bless($self, $class);
}

sub parse
{
	my($self, $ref) = @_;
	die "This method should be overridden.\n";
}

1;
