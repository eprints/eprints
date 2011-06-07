package Proc::Reliable;

=head1 NAME

Proc::Reliable -- Run external processes reliably with many options.

=head1 SYNOPSIS

use Proc::Reliable;

Create a new process object
 
   $myproc = Proc::Reliable->new();

Run a subprocess and collect its output

   $output = $myproc->run("/bin/ls -l");

Check for problems

   if($myproc->status()) {
     print("problem!\n");
   }

Run another subprocess, keeping stdout and stderr separated.
Also, send the subprocess some data on stdin.

   $msg = "Hello World\n");
   $p->want_single_list(0);
   $stdout = $p->run("/usr/bin/fastmail - foo@bar.com", $msg);
   if($p->status()) {
     print("problem: ", $p->stderr(), "\n");
   }

Another way to get output

   ($stdout, $stderr, $status, $msg) = $p->run("/bin/ls -l");

=head1 OPTIONS

Run Modes

 $p->run("shell-command-line");  # Launch a shell process
 $p->run("cmdline", "data");     # Launch a shell process with stdin data
 $p->run(["cmd", "arg1", ...]);  # Bypass shell processing of arguments
 $p->run(sub { ... });           # Launch a perl subroutine
 $p->run(\&subroutine);          # Launch a perl subroutine

Option settings below represent defaults

 $p->num_tries(1);           # execute the program only once
 $p->time_per_try(60);       # time per try 60 sec
 $p->maxtime(60);            # set overall timeout
 $p->time_btw_tries(5);      # time between tries 5 sec
 $p->want_single_list();     # return STDOUT and STDERR together
 $p->accept_no_error();      # Re-try if any STDERR output
 $p->pattern_stdout($pat);   # require STDOUT to match regex $pat
 $p->pattern_stderr($pat);   # require STDERR to match regex $pat
 $p->allow_shell(1);         # allowed to use shell for operation
 $p->child_exit_time(1.0);   # timeout for child to exit after it closes stdout
 $p->sigterm_exit_time(0.5); # timeout for child to exit after sigterm
 $p->sigkill_exit_time(0.5); # timeout for child to exit after sigkill
 $p->input_chunking(0);      # feed stdin data line-by-line to subprocess
 $p->stdin_error_ok(0);      # ok if child exits without reading all stdin

Getting output

 $out = $p->stdout();        # stdout produced by last run()
 $err = $p->stderr();        # stderr produced by last run()
 $stat = $p->status();       # exit code produced by last run()
 $msg = $p->msg();           # module messages produced by last run()

Debug

Proc::Reliable::debug($level);         # Turn debug on

=head1 OVERVIEW

Proc::Reliable is a class for simple, reliable and
configurable subprocess execution in perl.  In particular, it is
especially useful for managing the execution of 'problem' programs
which are likely to fail, hang, or otherwise behave in an unruly manner.

Proc::Reliable includes all the
functionality of the backticks operator and system() functions, plus
many common uses of fork() and exec(), open2() and open3().
Proc::Reliable incorporates a number of options, including 
sending data to the subprocess on STDIN, collecting STDOUT and STDERR
separately or together, killing hung processes, timouts and automatic retries.

=cut

=head1 DESCRIPTION

A new process object is created by

   $myproc = Proc::Reliable->new();

The default will run a subprocess only once with a 60-second timeout.
Either shell-like command lines or references 
to perl subroutines can be specified for launching a process in 
background.  A simple list process, for example, can be started 
via the shell as

   $out = $myproc->run("ls");

To separate stdout, stderr, and exit status:

   ($out, $err, $status, $msg) = $myproc->run("ls");

The output data is also stored within the $myproc object for later
retrieval.  You can also run a perl subroutine in a subprocess, with

   $myproc->run(sub { return <*>; });

The I<run> Method will try to run the named process.  If the 
process times out (after I<time_per_try> seconds) or has an
error defined as unacceptable and you would like to re-run it,
you can use the I<num_tries> option.  Use the I<time_btw_tries>
option to set the number of seconds between runs.  This can repeat
until I<maxtime> seconds have elapsed.

