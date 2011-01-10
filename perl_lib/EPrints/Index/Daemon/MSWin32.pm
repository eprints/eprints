package EPrints::Index::Daemon::MSWin32;

use Win32::Daemon;

use EPrints::Index::Daemon;
@ISA = qw( EPrints::Index::Daemon );
our $WIN32_SERVICENAME = 'EPrintsIndexer';

use strict;

sub win32_error
{
	my( $self, $msg ) = @_;

	EPrints->abort( "$msg: $^E" );
}

sub create_service
{
	my( $self ) = @_;

	my $path = $EPrints::SystemSettings::conf->{base_path} . "/bin/indexer";

	my $rc = Win32::Daemon::CreateService({
		machine => '',
		name => $WIN32_SERVICENAME,
		display => 'EPrints Indexer',
		path => $^X,
		user => '',
		pwd => '',
		description => 'Background indexing and thumbnailing',
		parameters => "$path --service start",
	});
       
	if( !$rc )
	{
		$self->win32_error( 'Create EPrints Indexer service' );
	}

	return $rc;
}

sub delete_service
{
	my( $self ) = @_;

	my $rc = Win32::Daemon::DeleteService('', $WIN32_SERVICENAME);

	if( !$rc )
	{
		$self->win32_error( 'Delete EPrints Indexer service' );
	}

	return $rc;
}

sub is_running
{
	my( $self ) = @_;

	my $status = {};
	if( !Win32::Service::GetStatus('',$WIN32_SERVICENAME,$status) )
	{
		$self->win32_error( "EPrints Indexer service state" );
	}

	return $status->{'CurrentState'} == 0x04; # running
}

sub start_daemon
{
	my( $self ) = @_;

	if( !Win32::Service::StartService('',$WIN32_SERVICENAME) )
	{
		$self->_error_win32( "Starting EPrints Indexer service" );
	}

	return 1;
}

sub stop_daemon
{
	my( $self ) = @_;

	if( !Win32::Service::StopService('',$WIN32_SERVICENAME) )
	{
		$self->_error_win32( "Stopping EPrints Indexer service" );
	}

	return 1;
}

sub start_service
{
	my( $self ) = @_;

	if( $self->{logfile} )
	{
		open(STDOUT, ">>", $self->{logfile})
			or die "Error opening $self->{logfile}: $!";
		open(STDERR, ">>", $self->{logfile})
			or die "Error opening $self->{logfile}: $!";
	}

	$self->log( 3, " ** Registering service callbacks" ); 

	Win32::Daemon::RegisterCallbacks( {
		start => \&callback_start,
		running => \&callback_running,
		stop => \&callback_stop,
		pause => \&callback_pause,
		continue => \&callback_continue,
	} );

	my %context = (
		last_state => SERVICE_STOPPED,
		start_time => time(),
		self => $self,
	);

	$self->log( 3, " ** StartService" );

	Win32::Daemon::StartService( \%context, 5000 );

	# this reached on StopService

	return 1;
}

# called every 5 seconds
sub callback_running
{
	my( $event, $context ) = @_;

	my $self = $context->{self};

	my @repos = $self->get_all_sessions();

	while( SERVICE_RUNNING == Win32::Daemon::State() )
	{
		$self->log( 3, " ** tick" );
		$self->tick;

		my $seen_action = 0;

		foreach my $repo (@repos)
		{
			$repo->check_last_changed;

			eval {
				local $SIG{ALRM} = sub { die "alarm\n" };
				alarm($self->get_timeout);
				$seen_action |= $self->_run_index( $repo, {
					loglevel => $self->{loglevel},
				} );
				alarm(0);
			};
			if( $@ )
			{
				die unless $@ eq "alarm\n";
				$self->log( 1, "**  Timed out processing index entry: some indexing failed" );
			}
		}

		last if !$seen_action;
	}
}

sub callback_start
{
	my( $event, $context ) = @_;

	$context->{self}->log( 3, " ** callback_start" );

	$context->{last_state} = SERVICE_RUNNING;
	Win32::Daemon::State( SERVICE_RUNNING );
}

sub callback_pause
{
	my( $event, $context ) = @_;

	$context->{self}->log( 3, " ** callback_pause" );

	$context->{last_state} = SERVICE_PAUSED;
	Win32::Daemon::State( SERVICE_PAUSED );
}

sub callback_continue
{
	my( $event, $context ) = @_;

	$context->{self}->log( 3, " ** callback_continue" );

	$context->{last_state} = SERVICE_RUNNING;
	Win32::Daemon::State( SERVICE_RUNNING );
}

sub callback_stop
{
	my( $event, $context ) = @_;

	$context->{self}->log( 3, " ** callback_stop" );

	$context->{last_state} = SERVICE_STOPPED;
	Win32::Daemon::State( SERVICE_STOPPED );

	Win32::Daemon::StopService();
}

1;
