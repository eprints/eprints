=head1 NAME

EPrints::Plugin::Event::FilterAccess

=cut

package EPrints::Plugin::Event::FilterAccess;

use EPrints::Plugin::Event;

@ISA = qw( EPrints::Plugin::Event );

sub user_agent
{
	my( $self ) = @_;

	$self->access_map(sub {
		my ($access) = @_;

		my $is_robot = 0;

		for(@EPrints::Apache::USERAGENT_ROBOTS)
		{
			$is_robot = 1, last if $access->value("requester_user_agent") =~ $_;
		}

		print $access->id . ": " . $access->value("requester_user_agent") . "\n" if $is_robot;
	});

	return;
}

sub repeated
{
	my( $self ) = @_;

	my $repo = $self->repository;

	my %RECENT;
	my $window = 30;

	my $total = 0;
	my $removed = 0;

	$self->access_map(sub {
		my ($access) = @_;

		my $ip = $access->value("requester_id");
		my $referent = $access->is_set("referent_docid") ?
			$access->value("referent_docid") :
			$access->value("referent_id");
		my $service = $access->value("service_type_id");

		my $datestamp = $access->value("datestamp");

		my $key = "$ip|$referent|$service";
		my $seconds = EPrints::Time::datetime_utc(EPrints::Time::split_value($datestamp));

		if(scalar keys %RECENT > 1000) {
warn "cleanup";
			while(my($key, $t) = each %RECENT) {
				delete $RECENT{$key} if $t < $seconds - 30;
			}
		}

		my $is_repeat = 0;

		if ($RECENT{$key} && $RECENT{$key} + $window >= $seconds) {
			$is_repeat = 1;
		}

		$total++;
		$removed++ if $is_repeat;
		print STDERR "$removed of $total\r";
#		print $access->id . ": [$key] $RECENT{$key} + $window >= $seconds\n" if $is_repeat;

		$RECENT{$key} = $seconds;
exit if $total > 10000;
	});
}

sub access_map
{
	my ($self, $f) = @_;

	my $repo = $self->repository;

	my $accessid = 0;

	do {
		my $list = $repo->dataset("access")->search(filters => [
				{ meta_fields => [qw( accessid )], value => ($accessid+1)."..", }
			],
			limit => 10000,
		);
		undef $accessid;
		$list->map(sub { $accessid = $_[2]->id; &$f($_[2]) });
	} while(defined $accessid);
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