When using I<num_tries>, the user can specify what constitutes an
unacceptable error of STDOUT or STDERR output -- i.e. demanding a retry.
One common shorthand is to have the I<run> method retry if there
is any return from STDERR.  

   $myproc->accept_no_error();    # Re-try if any STDERR
   $myproc->pattern_stdout($pat); # require STDOUT to match regex $pat
   $myproc->pattern_stderr($pat); # require STDERR to match regex $pat

Subprocess completion is detected when the process closes all filehandles.
The process must then exit before child_exit_time expires, or it will be
killed.  If the subprocess does not exit, it is sent a TERM signal unless
sigterm_exit_time is 0.  then if it does not exit before sigterm_exit_time
expires, it is sent a KILL signal unless sigkill_exit_time is 0.  then if
it does not exit before sigkill_exit_time expires an error is generated.
waiting is done in 0.01 second increments.

Proc::Reliable is not MT-Safe due to signals usage.

=cut

require 5.003;
use strict;
use Carp;
use FileHandle;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %SIG $AUTOLOAD);
use POSIX "sys_wait_h";

require Exporter;

@ISA     = qw(Exporter AutoLoader);
@EXPORT  = qw( );
$VERSION = '1.13';

######################################################################
# Globals: Debug and the mysterious waitpid nohang constant.
######################################################################
my $Debug = 0;
my $alarm_msg = "Proc::Reliable: child timed out";
# my $WNOHANG = _get_system_nohang();

# all valid options must exist in this hash
my %intdefaults = ("maxtime"          => 60,
		   "num_tries"        => 1,
		   "time_per_try"     => 60,
		   "time_btw_tries"   => 5,
		   "allow_shell"      => 1,
		   "want_single_list" => undef,
		   "accept_no_error"  => 0,
		   "pattern_stdout"   => undef,
		   "pattern_stderr"   => undef,
		   "child_exit_time"  => 1.0,
		   "sigterm_exit_time" => 0.5,
		   "sigkill_exit_time" => 0.5,
		   "input_chunking"    => 0,
		   "stdin_error_ok"    => 0,
		   "in_after_out_closed" => 1,
		  );

######################################################################

=head1 METHODS

The following methods are available:

=over 4

=item new (Constructor)

Create a new instance of this class by writing either

    $proc = new Proc::Reliable;   or   $proc = Proc::Reliable->new();

The I<new> method accepts any valid configuration options:

    $proc = Proc::Reliable->new('maxtime' => 200, 'num_tries' => 3);

=cut

######################################################################
# $proc_obj=Proc::Reliable->new(); - Constructor
######################################################################
sub new { 
  my($proto, %args) = @_;
  my $class = ref($proto) || $proto;
  my $self= { %intdefaults };
  bless($self, $class);

  my($arg);
  foreach $arg (keys(%args)) {
    $self->$arg($args{$arg});    # set options via AUTOLOAD
  }

  # Output fields
  $self->{stdout}= undef;
  $self->{stderr}= undef;
  $self->{status}= undef;
  $self->{msg} = undef;

  return $self;
}

######################################################################

=item run

Run a new process and collect the standard output and standard 
error via separate pipes.

  $out = $proc->run("program-name");
 ($out, $err, $status, $msg) = $proc->run("program-name");

by default with a single return value, stdout and stderr are combined
to a single stream and returned.  with 4 return values, stdout and
stderr are separated, and the program exit status is also returned.
$msg contains messages from Proc::Reliable when errors occur.
Set want_single_list(1) to force stdout and stderr to be combined,
and want_single_list(0) to force them separated.  The results from
run() are stored as member data also:

  $proc->want_single_list(0);
  $proc->run("program");
  if($proc->status) {
    print($proc->stderr);
    exit;
  }
  else {
    print($proc->stdout);
  }

Program exit status is returned in the same format as exec():
bits 0-7 set if program exited from a signal, bits 8-15 are the exit status
on a normal program exit.

There are a number of options.  You can also feed the forked program data
on stdin via a second argument to run():

 $myinput = "hello\ntest\n";
 $output = $proc->run("program-name", $myinput);

