package EPrints::Test::Template;

use base qw( EPrints::Template::EPC );

use strict;

sub write_page
{
	my ($self, undef, $page) = @_;

	open(my $fh, ">>", \$EPrints::Test::OnlineSession::STDOUT)
		or die "Failed to output stdout capture: $!";

	$self->SUPER::write_page($fh, $page);

	close($fh);
}

1;
