package DBI::Shell;

=head1 NAME

DBI::Shell - Interactive command shell for the DBI

=head1 SYNOPSIS

  perl -MDBI::Shell -e shell [<DBI data source> [<user> [<password>]]]

or

  dbish [<DBI data source> [<user> [<password>]]]

=head1 DESCRIPTION

The DBI::Shell module (and dbish command, if installed) provide a
simple but effective command line interface for the Perl DBI module.

DBI::Shell is very new, very experimental and very subject to change.
Your milage I<will> vary. Interfaces I<will> change with each release.

=cut

###
###	See TO DO section in the docs at the end.
###


BEGIN { require 5.004 }
BEGIN { $^W = 1 }

use strict;
use vars qw(@ISA @EXPORT $VERSION $SHELL);
use Exporter ();
use Carp;

@ISA = qw(Exporter);
@EXPORT = qw(shell);
$VERSION = sprintf "%d.%02d", '$Revision$ ' =~ /(\d+)\.(\d+)/;

my $warning = <<'EOM';

WARNING: The DBI::Shell interface and functionality are
=======  very likely to change in subsequent versions!

EOM

sub shell {
    my @args = @_ ? @_ : @ARGV;
    $SHELL = DBI::Shell::Std->new(@args);
    $SHELL->load_plugins;
    $SHELL->run;
}


# -------------------------------------------------------------
package DBI::Shell::Std;

use vars qw(@ISA);
@ISA = qw(DBI::Shell::Base);

# XXX this package might be used to override commands etc.


# -------------------------------------------------------------
package DBI::Shell::Base;

use Carp;
use Text::Abbrev ();
use Term::ReadLine;
use Getopt::Long 2.17;	# upgrade from CPAN if needed: http://www.perl.com/CPAN

use DBI 1.00 qw(:sql_types :utils);
use DBI::Format;

my $haveTermReadKey;


sub usage {
    warn <<USAGE;
Usage: perl -MDBI::Shell -e shell [<DBI data source> [<user> [<password>]]]
USAGE
}

sub log {
    my $sh = shift;
    ($sh->{batch}) ? warn @_,"\n" : print @_,"\n";	# XXX maybe
}

sub alert {	# XXX not quite sure how alert and err relate
    # for msgs that would pop-up an alert dialog if this was a Tk app
    my $sh = shift;
    warn @_,"\n";
}

sub err {	# XXX not quite sure how alert and err relate
    my ($sh, $msg, $die) = @_;
    $msg = "DBI::Shell: $msg\n";
    die $msg if $die;
    $sh->alert($msg);
}



sub add_option {
    my ($sh, $opt, $default) = @_;
    (my $opt_name = $opt) =~ s/[|=].*//;
    croak "Can't add_option '$opt_name', already defined"
	if exists $sh->{$opt_name};
    $sh->{options}->{$opt_name} = $opt;
    $sh->{$opt_name} = $default;
}


