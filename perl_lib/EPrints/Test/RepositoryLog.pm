package EPrints::Test::RepositoryLog;

=head1 NAME

EPrints::Test::RepositoryLog - capture repository log messages

=cut

use strict;

our @logs;

{
no warnings;
sub EPrints::Repository::log
{
	my( $repo, $msg ) = @_;

	push @logs, $msg;
}
}

sub logs
{
	my @r = @logs;
	@logs = ();

	return @r;
}

1;