The first option to run() supports three forms:
1) string containing command string to execute.  this incurs shell parsing.
2) arrayref containing split command string to execute.  this bypasses shell parsing.
3) coderef to perl function.
The first two options are executed via exec(), so the specifics of incurring shell
parsing are the same.

The second option to run() supports two forms:
1) string containing data to feed on stdin
2) stringref pointing to data to feed on stdin

You can start execution of an 
independent Perl function (like "eval" except with timeout, 
retries, etc.).  Simply provide the function reference like

 $output = $proc->run(\&perl_function);

or supply an unnamed subroutine:

 $output = $proc->run( sub { sleep(1) } );

The I<run> Method returns after the the function finishes, 
one way or another.

=cut

######################################################################
# ($out, $err, $status, $msg) = $proc_obj->run("prg"); - Run process
######################################################################

my($_WAIT_INCR_SEC) = 0.01;   # global config

# signal handler for SIGCHLD, stores child return status in $self->{status}
sub _collect_child {
  my($self) = @_;
  my($x) = waitpid(-1, 0);
  $self->{status} = $?;
  $Debug && print("got '$x' '$?'\n");
}

# do it!
sub run {
  my($self, $cmd, $input) = @_;
  
  my($cmdstr);
  if(ref($cmd) eq "ARRAY") {
    # user can input command as either a string, listref of command pieces, or coderef
    $cmdstr = join(" ", @$cmd);
  }
  elsif(ref($cmd) eq "CODE") {
    $cmdstr = "<CODE>"
  }
  else {
    $cmdstr = $cmd;
  }

  my($inputref, @inputlines);
  if(defined($input)) {
    if(ref($input)) {
      # user can input either a scalar or a scalar ref for input data
      $inputref = $input;
    }
    else {
      $inputref = \$input;
    }
    if($self->input_chunking()) {
      @inputlines = split(/\n/, $$inputref);
    }
  }

  # if user has set want_single_list then do what they specify,
  # otherwise autodetect the most useful thing.
  my($do_single_list);
  if(defined($self->want_single_list())) {
    $do_single_list = $self->want_single_list();
  }
  else {
    $do_single_list = !wantarray();
  }

  my($pid, $t, $i);

  my $ntry= 0;
  my $starttime= time();
  my $endtime= time() + $self->maxtime();
  my $time_per_try= $self->time_per_try();
  
  my $patout= $self->pattern_stdout();
  my $paterr= $self->pattern_stderr();
  
  my $redo = 0;
  
  #foreach $t (keys(%$self)) {
  #  print("$t $self->{$t}\n");
  #}
  
  $t = 0;

  # initialize object output variables
  $self->{msg} = undef;
  
  my($fileno_getstdout,
     $fileno_getstderr,
     $fileno_getstdin,
     $fileno_putstdout,
     $fileno_putstderr,
     $fileno_putstdin);
  while(1) {
    $Debug && $self->_dprt("ATTEMPT $ntry: '$cmdstr' ");

    # initialize object output variables
    $self->{stdout} = undef;
    $self->{stderr} = undef;
    $self->{status} = undef;
    
    # set up pipes to collect STDOUT and STDERR from child process
    pipe(GETSTDOUT,PUTSTDOUT) || die("couldn't create pipe 1");
    pipe(GETSTDERR,PUTSTDERR) || die("couldn't create pipe 2");
    $fileno_getstdout = fileno(GETSTDOUT) || die("couldn't get fileno 1");
    $fileno_getstderr = fileno(GETSTDERR) || die("couldn't get fileno 2");
    $fileno_putstdout = fileno(PUTSTDOUT) || die("couldn't get fileno 3");
    $fileno_putstderr = fileno(PUTSTDERR) || die("couldn't get fileno 4");
    PUTSTDOUT->autoflush(1);
    PUTSTDERR->autoflush(1);
    if(defined($inputref)) {
      pipe(GETSTDIN,PUTSTDIN) || die("couldn't create pipe 3");
      $fileno_getstdin = fileno(GETSTDIN) || die("couldn't get fileno 5");
      $fileno_putstdin = fileno(PUTSTDIN) || die("couldn't get fileno 6");
      PUTSTDIN->autoflush(1);
    }
    
    # fork starts a child process, returns pid for parent, 0 for child
    STDOUT->flush();   # don't dup a non-empty buffer
    $redo = 0;

    ##### PARENT PROCESS #####
    if($pid = fork()) {
      # close the ends of the pipes the child will be using
      close(PUTSTDOUT);
      close(PUTSTDERR);
      if(defined($inputref)) {
	close(GETSTDIN);
      }

      #print("sigs 1: ",$SIG{ALRM}," , ",$SIG{PIPE}," , ",$SIG{CHLD},"\n");
      # set up handler to collect child return status no matter when it dies
      my($oldsigchld) = $SIG{CHLD};
      $SIG{CHLD} = sub { $self->_collect_child(); };

      eval {
	# exit the eval if child takes too long or dies abnormally
	local $SIG{ALRM} = sub { die("SIGALRM") };
	local $SIG{PIPE} = sub { die("SIGPIPE") };
	#print("sigs 2: ",$SIG{ALRM}," , ",$SIG{PIPE}," , ",$SIG{CHLD},"\n");
        $t = min($endtime - time(), $time_per_try);
        if($t < 1) {
	  return 1;
        }
	alarm($t);

	# set up and do a select() to read/write the child to avoid deadlocks
	my($stdinlen);
	my($stdoutdone, $stderrdone, $stdindone) = (0, 0, 0); #garply
	my($nfound, $fdopen, $bytestodo, $blocksize, $s);
	my($rin, $rout, $win, $wout, $ein, $eout, $gotread);
# bug: occational death with: 'Modification of a read-only value attempted at /home/public/dgold/acsim//Proc/Reliable.pm line 416.'
	$rin = $rout = $win = $wout = $ein = $eout = '';
	vec($rin, $fileno_getstdout, 1) = 1;
	vec($rin, $fileno_getstderr, 1) = 1;
	$blocksize = (stat(GETSTDOUT))[11];
	$fdopen = 2;  # stdout and stderr
	if(defined($inputref)) {
# bug: same bug here
	  vec($win, $fileno_putstdin, 1) = 1;
	  $stdinlen = length($$inputref);
	  if($self->in_after_out_closed()) {
	    $fdopen++;
	  }
	}
	
	while($fdopen) {
	  $nfound = select($rout=$rin, $wout=$win, $eout=$ein, undef);
	  
	  if (defined $inputref) {
	  
	  if(vec($wout, $fileno_putstdin, 1)) {  # ready to write
	    #print("write ready\n");
	    my($indone) = 0;
	    if($self->input_chunking()) {
	      if($gotread) {
		$gotread = 0;
		my($inputline) = shift(@inputlines) . "\n";
		$stdinlen = length($inputline);
		#print("writing $stdinlen '$inputline'\n");
		$s = syswrite(PUTSTDIN, $inputline, $stdinlen, 0);
		unless(defined($s)) {  # stdin closed by child
		  if($self->stdin_error_ok()) {
		    $indone = 1;
		  }
		  else {
		    croak("failure writing to subprocess: $!");
		  }
		}
		if(scalar(@inputlines) == 0) { # finished writing all data
		  $indone = 1;
		}
	      }
	    }
	    else {
	      $bytestodo = min($blocksize, $stdinlen - $stdindone);
	      $s = syswrite(PUTSTDIN, $$inputref, $bytestodo, $stdindone);
	      defined($s) || croak("failure writing to subprocess: $!");
	      $stdindone += $s;  # number of bytes actually written
	      if($stdindone >= $stdinlen) {  # finished writing all data
		$indone = 1;
	      }
	    }
	    if($indone) {
	      $win = undef;  # don't select this descriptor anymore
	      close(PUTSTDIN);
	      if($self->in_after_out_closed()) {
		$fdopen--;
	      }
	    }
	  }

	  }
	  
	  if(vec($rout, $fileno_getstdout, 1)) {  # ready to read
	    $gotread = 1;
	    $s = sysread(GETSTDOUT, $self->{stdout}, $blocksize, $stdoutdone);
	    defined($s) || croak("failure reading from subprocess: $!");
	    $stdoutdone += $s;  # number of bytes actually read
	    unless($s) {
	      vec($rin, $fileno_getstdout, 1) = 0;  # don't select this descriptor anymore
	      close(GETSTDOUT);
	      $fdopen--;
	    }
	  }
	  if(vec($rout, $fileno_getstderr, 1)) {  # ready to read
	    $gotread = 1;
	    $s = sysread(GETSTDERR, $self->{stderr}, $blocksize, $stderrdone);
	    defined($s) || croak("failure reading from subprocess: $!");
	    $stderrdone += $s;  # number of bytes actually read
	    unless($s) {
	      vec($rin, $fileno_getstderr, 1) = 0;  # don't select this descriptor anymore
	      close(GETSTDERR);
	      $fdopen--;
	    }
	  }
	}
	#print("bytes processed: $stdindone $stdoutdone $stderrdone\n");
	#if($self->input_chunking() && scalar(@inputlines)) {
	#  print(scalar(@inputlines) . " lines of stdin not fed\n");
	#}
	alarm(0);
	return 1;
      };  # end of eval

      # check return status of eval()
      if($@) {  # exited from eval() via die()
	if($@ =~ /SIG(ALRM|PIPE)/) {
	  my($sig) = $1;
	  if($sig eq "ALRM") {
	    $self->{msg} .= "Timed out after $t seconds\n";
	  }
	  else {
	    $self->{msg} .= "Pipe error talking to subprocess\n";
	  }
	  $redo++;
	}
	else {   # only a code bug should get here
	  croak("unexpected error talking to subprocess: '$@'");
	}
      }

      # wait until child exits, kill it if it doesn't.
      # normally child will exit shortly unless eval failed via SIGALRM.
      # if eval() succeeded, wait up to child_exit_time for child to exit
      my($s) = 0;
      while(!$redo && !defined($self->{status}) && kill(0, $pid) && ($s < $self->child_exit_time)) {
	#print("waiting for exit\n");
	select(undef, undef, undef, $_WAIT_INCR_SEC);
	$s += $_WAIT_INCR_SEC;
      }
      
      # if child has not exited yet, send sigterm.
      if(!defined($self->{status}) && kill(0, $pid) && $self->sigterm_exit_time) {  # child still alive
	#print("sending term\n");
	kill('TERM', $pid);
      }

      # wait until process exits or wait-time is exceeded.
      $s = 0;
      while(!defined($self->{status}) && kill(0, $pid) && ($s < $self->sigterm_exit_time)) {
	select(undef, undef, undef, $_WAIT_INCR_SEC);
	$s += $_WAIT_INCR_SEC;
      }

      if(!defined($self->{status}) && kill(0, $pid) && $self->sigkill_exit_time) {  # child still alive
	#print("sending kill\n");
	kill('KILL', $pid);
      }

      # wait until process exits or wait-time is exceeded.
      $s = 0;
      while(!defined($self->{status}) && kill(0, $pid) && ($s < $self->sigkill_exit_time)) {
	select(undef, undef, undef, $_WAIT_INCR_SEC);
	$s += $_WAIT_INCR_SEC;
      }

	  {
	  no warnings;
      $SIG{CHLD} = $oldsigchld;
	  }
      #print("sigs 3: ",$SIG{ALRM}," , ",$SIG{PIPE}," , ",$SIG{CHLD},"\n");
      
      if(!defined($self->{status})) {
	if(kill(0, $pid)) {
	  # get here if unable to kill or if coredump takes longer than sigkill_exit_time
	  $self->{msg} .= "unable to kill subprocess $pid";
	}
	$self->{status} = -1;
	$self->{msg} .= "no return status from subprocess\n";
      }
      else {
	if(kill(0, $pid)) {
	  # most likely coredumping?
	  $self->{msg} .= "got return status but subprocess still alive\n";
	}
      }
   }

    ##### CHILD PROCESS #####
    elsif(defined($pid)) {    # if child process: $pid == 0
      close(GETSTDOUT); close(GETSTDERR);
      if(defined($inputref)) {
	close(PUTSTDIN);
      }
      
      open(STDOUT, ">&=PUTSTDOUT") || croak("Couldn't redirect STDOUT: $!");
      if($do_single_list) {
	open(STDERR, ">&=PUTSTDOUT") || croak("Couldn't redirect STDERR: $!");
      }
      else {
	open(STDERR, ">&=PUTSTDERR") || croak("Couldn't redirect STDERR: $!");
      }
      
      if(defined($inputref)) {
	open(STDIN, "<&=GETSTDIN") || croak("Couldn't redirect STDIN: $!");
      }

      my($status) = -1;
      if(ref($cmd) eq "CODE") {
	$status = &$cmd;           # Start perl subroutine
      }
      elsif(ref($cmd) eq "ARRAY") {  # direct exec(), no shell parsing
	{
	no warnings;
	exec(@$cmd);
	croak("exec() failure: '$!'");
	}
      }
      else {                         # start shell process
	{
	no warnings;
	exec($cmd);
	croak("exec() failure: '$!'");
	}
      }

      # we get here for the perl subroutine normally.
      exit $status;
    }
    
    ##### FORK FAILURES #####
    elsif($! =~ /No more process/) {  # temporary fork error
      $self->{msg} .= "PERL fork error: $!\n";
      $redo++;
    }

    else {  # weird fork error
      croak("couldn't fork() subprocess: $!");
    }
    
    ##### CONTINUE AFTER CHILD IS DONE #####

    # figure out if we will loop again or exit
    $ntry++;  # retry counter
    if(defined($patout) or defined($paterr)) {
      $redo++ unless ($self->{stdout} =~ /$patout/);
      $redo++ unless ($self->{stderr} =~ /$paterr/);  
    }
    if($self->accept_no_error() && $self->{stderr}) {
      $redo++;    # accept_no_error only works if stdout and stderr are separated
    }

    $Debug && $self->_dprt("STDOUT\n$self->{stdout}");
    $Debug && $self->_dprt("STDERR\n$self->{stderr}");
    $Debug && $self->_dprt("RETURNVALUE $self->{status}");
    $Debug && $self->_dprt("MESSAGE\n$self->{msg}");

    if($redo) {
      if($ntry >= $self->{num_tries}) { 
	$self->{msg} .= "Exceeded retry limit\n";
	last;
      }
      if((time() + $self->time_btw_tries) >= $endtime) {
	$self->{msg} .= "Exceeded time limit\n";
	last;
      }
      sleep($self->time_btw_tries);
    }
    else {
      last;  # successful termination
    }
  } # end of retry loop

  if(wantarray()) {
    return ($self->{stdout}, $self->{stderr}, $self->{status}, $self->{msg});
  }
  else {
    return $self->{stdout};
  }
}

