package EPrints::DataObj::EventQueue;

=head1 NAME

EPrints::DataObj::EventQueue - Scheduler queue

=head1 FIELDS

=over 4

=item eventqueueid

A unique id for this event.

=item datestamp

The date/time the event was created.

=item hash

A unique hash for this event.

=item unique

If set to true only one event of this type (pluginid/action/params) is allowed to be running.

=item priority

The priority for this event.

=item start_time

The event should not be executed before this time.

=item end_time

The event was completed at this time.

=item due_time

Do not start this event if we have gone beyond due_time.

=item repetition

Repetition number of seconds will be added to start_time until it is greater than now and a new event created, when this event is completed.

=item status

The status of this event.

=item userid

The user (if any) that was responsible for creating this event.

=item description

A human-readable description of this event.

=item pluginid

The L<EPrints::Plugin::Event> plugin id to call to execute this event (not contained the leading "Event::").

=item action

The name of the action to execute on the plugin.

=item params

Parameters to pass to the action (a text serialisation).

=back

=cut

@ISA = qw( EPrints::DataObj );

use strict;

use constant {
	ALL => "_all_",
	FULLTEXT => "_fulltext_",
};

sub get_system_field_info
{
	return (
		{ name=>"eventqueueid", type=>"counter", sql_counter=>"eventqueueid", required=>1 },
		{ name=>"datestamp", type=>"timestamp", required=>1, },
		{ name=>"hash", type=>"text", sql_index=>1, },
		{ name=>"unique", type=>"boolean", },
		{ name=>"priority", type=>"int", },
		{ name=>"start_time", type=>"timestamp", required=>1, },
		{ name=>"end_time", type=>"time", },
		{ name=>"due_time", type=>"time", },
		{ name=>"repetition", type=>"int", sql_index=>0, },
		{ name=>"status", type=>"set", options=>[qw( waiting inprogress success failed )], default_value=>"waiting", },
		{ name=>"userid", type=>"itemref", datasetid=>"user", },
		{ name=>"description", type=>"longtext", },
		{ name=>"pluginid", type=>"text", required=>1, },
		{ name=>"action", type=>"text", required=>1, },
		{ name=>"params", type=>"storable", },
	);
}

sub get_dataset_id { "event_queue" }

sub new_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	if( defined $data->{unique} && $data->{unique} eq "TRUE" )
	{
		my $md5 = Digest::MD5->new;
		$md5->add_data( $data->{pluginid} );
		$md5->add_data( $data->{action} );
		$md5->add_data( $data->{params} )
			if EPrints::Utils::is_set( $data->{params} );
		$data->{hash} = $md5->hex_digest;

		my $searchexp = EPrints::Search->new(
			dataset => $dataset,
			session => $session,
			filters => [
				{ meta_fields => [qw( hash )], value => $data->{hash} },
				{ meta_fields => [qw( status )], value => "waiting inprogress", match => "EQ", merge => "ANY" },
			]);
		my $count = $searchexp->perform_search->count;
		$searchexp->dispose;

		if( $count > 0 )
		{
			return undef;
		}
	}

	return $class->SUPER::new_from_data( $session, $data, $dataset );
}

1;