sub load_plugins {
    my ($sh) = @_;
    my @pi;
    foreach my $where (qw(DBI/Shell DBI_Shell)) {
	my $mod = $where; $mod =~ s!/!::!g; #/ so vim see the syn correctly
	my @dir = map { -d "$_/$where" ? ("$_/$where") : () } @INC;
	foreach my $dir (@dir) {
	    opendir DIR, $dir or warn "Unable to read $dir: $!\n";
	    push @pi, map { s/\.pm$//; "${mod}::$_" } grep { /\.pm$/ }
	        readdir DIR;
	    closedir DIR;
	}
    }
    foreach my $pi (@pi) {
	local $DBI::Shell::SHELL = $sh; # publish the current shell
	$sh->log("Loading $pi");
	eval qq{ use $pi };
	$sh->alert("Unable to load $pi: $@") if $@;
    }
    # plug-ins should remove options they recognise from (localized) @ARGV
    # by calling Getopt::Long::GetOptions (which is already in pass_through mode).
    foreach my $pi (@pi) {
	local *ARGV = $sh->{unhandled_options};
	$pi->init($sh);
    }
}


sub new {
    my ($class, @args) = @_;
    my $sh = bless {}, $class;

    #
    # Set default configuration options
    #
    foreach my $opt_ref (
	 [ 'command_prefix=s'	=> '/' ],
	 [ 'chistory_size=i'	=> 50 ],
	 [ 'rhistory_size=i'	=> 50 ],
	 [ 'rhistory_head=i'	=>  5 ],
	 [ 'rhistory_tail=i'	=>  5 ],
	 [ 'editor|ed=s'	=> ($ENV{VISUAL} || $ENV{EDITOR} || 'vi') ],
	 [ 'batch'		=> 0 ],
	 [ 'displaymode|display'=> 'neat' ],
	 [ 'columnseparator=s' => ',' ],
	# defaults for each new database connect:
	 [ 'init_trace|trace=i' => 0 ],
	 [ 'init_autocommit|autocommit=i' => 1 ],
	 [ 'debug|d=i'		=> ($ENV{DBISH_DEBUG} || 0) ],
    ) {
	$sh->add_option(@$opt_ref);
    }


    #
    # Install default commands
    #
    # The sub is passed a reference to the shell and the @ARGV-style
    # args it was invoked with.
    #
    $sh->{commands} = {

    'help' => {
	    hint => "display this list of commands",
    },
    'quit' => {
	    hint => "exit",
    },
    'exit' => {
	    hint => "exit",
    },
    'trace' => {
	    hint => "set DBI trace level for current database",
    },
    'connect' => {
	    hint => "connect to another data source/DSN",
    },

    # --- execute commands
    'go' => {
	    hint => "execute the current statement",
    },
    'do' => {
	    hint => "execute the current (non-select) statement",
    },
    'perl' => {
	    hint => "evaluate the current statement as perl code",
    },
    'commit' => {
	    hint => "commit changes to the database",
    },
    'rollback' => {
	    hint => "rollback changes to the database",
    },
    # --- information commands
    'table_info' => {
	    hint => "display tables that exist in current database",
    },
    'type_info' => {
	    hint => "display data types supported by current server",
    },
    'drivers' => {
	    hint => "display available DBI drivers",
    },

    # --- statement/history management commands
    'clear' => {
	    hint => "erase the current statement",
    },
    'redo' => {
	    hint => "re-execute the previously executed statement",
    },
    'get' => {
	    hint => "make a previous statement current again",
    },
    'current' => {
	    hint => "display current statement",
    },
    'edit' => {
	    hint => "edit current statement in an external editor",
    },
    'chistory' => {
	    hint => "display command history",
    },
    'rhistory' => {
	    hint => "display result history",
    },
    'format' => {
	    hint => "set display format for selected data (Neat|Box)",
    },
    'history' => {
	    hint => "display combined command and result history",
    },
    'option' => {
	    hint => "display or set an option value",
    },
    'describe' => {
	    hint => "display information about a table",
    },

    };


    # Source config file which may override the defaults.
    # Default is $ENV{HOME}/.dbish_config.
    # Can be overridden with $ENV{DBISH_CONFIG}.
    # Make $ENV{DBISH_CONFIG} empty to prevent sourcing config file.
    # XXX all this will change
    my $homedir = $ENV{HOME}				# unix
		|| "$ENV{HOMEDRIVE}$ENV{HOMEPATH}";	# NT
    $sh->{config_file} = $ENV{DBISH_CONFIG} || "$homedir/.dbish_config";
    if ($sh->{config_file} && -f $sh->{config_file}) {
	require $sh->{config_file};
    }
    
    #
    # Handle command line parameters
    #
    # data_source and user command line parameters overrides both 
    # environment and config settings.
    #
    local (@ARGV) = @args;
    my @options = values %{ $sh->{options} };
    Getopt::Long::config('pass_through');	# for plug-ins
    unless (GetOptions($sh, 'help|h', @options)) {
	$class->usage;
	croak "DBI::Shell aborted.\n";
    }
    if ($sh->{help}) {
	$class->usage;
	return;
    }
    $sh->{unhandled_options} = [];
    @args = ();
    foreach my $arg (@ARGV) {
	if ($arg =~ /^-/) {	# expected to be in "--opt=value" format
	    push @{$sh->{unhandled_options}}, $arg;
	}
	else {
	    push @args, $arg;
	}
    }

    $sh->do_format($sh->{displaymode});

    $sh->{data_source}	= shift(@args) || $ENV{DBI_DSN}  || '';
    $sh->{user}		= shift(@args) || $ENV{DBI_USER} || '';
    $sh->{password}	= shift(@args) || $ENV{DBI_PASS} || undef;

    $sh->{chistory} = [];	# command history
    $sh->{rhistory} = [];	# result  history

    #
    # Setup Term
    #
    my $mode;
    if ($sh->{batch} || ! -t STDIN) {
	$sh->{batch} = 1;
	$mode = "in batch mode";
    }
    else {
	$sh->{term} = new Term::ReadLine($class);
	$mode = "";
    }

    $sh->log("DBI::Shell $DBI::Shell::VERSION using DBI $DBI::VERSION $mode");
    $sh->log("DBI::Shell loaded from $INC{'DBI/Shell.pm'}") if $sh->{debug};

    return $sh;
}


sub run {
    my $sh = shift;

    die "Unrecognised options: @{$sh->{unhandled_options}}\n"
	if @{$sh->{unhandled_options}};

    $sh->log($warning) unless $sh->{batch};

    # Use valid "dbi:driver:..." to connect with source.
    $sh->do_connect( $sh->{data_source} );

    #
    # Main loop
    #
    $sh->{abbrev} = undef;
    $sh->{abbrev} = Text::Abbrev::abbrev(keys %{$sh->{commands}})
	unless $sh->{batch};
    $sh->{current_buffer} = '';
    my $current_line = '';

    while (1) {
	my $prefix = $sh->{command_prefix};

	$current_line = $sh->readline($sh->prompt());
	$current_line = "${prefix}quit" unless defined $current_line;

	if ( $current_line =~ /
		^(.*?)
		$prefix
		(?:(\w*)([^\|>]*))?
		((?:\||>>?).+)?
		$
	/x) {
	    my ($stmt, $cmd, $args_string, $output) = ($1, $2, $3, $4||''); 

	    $sh->{current_buffer} .= "$stmt\n" if length $stmt;

	    $cmd = 'go' if $cmd eq '';
	    my @args = split ' ', $args_string||'';

	    warn("command='$cmd' args='$args_string' output='$output'") 
		    if $sh->{debug};

	    my $command;
	    if ($sh->{abbrev}) {
		$command = $sh->{abbrev}->{$cmd};
	    }
	    else {
		$command = ($sh->{commands}->{$cmd}) ? $cmd : undef;
	    }
	    if ($command) {
		$sh->run_command($command, $output, @args);
	    }
	    else {
		if ($sh->{batch}) {
		    die "Command '$cmd' not recognised";
		}
		$sh->alert("Command '$cmd' not recognised ",
		    "(enter ${prefix}help for help).");
	    }
	}
	elsif ($current_line ne "") {
	    $sh->{current_buffer} .= $current_line . "\n";
	    # print whole buffer here so user can see it as
	    # it grows (and new users might guess that unrecognised
	    # inputs are treated as commands)
	    $sh->run_command('current', undef,
		"(enter '$prefix' to execute or '${prefix}help' for help)");
	}
    }
}
	



#
# Internal methods
#

sub readline {
    my ($sh, $prompt) = @_;
    my $rv;
    if ($sh->{term}) {
	$rv = $sh->{term}->readline($prompt);
    }
    else {
	chop($rv = <STDIN>);
    }
    return $rv;
}


sub run_command {
    my ($sh, $command, $output, @args) = @_;
    return unless $command;
    local(*STDOUT) if $output;
    local(*OUTPUT) if $output;
    if ($output) {
	if (open(OUTPUT, $output)) {
	    *STDOUT = *OUTPUT;
	} else {
	    $sh->err("Couldn't open output '$output'");
	    $sh->run_command('current', undef, '');
	}
    }
    eval {
	my $code = "do_$command";
	$sh->$code(@args);
    };
    close OUTPUT if $output;
    $sh->err("$command failed: $@") if $@;
}


sub print_list {
    my ($sh, $list_ref) = @_;
    for(my $i = 0; $i < @$list_ref; $i++) {
	print $i+1,":  $$list_ref[$i]\n";
    }
}


sub print_buffer {
    my ($sh, $buffer) = @_;
    print $sh->prompt(), $buffer, "\n";
}


sub get_data_source {
    my ($sh, $dsn, @args) = @_;
    my $driver;

    if ($dsn) {
	if ($dsn =~ m/^dbi:.*:/i) {	# has second colon
	    return $dsn;		# assumed to be full DSN
	}
	elsif ($dsn =~ m/^dbi:([^:]*)/i) {
	    $driver = $1		# use DriverName part
	}
	else {
	    print "Ignored unrecognised DBI DSN '$dsn'.\n";
	}
    }

    if ($sh->{batch}) {
	die "Missing or unrecognised DBI DSN.";
    }

    print "\n";
    while (!$driver) {
	print "Available DBI drivers:\n";
	my @drivers = DBI->available_drivers;
	for( my $cnt = 0; $cnt <= $#drivers; $cnt++ ) {
	    printf "%2d: dbi:%s\n", $cnt+1, $drivers[$cnt];
	} 
	$driver = $sh->readline(
		"Enter driver name or number, or full 'dbi:...:...' DSN: ");
	exit unless defined $driver;	# detect ^D / EOF
	print "\n";

	return $driver if $driver =~ /^dbi:.*:/i; # second colon entered

	if ( $driver =~ /^\s*(\d+)/ ) {
	    $driver = $drivers[$1-1];
	} else {
	    $driver = $1;
	    $driver =~ s/^dbi://i if $driver # incase they entered 'dbi:Name'
	}
	# XXX try to install $driver (if true)
	# unset $driver if install fails.
    }

    my $source;
    while (!defined $source) {
	my $prompt;
	my @data_sources = DBI->data_sources($driver);
	if (@data_sources) {
	    print "Enter data source to connect to: \n";
	    for( my $cnt = 0; $cnt <= $#data_sources; $cnt++ ) {
		printf "%2d: %s\n", $cnt+1, $data_sources[$cnt];
	    } 
	    $prompt = "Enter data source or number,";
	}
	else {
	    print "(The data_sources method returned nothing.)\n";
	    $prompt = "Enter data source";
	}
	$source = $sh->readline(
		"$prompt or full 'dbi:...:...' DSN: ");
	return if !defined $source;	# detect ^D / EOF
	if ($source =~ /^\s*(\d+)/) {
	    $source = $data_sources[$1-1]
	}
	elsif ($source =~ /^dbi:([^:]+)$/) { # no second colon
	    $driver = $1;		     # possibly new driver
	    $source = undef;
	}
	print "\n";
    }

    return $source;
}


sub prompt_for_password {
    my ($sh) = @_;
    if (!defined($haveTermReadKey)) {
	$haveTermReadKey = eval { require Term::ReadKey } ? 1 : 0;
    }
    local $| = 1;
    print "Password for $sh->{user} (",
	($haveTermReadKey ? "not " : "Warning: "),
	"echoed to screen): ";
    if ($haveTermReadKey) {
        Term::ReadKey::ReadMode('noecho');
	$sh->{password} = Term::ReadKey::ReadLine(0);
	Term::ReadKey::ReadMode('restore');
    } else {
	$sh->{password} = <STDIN>;
    }
    chomp $sh->{password};
    print "\n";
}

sub prompt {
    my ($sh) = @_;
    return "" if $sh->{batch};
    return "(not connected)> " unless $sh->{dbh};
    return "$sh->{user}\@$sh->{data_source}> ";
}


sub push_chistory {
    my ($sh, $cmd) = @_;
    $cmd = $sh->{current_buffer} unless defined $cmd;
    $sh->{prev_buffer} = $cmd;
    my $chist = $sh->{chistory};
    shift @$chist if @$chist >= $sh->{chistory_size};
    push @$chist, $cmd;
}


#
# Command methods
#

sub do_help {
    my ($sh, @args) = @_;
    my $prefix = $sh->{command_prefix};
    my $commands = $sh->{commands};
    print "Defined commands, in alphabetical order:\n";
    foreach my $cmd (sort keys %$commands) {
	my $hint = $commands->{$cmd}->{hint} || '';
	printf "  %s%-10s %s\n", $prefix, $cmd, $hint;
    }
    print "Commands can be abbreviated.\n" if $sh->{abbrev};
}


sub do_format {
    my ($sh, @args) = @_;
    my $mode = $args[0] || '';
    my $col_sep = $args[1];
    my $class = eval { DBI::Format->formatter($mode) };
    unless ($class) {
	$sh->alert("Unable to select '$mode': $@");
	return;
    }
    $sh->log("Using formatter class '$class'") if $sh->{debug};
    $sh->{display} = $class->new($sh);
    $sh->do_option("columnseparator=$col_sep") if $col_sep;
}


sub do_go {
    my ($sh, @args) = @_;

    return if $sh->{current_buffer} eq '';

    $sh->{prev_buffer} = $sh->{current_buffer};

    $sh->push_chistory;
    
    eval {
	my $sth = $sh->{dbh}->prepare($sh->{current_buffer});

	$sh->sth_go($sth, 1);
    };
    if ($@) {
	my $err = $@;
	$err =~ s: at \S*DBI/Shell.pm line \d+(,.*?chunk \d+)?::
		if !$sh->{debug} && $err =~ /^DBD::\w+::\w+ \w+/;
	print "$err";
    }

    # There need to be a better way, maybe clearing the
    # buffer when the next non command is typed.
    # Or sprinkle <$sh->{current_buffer} ||= $sh->{prev_buffer};>
    # around in the code.
    $sh->{current_buffer} = '';
}


sub sth_go {
    my ($sh, $sth, $execute) = @_;

    my $rv;
    if ($execute || !$sth->{Active}) {
	my @params;
	my $params = $sth->{NUM_OF_PARAMS} || 0;
	print "Statement has $params parameters:\n" if $params;
	foreach(1..$params) {
	    my $val = $sh->readline("Parameter $_ value: ");
	    push @params, $val;
	}
	$rv = $sth->execute(@params);
    }
	
    if (!$sth->{'NUM_OF_FIELDS'}) { # not a select statement
	local $^W=0;
	$rv = "undefined number of" unless defined $rv;
	$rv = "unknown number of"   if $rv == -1;
	print "[$rv row" . ($rv==1 ? "" : "s") . " affected]\n";
	return;
    }

    $sh->{sth} = $sth;

    #
    # Remove oldest result from history if reached limit
    #
    my $rhist = $sh->{rhistory};
    shift @$rhist if @$rhist >= $sh->{rhistory_size};
    push @$rhist, [];

    #
    # Keep a buffer of $sh->{rhistory_tail} many rows,
    # when done with result add those to rhistory buffer.
    # Could use $sth->rows(), but not all DBD's support it.
    #
    my @rtail;
    my $i = 0;
    my $display = $sh->{display} || die "panic: no display set";
    $display->header($sth, \*STDOUT, $sh->{columnseparator});
    while (my $rowref = $sth->fetchrow_arrayref()) {
	$i++;

	$display->row($rowref);

	if ($i <= $sh->{rhistory_head}) {
	    push @{$rhist->[-1]}, [@$rowref];
	}
	else {
	    shift @rtail if @rtail == $sh->{rhistory_tail};
	    push @rtail, [@$rowref];
	}

    }
    $display->trailer($i);

    if (@rtail) {
	my $rows = $i;
	my $ommitted = $i - $sh->{rhistory_head} - @rtail;
	    push(@{$rhist->[-1]},
		 [ "[...$ommitted rows out of $rows ommitted...]"]);
	foreach my $rowref (@rtail) {
	    push @{$rhist->[-1]}, $rowref;
	}
    }

    #$sh->{sth} = undef;
    #$sth->finish();	# drivers which need this are broken
}


sub do_do {
    my ($sh, @args) = @_;
    $sh->push_chistory;
    my $rv = $sh->{dbh}->do($sh->{current_buffer});
    print "[$rv row" . ($rv==1 ? "" : "s") . " affected]\n"
	if defined $rv;

    # XXX I question setting the buffer to '' here.
    # I may want to edit my line without having to scroll back.
    $sh->{current_buffer} = '';
}


sub do_disconnect {
    my ($sh, @args) = @_;
    return unless $sh->{dbh};
    $sh->log("Disconnecting from $sh->{data_source}.");
    eval {
	$sh->{sth}->finish if $sh->{sth};
	$sh->{dbh}->rollback unless $sh->{dbh}->{AutoCommit};
	$sh->{dbh}->disconnect;
    };
    $sh->alert("Error during disconnect: $@") if $@;
    $sh->{sth} = undef;
    $sh->{dbh} = undef;
}


sub do_connect {
    my ($sh, $dsn, $user, $pass) = @_;

    $dsn = $sh->get_data_source($dsn);
    return unless $dsn;

    $sh->do_disconnect if $sh->{dbh};

    $sh->{data_source} = $dsn;
    if (defined $user and length $user) {
	$sh->{user}     = $user;
	$sh->{password} = undef;	# force prompt below
    }

    $sh->log("Connecting to '$sh->{data_source}' as '$sh->{user}'...");
    if ($sh->{user} and !defined $sh->{password}) {
	$sh->prompt_for_password();
    }
    $sh->{dbh} = DBI->connect(
	$sh->{data_source}, $sh->{user}, $sh->{password}, {
	    AutoCommit => $sh->{init_autocommit},
	    PrintError => 0,
	    RaiseError => 1,
	    LongTruncOk => 1,	# XXX
    });
    $sh->{dbh}->trace($sh->{init_trace}) if $sh->{init_trace};
}


sub do_current {
    my ($sh, $msg, @args) = @_;
    $msg = $msg ? " $msg" : "";
    $sh->log("Current statement buffer$msg:\n" . $sh->{current_buffer});
}


sub do_trace {
    shift->{dbh}->trace(@_);
}

sub do_commit {
    shift->{dbh}->commit(@_);
}

sub do_rollback {
    shift->{dbh}->rollback(@_);
}


sub do_quit {
    my ($sh, @args) = @_;
    $sh->do_disconnect if $sh->{dbh};
    undef $sh->{term};
    exit 0;
}

# Until the alias command is working each command requires definition.
sub do_exit { shift->do_quit(@_); }

sub do_clear {
    my ($sh, @args) = @_;
    $sh->{current_buffer} = '';
}


sub do_redo {
    my ($sh, @args) = @_;
    $sh->{current_buffer} = $sh->{prev_buffer} || '';
    $sh->run_command('go') if $sh->{current_buffer};
}


sub do_chistory {
    my ($sh, @args) = @_;
    $sh->print_list($sh->{chistory});
}

sub do_history {
    my ($sh, @args) = @_;
    for(my $i = 0; $i < @{$sh->{chistory}}; $i++) {
	print $i+1, ":\n", $sh->{chistory}->[$i], "--------\n";
	foreach my $rowref (@{$sh->{rhistory}[$i]}) {
	    print "    ", join(", ", @$rowref), "\n";
	}
    }
}

sub do_rhistory {
    my ($sh, @args) = @_;
    for(my $i = 0; $i < @{$sh->{rhistory}}; $i++) {
	print $i+1, ":\n";
	foreach my $rowref (@{$sh->{rhistory}[$i]}) {
	    print "    ", join(", ", @$rowref), "\n";
	}
    }
}


sub do_get {
    my ($sh, $num, @args) = @_;
    if (!$num || $num !~ /^\d+$/ || !defined($sh->{chistory}->[$num-1])) {
	$sh->err("No such command number '$num'. Use /chistory to list previous commands.");
	return;
    }
    $sh->{current_buffer} = $sh->{chistory}->[$num-1];
    $sh->print_buffer($sh->{current_buffer});
}


sub do_perl {
    my ($sh, @args) = @_;
	$DBI::Shell::eval::dbh = $sh->{dbh};
    eval "package DBI::Shell::eval; $sh->{current_buffer}";
    if ($@) { $sh->err("Perl failed: $@") }
    $sh->run_command('clear');
}


sub do_edit {
    my ($sh, @args) = @_;

    $sh->run_command('get', '', $&) if @args and $args[0] =~ /^\d+$/;
    $sh->{current_buffer} ||= $sh->{prev_buffer};
	    
    # Find an area to write a temp file into.
    my $tmp_dir = $ENV{DBISH_TMP} || # Give people the choice.
	    $ENV{TMP}  ||            # Is TMP set?
	    $ENV{TEMP} ||            # How about TEMP?
	    $ENV{HOME} ||            # Look for HOME?
	    $ENV{HOMEDRIVE} . $ENV{HOMEPATH} || # Last env checked.
	    ".";       # fallback: try to write in current directory.
    my $tmp_file = "$tmp_dir/dbish$$.sql";

    local (*FH);
    open(FH, ">$tmp_file") ||
	    $sh->err("Can't create $tmp_file: $!\n", 1);
    print FH $sh->{current_buffer} if defined $sh->{current_buffer};
    close(FH) || $sh->err("Can't write $tmp_file: $!\n", 1);

    my $command = "$sh->{editor} $tmp_file";
    system($command);

    # Read changes back in (editor may have deleted and rewritten file)
    open(FH, "<$tmp_file") || $sh->err("Can't open $tmp_file: $!\n");
    $sh->{current_buffer} = join "", <FH>;
    close(FH);
    unlink $tmp_file;

    $sh->run_command('current');
}


sub do_drivers {
    my ($sh, @args) = @_;
    $sh->log("Available drivers:");
    my @drivers = DBI->available_drivers;
    foreach my $driver (sort @drivers) {
	$sh->log("\t$driver");
    }
}


sub do_type_info {
    my ($sh, @args) = @_;
    my $dbh = $sh->{dbh};
    my $ti = $dbh->type_info_all;
    my $ti_cols = shift @$ti;
    my @names = sort { $ti_cols->{$a} <=> $ti_cols->{$b} } keys %$ti_cols;
    my $sth = $sh->prepare_from_data("type_info", $ti, \@names);
    $sh->sth_go($sth, 0);
}

sub do_describe {
    my ($sh, $tab, @argv) = @_;
	$sh->log( "Describle: $tab" );
	my $dbh = $sh->{dbh};
	my $sql = qq{select * from $tab where 1 = 0};
	my $sth = $dbh->prepare( $sql );
	$sth->execute;
	my $cnt = $#{$sth->{NAME}};  #
    	my @names = qw{NAME TYPE NULLABLE};
	my @ti;
	#push( @j, join( "\t", qw{NAME TYPE PRECISION SCALE NULLABLE}));
	for ( my $c = 0; $c <= $cnt; $c++ ) {
		push( my @j, $sth->{NAME}->[$c] || 0 );
		my $m = $dbh->type_info($sth->{TYPE}->[$c]);
		my $s;
		if (ref $m eq 'HASH') {
			$s = $m->{TYPE_NAME};
		} elsif (not defined $m) {
			 $s = q{undef } . $sth->{TYPE}->[$c];
		} else {
			warn "describe: can't parse data ($m) from type_info!";
		}

		if (defined $sth->{PRECISION}->[$c]) {
			$s .= "(" . $sth->{PRECISION}->[$c] || '';
			$s .= "," . $sth->{SCALE}->[$c] 
			if ( defined $sth->{SCALE}->[$c] 
				and $sth->{SCALE}->[$c] ne 0);
			$s .= ")";
		}
		push(@j, $s,
			 $sth->{NULLABLE}->[$c] ne 1? qq{N}: qq{Y} );
		push(@ti,\@j);
	}
	$sth->finish;
	$sth = $sh->prepare_from_data("describe", \@ti, \@names);
	$sh->sth_go($sth, 0);
}


sub prepare_from_data {
    my ($sh, $statement, $data, $names, %attr) = @_;
    my $sponge = DBI->connect("dbi:Sponge:","","",{ RaiseError => 1 });
    my $sth = $sponge->prepare($statement, { rows=>$data, NAME=>$names, %attr });
    return $sth;
}


# Do option: sets or gets an option
sub do_option {
    my ($sh, @args) = @_;

    unless (@args) {
	foreach my $opt (sort keys %{ $sh->{options}}) {
	    my $value = (defined $sh->{$opt}) ? $sh->{$opt} : 'undef';
	    $sh->log(sprintf("%20s: %s", $opt, $value));
	}
	return;
    }

    my $options = Text::Abbrev::abbrev(keys %{$sh->{options}});

    # Expecting the form [option=value] [option=] [option]
    foreach my $opt (@args) {
	my ($opt_name, $value) = $opt =~ /^\s*(\w+)(?:=(.*))?/;
	$opt_name = $options->{$opt_name} || $opt_name if $opt_name;
	if (!$opt_name || !$sh->{options}->{$opt_name}) {
	    $sh->log("Unknown or ambiguous option name '$opt_name' (use name=value format)");
	    next;
	}
	my $crnt = (defined $sh->{$opt_name}) ? $sh->{$opt_name} : 'undef';
	my $log;
	if (not defined $value) {
	    $log = "$opt_name=$crnt";
	}
	else {
	    $log = "/option $opt_name=$value  (was $crnt)";
	    $sh->{$opt_name} = ($value eq 'undef') ? undef : $value;
	}
	$sh->log($sh->{command_prefix}."option $log");
    }
}


sub do_table_info {
    my ($sh, @args) = @_;
    my $dbh = $sh->{dbh};
    my $sth = $dbh->table_info(@args);
    unless(ref $sth) {
	print "Driver has not implemented the table_info() method, ",
		"trying tables()\n";
	my @tables = $dbh->tables(@args); # else try list context
	unless (@tables) {
	    print "No tables exist ",
		  "(or driver hasn't implemented the tables method)\n";
	    return;
	}
	$sth = $sh->prepare_from_data("tables",
		[ map { [ $_ ] } @tables ],
		[ "TABLE_NAME" ]
	);
    }
    $sh->sth_go($sth, 0);
}



1;
__END__

=head1 TO DO

Proper docs - but not yet, too much is changing.

"/source file" command to read command file.
Allow to nest via stack of command file handles.
Add command log facility to create batch files.

Commands:
	load (query?) from file
	save (query?) to file

Use Data::ShowTable if available.

Define DBI::Shell plug-in semantics.
	Implement import/export as plug-in module

Clarify meaning of batch mode

Completion hooks

Set/Get DBI handle attributes

Portability

Emulate popular command shell modes (Oracle, Ingres etc)?

=head1 COMMANDS

Many commands - few documented, yet!

=over 4

=item help

  /help

=item chistory

  /chistory          (display history of all commands entered)
  /chistory | YourPager (display history with paging)

=item clear

  /clear             (Clears the current command buffer)

=item commit

  /commit            (commit changes to the database)

=item connect

  /connect           (pick from available drivers and sources)
  /connect dbi:Oracle (pick source from based on driver)
  /connect dbi:YourDriver:YourSource i.e. dbi:Oracle:mysid

Use this option to change userid or password.

=item current

  /current            (Display current statement in the buffer)

=item do

  /do                 (execute the current (non-select) statement)

	dbish> create table foo ( mykey integer )
	dbish> /do

	dbish> truncate table OldTable /do (Oracle truncate)

=item drivers

  /drivers            (Display available DBI drivers)

=item edit

  /edit               (Edit current statement in an external editor)

Editor is defined using the enviroment variable $VISUAL or
$EDITOR or default is vi.  Use /option editor=new editor to change
in the current session.

To read a file from the operating system invoke the editor (/edit)
and read the file into the editor buffer.

=item exit

  /exit              (Exits the shell)

=item get

  /get               (Retrieve a previous command to the current buffer)

=item go

  /go                (Execute the current statement)

Run (execute) the statement in the current buffer.  This is the default
action if the statement ends with /

	dbish> select * from user_views/

	dbish> select table_name from user_tables
	dbish> where table_name like 'DSP%'
	dbish> /

	dbish> select table_name from all_tables/ | more

=item history

  /history            (Display combined command and result history)
  /history | more

=item option

  /option [option1[=value]] [option2 ...]
  /option            (Displays the current options)
  /option   MyOption (Displays the value, if exists, of MyOption)
  /option   MyOption=4 (defines and/or sets value for MyOption)

=item perl

  /perl               (Evaluate the current statement as perl code)

=item quit

  /quit               (Leaves shell.  Same as exit)

=item redo

  /redo               (Re-execute the previously executed statement)

=item rhistory

  /rhistory           (Display result history)

=item rollback

  /rollback           (rollback changes to the database)

For this to be useful, turn the autocommit off. /option autocommit=0

=item table_info

  /table_info         (display all tables that exist in current database)
  /table_info | more  (for paging)

=item trace

  /trace              (set DBI trace level for current database)

Adjust the trace level for DBI 0 - 4.  0 off.  4 is lots of information.
Useful for determining what is really happening in DBI.  See DBI.

=item type_info

  /type_info          (display data types supported by current server)

=back

=head1 AUTHORS and ACKNOWLEDGEMENTS

The DBI::Shell has a long lineage.

It started life around 1994-1997 as the pmsql script written by Andreas
König. Jochen Wiedmann picked it up and ran with it (adding much along
the way) as I<dbimon>, bundled with his DBD::mSQL driver modules. In
1998, around the time I wanted to bundle a shell with the DBI, Adam
Marks was working on a dbish modeled after the Sybase sqsh utility.

Wanting to start from a cleaner slate than the feature-full but complex
dbimon, I worked with Adam to create a fairly open modular and very
configurable DBI::Shell module. Along the way Tom Lowery chipped in
ideas and patches. As we go further along more useful code and concepts
from Jochen's dbimon is bound to find it's way back in.

=head1 COPYRIGHT

The DBI::Shell module is Copyright (c) 1998 Tim Bunce. England.
All rights reserved. Portions are Copyright by Jochen Wiedmann,
Adam Marks and Tom Lowery.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