######################################################################

=item debug

Switches debug messages on and off -- Proc::Reliable::debug(1) switches
them on, Proc::Reliable::debug(0) keeps Proc::Reliable quiet.

=cut

sub debug { $Debug = shift; } # debug($level) - Turn debug on/off

######################################################################

=item maxtime

Return or set the maximum time in seconds per I<run> method call.  
Default is 300 seconds (i.e. 5 minutes). 

=cut

=item num_tries

Return or set the maximum number of tries the I<run> method will 
attempt an operation if there are unallowed errors.  Default is 5. 

=cut

=item time_per_try

Return or set the maximum time in seconds for each attempt which 
I<run> makes of an operation.  Multiple tries in case of error 
can go longer than this.  Default is 30 seconds. 

=cut

=item time_btw_tries

Return or set the time in seconds between attempted operations 
in case of unacceptable error.  Default is 5 seconds.  

=cut

=item child_exit_time

When the subprocess closes stdout, it is assumed to have completed
normal operation.  It is expected to exit within the amount of time
specified.  If it does not exit, it will be killed (with SIGTERM).
This option can be disabled by setting to '0'.
Values are in seconds, with a resolution of 0.01.

=cut

=item sigterm_exit_time

If the I<time_per_try> or I<max_time> has been exceeded, or if
I<child_exit_time> action has not succeeded, the subprocess will be
killed with SIGTERM.  This option specifies the amount of time to allow
the process to exit after closing stdout.
This option can be disabled by setting to '0'.
Values are in seconds, with a resolution of 0.01.

