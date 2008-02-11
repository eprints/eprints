######################################################################
#
# EPrints::Index::Daemon
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Index::Daemon> - indexer process

=head1 DESCRIPTION

This module provides utility wrappers around the indexing engine to provide a
daemonised service.

You probably don't want to use anything here directly, instead use the
B<bin/indexer> script or L<EPrints::Plugin::Screen::Admin::IndexerControl>.

=head1 METHODS

=over 4

=cut


package EPrints::Index::Daemon;

use EPrints;

use POSIX 'setsid';

use strict;

=head2 Class Methods

=cut

=item EPrints::Index::Daemon->new( %opts )

Return a new daemon control object. May optionally specify 'session', 'logfile', 'noise' and 'Handler' to control log output.

=cut

sub new
{
	my( $class, %opts ) = @_;

#	$opts{logfile} = EPrints::Index::logfile();
	$opts{pidfile} ||= EPrints::Index::pidfile();
	$opts{tickfile} ||= EPrints::Index::tickfile();
	$opts{suicidefile} ||= EPrints::Index::suicidefile();
	$opts{noise} = 1 unless defined $opts{noise};
	$opts{rollcount} = 5 unless defined $opts{rollcount};
	$opts{maxwait} ||= 8;
	$opts{interval} ||= 30;
	$opts{respawn} ||= 60*60*24;
	$opts{timeout} ||= 10*60;

	my $self = bless \%opts, $class;

	$self->{Handler} ||= EPrints::CLIProcessor->new(
		session => $self->{session}
	);

	return $self;
}

=head2 Accessors

=cut

# return the current handler
sub handler { $_[0]->{Handler} }

# write the given pid or $$
sub write_pid
{
	my( $self, $pid ) = @_;
	my $pidfile = $self->{pidfile};
	open( PID, ">", $pidfile) or die "Error writing pid file $pidfile: $!";
	print PID ($pid || $$);
	close( PID );
}

sub get_pidfile
{
	my( $self ) = @_;
	return $self->{pidfile};
}

=item $daemon->get_timeout

Returns the maximum time to allow an indexing process to take. Defaults to 10 minutes.

=cut

sub get_timeout { $_[0]->{timeout} }

=item $daemon->get_respawn

Returns the time between respawns. On respawn the log files are rotated. Defaults to 1 day.

In practise respawns are likely to take slightly longer than the time given.

=cut

sub get_respawn { $_[0]->{respawn} }

=item $daemon->get_interval

Returns the time between checks on the indexing queues, when we're idling. Defaults to 30 seconds.

=cut

sub get_interval
{
	my( $self ) = @_;
	return $self->{interval};
}

=item $daemon->get_pid

Get the current indexer pid or undef.

=cut

sub get_pid
{
	my( $self ) = @_;
	my $pidfile = $self->{pidfile};
	open( PID, "<", $pidfile) or return undef;
	my $pid = <PID>;
	close( PID );
	return ($pid and $pid > 0) ? $pid : undef;
}

=item $daemon->remove_pid

If is_running() is true but you still want to force a new indexer start, remove the existing pid file. Otherwise, you shouldn't have any need to call this method.

=cut

sub remove_pid
{
	my( $self ) = @_;
	my $pidfile = $self->{pidfile};
	return unlink($pidfile);
}

=item $daemon->is_running()

Returns true if the indexer appears to be running. Returns undef if no PID was found.

=cut

sub is_running
{
	my( $self ) = @_;
	my $pid = $self->get_pid or return undef;
	return kill(0, $pid) ? 1 : 0;
}

# tick tock
sub tick
{
	my( $self ) = @_;

	open( TICK, ">", $self->{tickfile} ) or die "Error opening tick file $self->{tickfile}: $!";
	print TICK <<END;
# This file is by the indexer to indicate
# that the indexer is still is_running.
END
	close TICK;
}

=item $daemon->has_stalled()

Returns true if the indexer appears to have stopped running (i.e. no tick for 10 minutes).

=cut

sub has_stalled
{
	my( $self ) = @_;

	return $self->get_last_tick > 10*60;
}

=item $daemon->get_last_tick

Seconds since last tick, based on when the current script started.

=cut

sub get_last_tick
{
	my( $self ) = @_;

	return 0 unless -e $self->{tickfile};

	# fractions of days, change to seconds
	my $age = -M $self->{tickfile};
	return $age * 60*60*24;
}

# true if we've been asked to exit
sub suicidal
{
	return -e $_[0]->{suicidefile};
}

