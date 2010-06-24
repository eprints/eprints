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

=item oneshot

If set to true removes this event once it has finished by success or failure.

=item priority

The priority for this event.

=item start_time

The event should not be executed before this time.

=item end_time

The event was last touched at this time.

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

The L<EPrints::Plugin::Event> plugin id to call to execute this event.

=item action

The name of the action to execute on the plugin (i.e. method name).

=item params

Parameters to pass to the action (a text serialisation).

=back

=cut

@ISA = qw( EPrints::DataObj );

use strict;

use constant {
	INTERNAL_ERROR => 0,
	SUCCESS => 1,
	IS_LOCKED => 2,
	BAD_PARAMETERS => 3,
};

sub get_system_field_info
{
	return (
		{ name=>"eventqueueid", type=>"counter", sql_counter=>"eventqueueid", required=>1 },
		{ name=>"datestamp", type=>"timestamp", required=>1, },
		{ name=>"hash", type=>"id", sql_index=>1, },
		{ name=>"unique", type=>"boolean", },
		{ name=>"oneshot", type=>"boolean", },
		{ name=>"priority", type=>"int", },
		{ name=>"start_time", type=>"timestamp", required=>1, },
		{ name=>"end_time", type=>"time", },
		{ name=>"due_time", type=>"time", },
		{ name=>"repetition", type=>"int", sql_index=>0, },
		{ name=>"status", type=>"set", options=>[qw( waiting inprogress success failed )], default_value=>"waiting", },
		{ name=>"userid", type=>"itemref", datasetid=>"user", },
		{ name=>"description", type=>"longtext", },
		{ name=>"pluginid", type=>"id", required=>1, },
		{ name=>"action", type=>"id", required=>1, },
		{ name=>"params", type=>"storable", },
	);
}

sub get_dataset_id { "event_queue" }

sub create_unique
{
	my( $class, $session, $data, $dataset ) = @_;

	$dataset ||= $session->dataset( $class->get_dataset_id );

	$data->{unique} = "TRUE";

	my $md5 = Digest::MD5->new;
	$md5->add( $data->{pluginid} );
	$md5->add( $data->{action} );
	$md5->add( EPrints::MetaField::Storable->freeze( $session, $data->{params} ) )
		if EPrints::Utils::is_set( $data->{params} );
	$data->{hash} = $md5->hexdigest;

	my $results = $dataset->search(
		filters => [
			{ meta_fields => [qw( hash )], value => $data->{hash} },
			{ meta_fields => [qw( status )], value => "waiting inprogress", match => "EQ", merge => "ANY" },
		],
		limit => 1);
	my $count = $results->count;

	if( $count > 0 )
	{
		return undef;
	}

	return $class->create_from_data( $session, $data, $dataset );
}

=item $ok = $event->execute()

Execute the action this event describes.

=cut

sub execute
{
	my( $self ) = @_;

	# commenced at
	$self->set_value( "end_time", EPrints::Time::get_iso_timestamp() );
	$self->commit();

	my $rc = $self->_execute();

	# completed at
	$self->set_value( "end_time", EPrints::Time::get_iso_timestamp() );

	if( $rc == IS_LOCKED )
	{
		$self->set_value( "status", "waiting" );
		$self->commit;
	}
	# BAD_PARAMETERS probably means the object has gone away, which is ok
	elsif( $rc == SUCCESS || $rc == BAD_PARAMETERS )
	{
		if( !$self->is_set( "oneshot" ) || $self->value( "oneshot" ) eq "TRUE" )
		{
			$self->remove();
		}
		else
		{
			if( $rc == SUCCESS )
			{
				$self->set_value( "status", "success" );
			}
			else # BAD_PARAMETERS
			{
				$self->set_value( "status", "failed" );
			}
			$self->commit;
		}
	}
	elsif( $rc == INTERNAL_ERROR )
	{
		$self->set_value( "status", "failed" );
		$self->commit();
	}

	return $rc;
}

sub _execute
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $xml = $session->xml;

	my $plugin = $session->plugin( $self->value( "pluginid" ) );
	if( !defined $plugin )
	{
		# no such plugin
		$self->message( "error", $xml->create_text_node( $self->value( "pluginid" )." not available" ) );
		return INTERNAL_ERROR;
	}

	my $action = $self->value( "action" );
	if( !$plugin->can( $action ) )
	{
		$self->message( "error", $xml->create_text_node( "'$action' not available on ".ref($plugin) ) );
		return INTERNAL_ERROR;
	}

	my $params = $self->value( "params" );
	if( !defined $params )
	{
		$params = [];
	}
	my @params = @$params;

	# expand any object identifiers
	foreach my $param (@params)
	{
		if( $param =~ m# ^/id/([^/]+)/(.+)$ #x )
		{
			my $dataset = $session->dataset( $1 );
			if( !defined $dataset )
			{
				$self->message( "error", $xml->create_text_node( "Bad parameters: No such dataset '$1'" ) );
				return BAD_PARAMETERS;
			}
			$param = $dataset->dataobj( $2 );
			if( !defined $param )
			{
				$self->message( "error", $xml->create_text_node( "Bad parameters: No such item '$2' in dataset '$1'" ) );
				return BAD_PARAMETERS;
			}
			my $locked = 0;
			if( $param->isa( "EPrints::DataObj::EPrint" ) )
			{
				$locked = 1 if( $param->is_locked() );
			}
			if( $param->isa( "EPrints::DataObj::Document" ) )
			{
				my $eprint = $param->get_parent;
				$locked = 1 if( $eprint && $eprint->is_locked() );
			}
			if( $locked )
			{
				$self->message( "warning", $xml->create_text_node( $param->get_dataset->base_id.".".$param->id." is locked" ) );
				return IS_LOCKED;
			}
		}
	}

	eval { $plugin->$action( @params ) };
	if( $@ )
	{
		$self->message( "error", $xml->create_text_node( "Error during execution: $@" ) );
		$self->set_value( "description", $@ );
		return INTERNAL_ERROR;
	}

	return 1;
}

=item $event->message( $type, $xhtml )

Register a message.

=cut

sub message
{
	my( $self, $type, $message ) = @_;

	my $msg = "";
	$msg = sprintf( "[%s] %s::%s: %s",
		$self->id,
		$self->value( "pluginid" ),
		$self->value( "action" ),
		$self->{session}->xhtml->to_text_dump( $message ) );
	$self->{session}->xml->dispose( $message );

	$self->{session}->log( $msg );
}

1;
