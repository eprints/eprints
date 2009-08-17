package EPrints::Plugin::Event;

@ISA = qw( EPrints::Plugin );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Base event plugin: This should have been subclassed";
	$self->{visible} = "all";
	$self->{advertise} = 1;

	return $self;
}

=item $ok = $plugin->run( $event )

Executes the $event on this plugin. Returns true on success.

=cut

sub run
{
	my( $self, $event ) = @_;

	my $rc = 1;

	my $action = $event->get_value( "action" );
	my $params = [];
	if( $event->is_set( "params" ) )
	{
		$params = $event->get_value( "params" );
	}

	if( !ref($params) eq "ARRAY" )
	{
		$self->plain_message( "error", "parameters are not an array" );
		return 0;
	}

	if( $action =~ /^([a-zA-Z_]+)$/ )
	{
		my $f = "run_$1";
		my $method = ref($self)."::$f";
		if( defined &$method )
		{
			$self->plain_message( "message", "executing $method(".join(', ', @$params).")" );
			$rc = $self->$f( $event, @$params );
		}
		else
		{
			$self->plain_message( "error", "Action '$action' ($method) not available" );
# action not available
			$rc = 0;
		}
	}
	else
	{
		$self->plain_message( "error", "Action '$action' contains bad characters" );
# dodgy action name
		$rc = 0;
	}

	return $rc;
}

=item $ok = $plugin->run_log( $event [, @params ] )

Example event method. If the B<action> is "log" this method will be called with the event parameters @params. This method just sends the message to the repository log.

Returns true on success.

=cut

sub run_log
{
	my( $self, $event, @params ) = @_;

	$self->{handle}->get_repository->log( "event: ".$event->get_value( "action" ) . " (" . join(', ', @params) . ")" );

	return 1;
}

sub plain_message
{
	my( $self, $type, $msg ) = @_;

	$self->message( $type, $self->{handle}->make_text( $msg ) );
}

# TODO: scheduler logging?
sub message
{
	my( $self, $type, $msg ) = @_;

	print STDERR "$type: ".EPrints::Utils::tree_to_utf8($msg)."\n";
	EPrints::XML::dispose( $msg );
}

1;