# roll the log files then reopen the main log file
sub roll_logs
{
	my( $self ) = @_;

	return unless $self->{logfile};

	$self->log( 0, "** End of log. Closing and rolling." );

	for( my $n = $self->{rollcount}; $n > 0; --$n )
	{
		my $src = $self->{logfile};
		if( $n > 1 ) { $src.='.'.($n-1); }
		next unless( -f $src );
		my $tgt = $self->{logfile}.'.'.$n;
		if( !rename( $src, $tgt ) )
		{
			$self->log( 0, "*** Error in log file rotation, failed to rename $src to $tgt: $!" );
			return;
		}
	}
	close STDERR;
	open( STDERR, ">>", $self->{logfile} ); # If this fails we're stuffed
}

# abort() if fork() fails
sub safe_fork
{
	my $pid = fork();
	EPrints::abort "fork() failed\n" unless defined $pid;
	return $pid;
}

# Get all sessions for all repositories
sub get_all_sessions
{
	my( $self ) = @_;

	my @sessions;

	my @arc_ids = EPrints::Config::get_repository_ids();
	foreach my $arc_id (sort @arc_ids)
	{
		my $repository = EPrints::Repository->new( $arc_id );
		next unless $repository->get_conf( "index" );
		my $session = EPrints::Session->new( 1 , $arc_id );
		if( !defined $session )
		{
			$self->log( 0, "!! Could not open session for $arc_id" );
			next;
		}
		push @sessions, $session;
	}

	return @sessions;
}

=item $daemon->log( LEVEL, MESSAGE )

Prints MESSAGE to STDERR if noise >= LEVEL.

=cut

sub log
{
	my( $self, $level, $msg ) = @_;

	return unless $self->{noise} >= $level;

	if( !defined $msg )
	{
		print STDERR "\n";
		return;
	}

	print STDERR "[".localtime()."] ".$msg."\n";
}

=head2 Control Methods

=cut

=item $daemon->start( $session )

Starts the indexer process from an existing EPrints session.

=cut

sub start
{
	my( $self, $session ) = @_;

	my $rc = 0;

	my $perl = $EPrints::SystemSettings::conf->{executables}->{perl};
	my $perl_lib = $EPrints::SystemSettings::conf->{base_path} . "/perl_lib";
	my $logfile = quotemeta($self->{logfile}||'');
	my $prog = <<END;
EPrints::Index::Daemon->new( logfile => "$logfile" )->start_daemon();
END

	my( $in_fh, $out_fh, $err_fh ) = $session->get_request->spawn_proc_prog( $perl, [
		"-w",
		"-I$perl_lib",
		"-MEPrints",
		"-e", $prog,
	]);

	while(defined(my $err = <$err_fh>))
	{
		$self->handler->add_message( "warning", $session->make_text( $err ));
	}

	close($in_fh);
	close($out_fh);
	close($err_fh);

	for(1..$self->{maxwait})
	{
		if( $self->is_running )
		{
			$rc = 1;
			last;
		}
		sleep(1);
	}

	return $rc;
}

=item $daemon->stop( $session )

Stops the indexer process from an existing EPrints session.

=cut

sub stop
{
	my( $self, $session ) = @_;

	return $self->stop_daemon;
}

# Make sure the child has quit and remove our control files
sub cleanup
{
	my( $self, $force ) = @_;

	# ask child to exit now
	if( $force )
	{
		if( $self->{child} ) {
			$self->log(1,"** Asking child to exit: $self->{child}");
			kill 9, $self->{child};
			delete $self->{child};
		}
	}
	elsif( $self->{child} )
	{
		waitpid($self->{child}, 0);
	}

	unlink($self->{tickfile});
	unlink($self->{suicidefile});

	$self->remove_pid;
}

# Really exit, ignoring mod_perl's pseudo-exit.
sub real_exit
{
	my( $self ) = @_;

	if( $self->{session} and $self->{session}->{request} )
	{
		CORE::exit(0); # exit inside mod_perl
	}
	else
	{
		exit(0);
	}
}

=item $daemon->start_daemon()

Starts the indexer process from the current process. You should check the indexer isn't running before calling this method.

This method will fork() then redirect STDOUT and STDERR to logfile (if configured), otherwise messages will be output to STDERR.

Returns true if successful.

=cut