=cut

=item sigkill_exit_time

Similar to I<sigterm_exit_time>, but a SIGKILL is sent instead of a
SIGTERM.  When both options are enabled, the SIGTERM is sent first
and SIGKILL is then sent after the specified time only if the
subprocess is still alive.
This option can be disabled by setting to '0'.
Values are in seconds, with a resolution of 0.01.

=cut

=item input_chunking

If data is being written to the subprocess on stdin, this option will
cause the module to split() the input data at linefeeds, and only feed
the subprocess a line at a time.  This option typically would be used
when the subprocess is an application with a command prompt and does
not work properly when all the data is fed on stdin at once.
The module will feed the subprocess one line of data on stdin, and
will then wait until some data is produced by the subprocess on stdout
or stderr.  It will then feed the next line of data on stdin.

=cut

sub AUTOLOAD {
    my $self= shift; 
    my $type= ref($self) or croak("$self is not an object");
    my $name= $AUTOLOAD; 
    $name =~ s/.*://; # strip qualified call, i.e. Geometry::that
    unless (exists $self->{$name}) {
	croak("Can't access `$name' field in object of class $type");
    }
    if (@_) {
	my $val = shift;
	unless(exists($intdefaults{$name})) {
	    croak "Invalid $name initializer $val";
	}
	#print("got: $name -> $val\n");
	$self->{$name}= $val;
    }
    return $self->{$name};
}

