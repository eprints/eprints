package EPrints::Test::ProcessSize;

=head1 NAME

EPrints::Test::ProcessSize - track the increase in Apache process size

=head1 SYNOPSIS

	# Add to cfg/apache.conf
	PerlInitHandler EPrints::Test::ProcessSize

Then monitor the Perl apache error log.

=head1 DESCRIPTION

This module hooks into the PerlInit and PerlCleanup stages of mod_perl to test whether the Apache child process has increased its footprint (based on GTop's 'resident' memory).

The log entries look like this:

	[pid] before increase method uri

Where:

=over 4

=item [pid]

The child process id.

=item before

The resident size before running the request.

=item increase

The increase in memory size after running the request.

=item method

The HTTP method (GET/POST etc.).

=item uri

The URI that was requested.

=back

=cut

use GTop;

use strict;

sub handler
{
	my( $r ) = @_;

	my $uri = $r->unparsed_uri;
	my $size = GTop->new->proc_mem( $$ )->resident;
	my $method = $r->method;

	$r->set_handlers(PerlCleanupHandler => sub { &record( $uri, $size, $method ) });

	return Apache2::Const::OK;
}

sub record
{
	my( $uri, $size, $method ) = @_;

	my $new_size = GTop->new->proc_mem( $$ )->resident;

	my $diff = $new_size - $size;

	print STDERR "[$$] $size ".EPrints::Utils::human_filesize($diff)." $method $uri\n";
}

1;