sub start_daemon
{
	my( $self ) = @_;

	my $pid = $self->safe_fork;
	if( $pid )
	{
		for(1..$self->{maxwait})
		{
			return 1 if $self->is_running;
			sleep(1);
		}
		return 0;
	}

	$0 = "indexer";

	# Make sure we can pid and tick
	$self->write_pid($$);
	$self->tick();

	chdir("/");
	if( -e "/dev/null" )
	{
		open(STDIN, "/dev/null") or die "Can't open /dev/null for reading: $!";
	}
	else
	{
		close(STDIN);
	}
	if( $self->{logfile} )
	{
		open(STDOUT, ">>", $self->{logfile})
			or die "Can't write to $self->{logfile} (STDOUT): $!";
		open(STDERR, ">>", $self->{logfile})
			or die "Can't write to $self->{logfile} (STDERR): $!";
	}

	setsid() or die "Can't start a new session: $!";

	$SIG{TERM} = sub {
		$self->log( 2, "*** TERM signal received" );
		$self->cleanup(1);
		$self->real_exit;
	};
	$SIG{CHLD} = 'IGNORE';

	$self->log( 1, "** Indexer process started" );

	$self->log( 3, "** Indexer control process started with process ID: $$" );

	while(1)
	{
		$self->log( 2, "*** Starting indexer sub-process" );

		my $pid = $self->{child} = $self->safe_fork;
		if( $pid )
		{
			# parent
			waitpid($pid, 0);
			delete $self->{child};

			if( $self->suicidal )
			{
				$self->log( 1, "** Indexer process stopping" );
				last;
			}
			last if( $self->{once} );
		}
		else
		{
			# child
			setsid() or die "Can't start a new worker: $!";
			$self->run_index();
			$self->real_exit();
		}
	}

	$self->cleanup;
	$self->real_exit;
}

=item $daemon->stop_daemon

Stops the indexer process from the current process. You should check the indexer is running before calling this method.

Returns true if successful.

=cut

sub stop_daemon
{
	my( $self ) = @_;

	open(SUICIDE, ">", $self->{suicidefile});
	print SUICIDE <<END;
# This file is recreated by the indexer to indicate
# that the indexer should exit.
END
	close SUICIDE;

	for( 1..$self->{maxwait} )
	{
		if( !$self->is_running )
		{
			unlink($self->{suicidefile});
			return 1;
		}
		sleep(1);
	}

	unlink($self->{suicidefile});

	# That didn't work, lets try killing it
	if( my $pid = $self->get_pid )
	{
		kill 9, $pid;
	}

	return 1;
}

=item $daemon->run_index

Runs a single indexing process for all repositories.

=cut

sub run_index
{
	my( $self ) = @_;

	$self->log( 3, "** Worker process started: $$" );

	my @sessions = $self->get_all_sessions();

	$SIG{TERM} = sub {
		$self->log( 3, "** Worker process terminated: $$" );
		$_->terminate for @sessions;
		$self->real_exit;
	};

	my $suicidal = $self->suicidal;

	while( !$suicidal )
	{
		my $seen_action = 0;

		foreach my $session ( @sessions )
		{
			# give the next code $timeout secs to complete
			eval {
				local $SIG{ALRM} = sub { die "alarm\n" };
				alarm($self->get_timeout);
				$seen_action ||= EPrints::Index::do_index( $session, {
					loglevel => $self->{noise},
				});
				alarm(0);
			};
			if( $@ )
			{
				die unless $@ eq "alarm\n";
				$self->log( 1, "** Timed out processing index entry: some indexing failed" );
			}
		}

		$self->log( 4, "* tick: $$" );
		$self->tick;

		# is it time to respawn yet?
		if( $self->should_respawn )
		{
			$self->log( 3, "** Worker process restarting: $$" );
			$self->roll_logs unless $self->{once};
			last;
		}

		next if( $seen_action );

		last if( $self->{once} );

		# wait interval seconds. Check suicide requests every 5 seconds.
		my $stime = time();
		while( ($stime + $self->{interval}) > time() )
		{
			if( $self->suicidal )
			{
				$suicidal = 1;
				last;
			}
			sleep 5;
		}
	}

	if( $suicidal )
	{
		$self->log( 3, "** Worker process stopping: $$" );
	}

	$_->terminate for @sessions;
}

# is it time to respawn the indexer/roll the logs?
sub should_respawn
{
	my( $self ) = @_;

	my $rc = 0;

	if( !defined $self->{nextrespawn} )
	{
		$self->{nextrespawn} = time() + $self->get_respawn;
	}
	elsif( time() > $self->{nextrespawn} )
	{
		$rc = 1;
		$self->{nextrespawn} += $self->get_respawn;
	}

	return $rc;
}

1;

=back

=head1 SEE ALSO

L<EPrints::Index>

=cut