sub DESTROY {
  my $self = shift;
}

# INPUT: two numbers
# OUTPUT: the larger one
sub max($$) {
    my($a, $b) = @_;
    return ($a > $b) ? $a : $b;
}

# INPUT: two numbers
# OUTPUT: the smaller one
sub min($$) {
    my($a, $b) = @_;
    return ($a < $b) ? $a : $b;
}

######################################################################
# Internal debug print function
######################################################################
sub _dprt { 
    return unless $Debug;
    if (ref($_[0])) {
        warn ref(shift()), "> @_\n"; 
    } else {
	warn "> @_\n";
    }
}

######################################################################
# This is for getting the WNOHANG constant of the system: a magic 
# flag for the "waitpid" command which guards against certain errors
# which could hang the system.  
# 
# Since the waitpid(-1, &WNOHANG) command isn't supported on all Unix 
# systems, and we still want Proc::Reliable to run on every system, we 
# have to quietly perform some tests to figure out if -- or if not.
# The function returns the constant, or undef if it's not available.
######################################################################
sub _get_system_nohang {
  return &WNOHANG;
}
#sub _get_system_nohang {
#    my $nohang;
#    open(SAVEERR, ">&STDERR");
#    # If the system doesn't even know /dev/null, forget about it.
#    open(STDERR, ">/dev/null") || return undef;
#    # Close stderr, since some weirdo POSIX modules write nasty
#    # error messages
#    close(STDERR);
#    # Check for the constant
#    eval 'use POSIX ":sys_wait_h"; $nohang = &WNOHANG;';
#    # Re-open STDERR
#    open(STDERR, ">&SAVEERR");
#    close(SAVEERR);
#    # If there was an error, return undef
#    return undef if $@;
#    return $nohang;
#}

1;

__END__

=head1 REQUIREMENTS

I recommend using at least perl 5.003.

=head1 AUTHORS

Proc::Reliable by Dan Goldwater <dgold at zblob dot com>

Based on Proc::Short, written by John Hanju Kim <jhkim@fnal.gov>.

Contributions by Stephen Cope.

=cut

=head1 COPYRIGHT

Copyright 2001 by Dan Goldwater, all rights reserved.
Copyright 1999 by John Hanju Kim, all rights reserved.

This program is free software, you can redistribute it and/or 
modify it under the same terms as Perl itself.

=cut

