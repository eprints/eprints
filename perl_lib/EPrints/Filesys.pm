package EPrints::Filesys;

=head1 NAME

B<EPrints::Filesys> - virtual file system for EPrints

=head1 METHODS

=cut

use strict;
use warnings;

use Carp;
use Filesys::Virtual;
use Filesys::Virtual::Plain;
use Time::Local;
use Fcntl ':mode';
use constant DEBUG => 1;

our @ISA = qw( Filesys::Virtual );

# Here's the EPrints virtual file system
our @ROOT_FILESYS = (
	qr{/} => {
		is_dir => sub { 1 },
		can_write => sub { 0 },
		can_delete => sub { 0 },
		exists => sub { 1 },
		size => sub { 4096 },
		modtime => sub { time() },
		list => \&list_root,
	},
	qr{/inbox} => {
		is_dir => sub { 1 },
		can_write => sub { 0 },
		can_delete => sub { 0 },
		exists => sub { 1 },
		size => sub { 4096 },
		modtime => sub { time() },
		list => \&list_inbox_eprints,
	},
);

our @PUBLIC_FILESYS = (
	qr{/view} => {
		is_dir => sub { 1 },
		can_write => sub { 0 },
		can_delete => sub { 0 },
		exists => sub { 1 },
		size => sub { 4096 },
		modtime => sub { time() },
		list => \&list_browse_views,
	},
);

our @USER_FILESYS = (
	qr{/inbox/([^/]+)} => {
		is_dir => sub { 1 },
		can_write => sub { defined $_[0]->{current_user} },
		can_delete => \&can_change_eprint,
		exists => sub { defined &retrieve_eprint(@_) },
		size => sub { 4096 },
		modtime => sub { $_[0]->get_object_mtime( &retrieve_eprint(@_) ) },
		list => \&list_documents,
		delete => \&delete_eprint,
		mkdir => \&make_eprint,
		rename => \&rename_eprint,
		open_write => \&open_write_eprint,
		close_write => \&close_write_file,
	},
#	qr{/inbox/([^/]+)/export/?(.*)/eprint_.*} => {
#		is_dir => sub { 0 },
#		can_write => sub { 0 },
#		can_delete => sub { 1 },
#		exists => sub { 1 },
#		size => \&eprint_export_size,
#		modtime => sub { $_[0]->get_object_mtime( &retrieve_eprint(@_) ) },
#		open_read => \&open_eprint_export,
#		mime_type => \&eprint_export_mime_type,
#		delete => \&virtual_delete,
#	},
#	qr{/inbox/([^/]+)/export/?(.*)} => {
#		is_dir => sub { 1 },
#		can_write => sub { 0 },
#		can_delete => sub { 1 },
#		exists => sub { 1 },
#		size => sub { 4096 },
#		modtime => sub { time() },
#		list => \&list_eprint_exports,
#		delete => \&virtual_delete,
#	},
	qr{/inbox/([^/]+)/([^/]+)} => {
		is_dir => sub { 1 },
		can_write => sub { 1 },
		can_delete => sub { 1 },
		exists => sub { defined &retrieve_document(@_) },
		size => sub { 4096 },
		modtime => sub { $_[0]->get_object_mtime( &retrieve_document(@_) ) },
		list => \&list_document_contents,
		open_write => \&open_write_document,
		close_write => \&close_write_file,
		delete => \&delete_document,
		mkdir => \&make_document,
		rename => \&rename_document,
	},
	qr{/inbox/([^/]+)/(\d+)/([^/]+)} => {
		is_dir => sub { 0 },
		can_write => sub { 1 },
		can_delete => sub { 1 },
		exists => sub { defined &retrieve_file(@_) },
		size => sub { $_[0]->get_object_size( &retrieve_file(@_) ) },
		modtime => sub { $_[0]->get_object_mtime( &retrieve_file(@_) ) },
		open_read => \&open_file,
		open_write => \&open_write_file,
		close_write => \&close_write_file,
		delete => \&delete_file,
		rename => \&rename_file,
	},
);

our @TEST_FILESYS = (
	qr{/test} => {
		is_dir => sub { 1 },
		can_write => sub { 1 },
		can_delete => sub { 1 },
		exists => sub { 1 },
		size => sub { $_[0]->{test}->size( "/" ) },
		modtime => sub { time() },
		list => sub { $_[0]->{test}->list( "/" ) },
	},
	qr{/test(/.+)} => {
		is_dir => sub { $_[0]->{test}->test( "d", $_[1]->[0] ) },
		can_write => sub { 1 },
		can_delete => sub { 1 },
		exists => sub { $_[0]->{test}->test( "e", $_[1]->[0] ) },
		size => sub { $_[0]->{test}->size( $_[1]->[0] ) },
		modtime => sub { time() },
		list => sub { $_[0]->{test}->list( $_[1]->[0] ) },
		mkdir => sub { $_[0]->{test}->mkdir( $_[1]->[0] ) },
		open_read => sub { $_[0]->{test}->open_read( $_[1]->[0] ) },
		close_read => sub { $_[0]->{test}->close_read( $_[2] ) },
		open_write => sub { $_[0]->{test}->open_write( $_[1]->[0], $_[2] ) },
		close_write => sub { $_[0]->{test}->close_write( $_[3] ) },
		delete => sub { $_[0]->{test}->rmdir( $_[1]->[0] ) },
	},
);

our %READ_SETTINGS;
our %WRITE_SETTINGS;

=head2 Class Methods

=over 4

=cut

=item EPrints::FileSys->new( ... )

Creates a new EPrints virtual file system object. Requires B<session> argument.

=cut

sub new
{
	my( $class, $self ) = @_;

binmode(STDERR, ":utf8");

	$self = bless $self, $class;

	Carp::croak "Requires session argument" unless $self->{session};

	$self->{root_path} ||= "";
	$self->{cwd} = [];
	$self->{filesys} = [];

	push @{$self->{filesys}}, @ROOT_FILESYS;

#	$self->{test} = Filesys::Virtual::Plain->new({
#		root_path => "/tmp",
#		});
#	push @{$self->{filesys}}, @TEST_FILESYS;

	if( defined $self->{current_user} )
	{
		$self->register_user( $self->{current_user} );
	}

	$self->register_browse_views();

	return $self;
}

sub _escape_filename
{
	my( $fn ) = @_;
	$fn =~ s#([=/&\:\\])#sprintf("=%02x",ord($1))#seg;
	return $fn;
}

sub _unescape_filename
{
	my( $fn ) = @_;
	$fn =~ s#=(..)#chr(hex($1))#seg;
	$fn;
}

sub _dir_entry
{
	my( $self, $name, $mode, $owner, $group, $size, $mtime ) = @_;

	my( $day, $mm, $dd, $time, $yr ) = (gmtime($mtime) =~
		m/(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/ );

	return sprintf("%1s%9s %4s %-8s %-8s %8s %3s %2s %5s %s",
			substr($mode,0,1),
			substr($mode,1),
			2, # nlinks
			$owner,
			$group,
			$size,
			$mm,
			$dd,
			((gmtime())[5]+1900 eq $yr) ? substr($time,0,5) : $yr,
			_escape_filename($name)
		);
}

sub _sanitise_filename
{
	my( $self, $path ) = @_;

	my @dir;
	for($self->_split_path( $path ))
	{
		if( $_ eq ".." )
		{
			pop @dir;
		}
		elsif( $_ eq "." or $_ eq "" )
		{
		}
		else
		{
			push @dir, $_;
		}
	}

	my $filename = pop @dir;

	return( $self->_join_path( @dir ), $filename );
}

sub _split_path
{
	my( $path ) = $_[1];
	$path =~ s#^\s*/\s*##;
	return split m{/}, $path;
}

sub _join_path
{
	return '/' . join '/', @_[1..$#_];
}

sub _resolve_path
{
	my( $self, $path ) = @_;

	return $self->cwd if not defined $path or $path !~ /\S/;

	$path =~ s/^$self->{root_path}//;

	my @dir;
	if( $path !~ m{^/} )
	{
		@dir = @{$self->{cwd}};
	}
	for($self->_split_path( $path ))
	{
		if( $_ eq ".." )
		{
			pop @dir;
		}
		elsif( $_ eq "." or $_ eq "" )
		{
		}
		else
		{
			push @dir, $_;
		}
	}

	return $self->_join_path( @dir );
}

sub _resolve_symlinks
{
	my( $self, $path, @stack ) = @_;

	my( $target, $vfs ) = $self->_vfs_match( $path );
	return( $path, @stack ) unless defined $vfs;
	return( $target, $vfs, @stack ) if $vfs->get_value( "type" ) eq "deletion";

	if( grep { $_->get_value( "path" ) eq $vfs->get_value( "path" ) } @stack )
	{
		$vfs->remove();
		EPrints::abort "Circular symlink relation resulted in symlink removal";
	}

print STDERR "\tSYMLINK(".$vfs->get_value( "path" ) . ") => $target\n" if DEBUG;
	return $self->_resolve_symlinks( $target, $vfs, @stack );
}

sub _get_handler
{
	my( $self, $path ) = @_;

print STDERR "_GET_HANDLER(".(defined $path ? $path : "null").")\n" if DEBUG;

	$path = $self->_resolve_path( $path );

	my( $real_path, @stack ) = $self->_resolve_symlinks( $path );

	if( scalar @stack && $stack[0]->get_value( "type" ) eq "deletion" )
	{
print STDERR "\tSYMLINK(".$stack[0]->get_value( "path" ) . ") => DELETED\n" if DEBUG;
		return( undef, [], \@stack );
	}

	my( $handler, $args );

	for(my $i = 0; $i < @{$self->{filesys}}; $i+=2)
	{
		my $re = $self->{filesys}->[$i];
		if( $real_path =~ m/^$re$/ )
		{
print STDERR "\tMATCHES($re)\n" if DEBUG;
			$handler = $self->{filesys}->[$i+1];
			$args = [$1,$2,$3,$4,$5,$6,$7,$8,$9];
			last;
		}
	}

	return( $handler, $args, \@stack );
}

sub _vfs_create
{
	my( $self, $type, $path, $tgt ) = @_;

	my $session = $self->{session};

	my $vfs = EPrints::DataObj::VFS->create_from_data(
		$session,
		{
			path => $path,
			userid => $self->{current_user}->get_id,
			type => "directory",
			target => $tgt,
		},
		$session->get_repository->get_dataset( "vfs" )
		);

	return $vfs;
}

# This method searches the sym links to find the target location
sub _vfs_match
{
	my( $self, $path ) = @_;

	$path = $self->_resolve_path( $path );

	my @parts = $self->_split_path( $path );

	for(my $i = 0; $i < @parts; ++$i)
	{
		my $path = $self->_join_path( @parts[0..$i] );

		my $searchexp = EPrints::Search->new(
			session => $self->{session},
			dataset => $self->{session}->get_repository->get_dataset( "vfs" ),
			filters => [
				{ meta_fields => [qw( userid )], match => "EX", value => $self->{current_user}->get_id, describe => 0 },
				{ meta_fields => [qw( path )], match => "EX", value => $path, describe => 0 },
			]
		);
		my $list = $searchexp->perform_search;
		my( $vfs ) = $list->get_records( 0, 1 );
		$list->dispose;
		if( defined $vfs )
		{
			my $target = $self->_join_path(
				$self->_split_path($vfs->get_value( "target" )),
				@parts[($i+1)..$#parts]
				);
			return( $target, $vfs );
		}
	}

	return ();
}

# %symlinks = _vfs_list( $path [, $deep ] )
#
# Returns a hash of symlinks that are below $path. If $deep is true returns
# all symlinks that are below $path.
#
# Hash is keyed by the symlink's path with $path stripped from the front.

sub _vfs_list
{
	my( $self, $path, $deep ) = @_;

	$path = $self->_resolve_path( $path );

	my $searchexp = EPrints::Search->new(
		session => $self->{session},
		dataset => $self->{session}->get_repository->get_dataset( "vfs" ),
		filters => [
			{ meta_fields => [qw( userid )], match => "EX", value => $self->{current_user}->get_id, describe => 0 },
		]
	);
	my $list = $searchexp->perform_search;
	my %matches;
	$list->map(sub {
		my( undef, undef, $vfs ) = @_;
		my $match = $vfs->get_value( "path" );
		return unless $match =~ s#^$path/##;
		return if not $deep and $match =~ m#/#;

		my $target = $vfs->get_value( "target" );
		my( $handler, $args ) = $self->_get_handler( $target );
		if( not defined $handler or not &{$handler->{exists}}( $self, $args ) )
		{
			$vfs->remove;
		}
		else
		{
			$matches{$match} = $vfs;
		}
	});
	$list->dispose;

	return %matches;
}

sub datetime_to_unixtime
{
	unless( $_[0] =~ /^(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/ )
	{
		EPrints::abort "Expected yyyymmddHHMMSS, got $_[0]";
	}
	return Time::Local::timegm($6,$5,$4,$3,$2-1,$1-1900);
}

=back

=head2 Virtual::Filesys Methods

=over 4

=cut


=item $filesys->login( USERNAME, PASSWORD [, BECOME ] )

Log in using USERNAME and PASSWORD.

=cut

sub login
{
	my( $self, $username, $password, $become ) = @_;

	if( !$self->{session}->valid_login( $username, $password ) )
	{
		return 0;
	}

	my $user = EPrints::DataObj::User::user_with_username( $self->{session}, $username );

	$self->register_user( $user );

	return 1;
}

=item $cwd = $filesys->cwd( [ CWD ] )

Returns the current working directory.

=cut

sub cwd
{
	my( $self, $cwd ) = @_;

	if( 2 == @_ )
	{
		$self->chdir( $cwd );
	}

	return $self->_join_path( @{$self->{cwd}} );
}

=item $filesys->chmod

Unimplemented.

=cut

sub chmod
{
}

=item $filesys->modtime( PATH )

Returns the modification time of the file in seconds since Unix epoch.

=cut

sub modtime
{
	my( $self, $path ) = @_;

	my $default = "19700101000000";

	my( $handler, $args ) = $self->_get_handler( $path );
	return $default unless defined $handler;
	return $default unless &{$handler->{exists}}( $self, $args );

	my $secs = defined $handler->{modtime} ?
		&{$handler->{modtime}}( $self, $args ) :
		time();

	my @datetime = gmtime( $secs );
	$datetime[4]++;
	$datetime[5] += 1900;

	return( 1, join("",reverse @datetime));
}

=item $filesys->size( PATH )

Returns the size of PATH in bytes.

=cut

sub size
{
	my( $self, $path ) = @_;

	my( $handler, $args ) = $self->_get_handler( $path );
	return unless defined $handler;
	return unless &{$handler->{exists}}( $self, $args );

	return &{$handler->{size}}( $self, $args );
}

=item $filesys->delete( PATH )

Delete the filename identified by CWD + PATH.

=cut

sub delete
{
	my( $self, $path ) = @_;

	my( $handler, $args ) = $self->_get_handler( $path );
	return 0 unless defined $handler;
	return 0 unless !&{$handler->{is_dir}}( $self, $args );
	return 0 unless &{$handler->{can_delete}}( $self, $args );
	return 0 unless &{$handler->{exists}}( $self, $args );

	return &{$handler->{delete}}( $self, $args, $path );
}

=item $filename->chdir( PATH )

Change the working path to PATH.

=cut

sub chdir
{
	my( $self, $path ) = @_;

	return 1 if !defined $path or $path !~ /\S/;

	$path = $self->_resolve_path( $path );

	# check this is a valid directory
	my( $handler, $args ) = $self->_get_handler( $path );
	return 0 unless defined $handler;
	return 0 unless &{$handler->{is_dir}}( $self, $args );
	return 0 unless &{$handler->{exists}}( $self, $args );

	@{$self->{cwd}} = $self->_split_path( $path );

	return 1;
}

=item $filesys->mkdir( PATH )

Make a path of PATH.

=cut

sub mkdir
{
	my( $self, $path ) = @_;

print STDERR "MKDIR($path)\n" if DEBUG;

	my( $handler, $args ) = $self->_get_handler( $path );
	return 0 unless defined $handler;
	return 0 unless defined $handler->{'mkdir'};
	return 0 unless &{$handler->{can_write}}( $self, $args );

	$path = $self->_resolve_path( $path );
	my( $real_path ) = $self->_resolve_symlinks( $path );

	return &{$handler->{mkdir}}( $self, $args, $real_path );
}

=item $filesys->rmdir( PATH )

Like delete but can also be used with directories.

=cut

sub rmdir
{
	my( $self, $path ) = @_;

print STDERR "RMDIR($path)\n" if DEBUG;

	my( $handler, $args, $stack ) = $self->_get_handler( $path );
	return 0 unless defined $handler;
	return 0 unless &{$handler->{can_delete}}( $self, $args );
	return 0 unless &{$handler->{exists}}( $self, $args );

	my $r = &{$handler->{delete}}( $self, $args, $path );
	return $r unless $r;

	$path = $self->_resolve_path( $path );
	my( $real_path ) = $self->_resolve_symlinks( $path );

	# Remove any contained symlinks
	my %symlinks = $self->_vfs_list( $real_path, 1 );

	foreach my $vfs (values %symlinks)
	{
		$vfs->remove;
	}

	# If the thing deleted was a symlink, remove it
	if( 
		defined($stack->[0]) &&
		$stack->[0]->get_value( "target" ) eq $real_path
	  )
	{
		$stack->[0]->remove();
	}

	return 1;
}

=item $filesys->list( [ PATH ] )

List items contained in CWD + PATH.

=cut

sub list
{
	my( $self, $path ) = @_;

print STDERR "LIST(".(defined $path ? $path : "null").")\n" if DEBUG;

	my( $handler, $args, $stack ) = $self->_get_handler( $path );
	return () unless defined $handler;
	return () unless &{$handler->{is_dir}}( $self, $args );
	return () unless &{$handler->{exists}}( $self, $args );

	# We need to find the real path to find symlinks
	my $vfs = $stack->[0];
	my $real_path = defined $vfs ? $vfs->get_value( "target" ) : $path;

	my %symlinks = $self->_vfs_list( $real_path );
	my %targets = map { $_->get_value( "target" ) => $_ } values %symlinks;

	my %files = &{$handler->{list}}( $self, $args, sub { $_[0] } );

#	my @cwd = @{$self->{cwd}};
#	$self->chdir( $path );

	foreach my $name (keys %symlinks)
	{
		my $target = $symlinks{$name}->get_value( "target" );
		$target =~ s# ^.*/ ##x;
		# Strip out targets of symlinks
		delete $files{$target} if exists $files{$target};
		# Strip out "deleted" paths
		delete $symlinks{$name}
			if( $symlinks{$name}->get_value( "type" ) eq "deletion" );
	}
#	foreach my $name (keys %files)
#	{
#		my $full_path = $self->_resolve_path( $name );
#print STDERR "Looking for [$full_path] ... ".(join(',',keys %targets))."\n";
#		if( exists($targets{$full_path}) )
#		{
#			delete $files{$name};
#		}
#	}
	
#	@{$self->{cwd}} = @cwd;

	my @dirs;
	push @dirs, values(%files);
	push @dirs, keys %symlinks;

print STDERR "\tdirs=@dirs\n";

	return @dirs;
}

=item $filesys->list_details( [ PATH ] )

List items contained in CWD + PATH, with full detail.

=cut

sub list_details
{
	my( $self, $path ) = @_;

	my( $handler, $args ) = $self->_get_handler( $path );
	return () unless defined $handler;
	return () unless &{$handler->{is_dir}}( $self, $args );
	return () unless &{$handler->{exists}}( $self, $args );

	return &{$handler->{list}}( $self, $args, sub { $self->_dir_entry( @_ ) } );
}

=item $filesys->stat

Unimplemented.

=cut

sub stat
{
	my( $self, $path ) = @_;

print STDERR "STAT($path)\n" if DEBUG;

	my( $handler, $args ) = $self->_get_handler( $path );
	return () unless defined $handler;
	return () unless &{$handler->{exists}}( $self, $args );

	# fake mode
	my $mode = 0644;
	if( &{$handler->{is_dir}}( $self, $args ) )
	{
		$mode |= S_IFDIR;
		$mode |= 0111;
	}
	else
	{
		$mode |= S_IFREG;
	}

	my $size = &{$handler->{size}}( $self, $args );
	my $mtime = defined $handler->{modtime} ?
		&{$handler->{modtime}}( $self, $args ) :
		time();

	my @stat = (
		0, #device
		0, #inode
		$mode, #mode
		0, #nlink
		0, #uid
		0, #gid,
		0, #rdev
		$size, #size
		$mtime, #atime
		$mtime, #mtime
		$mtime, #ctime
		0, #blksize
		0 #blocks
		);

	return @stat;
}

=item $filesys->test( TEST, PATH )

Returns where TEST is true of PATH, where TEST is a file test.

=cut

sub test
{
	my( $self, $test, $path ) = @_;

print STDERR "TEST($test,$path)\n" if DEBUG;

	my( $handler, $args ) = $self->_get_handler( $path );
	return 0 unless defined $handler;
	return 0 unless &{$handler->{exists}}( $self, $args );

	if( $test eq "r" or $test eq "e" )
	{
print STDERR "\t=exists\n" if DEBUG;
		return 1; # exists
	}
	elsif( $test eq "f" )
	{
print STDERR "\t=file\n" if DEBUG;
		return !&{$handler->{is_dir}}( $self, $args );
	}
	elsif( $test eq "d" )
	{
print STDERR "\t=directory\n" if DEBUG;
		return &{$handler->{is_dir}}( $self, $args );
	}
	else
	{
		warn "Unsupported test case '$test' on path '$path'";
		return 0;
	}
}

=item $filesys->open_read( PATH, [ opts? ] )

Open a file for reading, returns a file handle.

=cut

sub open_read
{
	my( $self, $path, @opts ) = @_;

	my( $handler, $args ) = $self->_get_handler( $path );
	return undef unless defined $handler;
	return undef unless !&{$handler->{is_dir}}( $self, $args );
	return undef unless &{$handler->{exists}}( $self, $args );
	return undef unless defined $handler->{open_read};

	my $fh = &{$handler->{open_read}}( $self, $args );

	$READ_SETTINGS{$fh} = {
		handler => $handler,
		args => $args
	};

	return $fh;
}

=item $filesys->close_read( fh )

=cut

sub close_read
{
	my( $self, $fh ) = @_;

	my $settings = delete $READ_SETTINGS{$fh};

	return unless defined $settings->{handler}->{close_read};

	&{$settings->{handler}->{close_read}}(
		$self,
		$settings->{args},
		$fh
	);
}

=item $filesys->open_write( PATH [, APPEND ] )

Returns a file handle to write to.

=cut

sub open_write
{
	my( $self, $path, $append ) = @_;

print STDERR "OPEN_WRITE($path)\n";

	my( $handler, $args ) = $self->_get_handler( $path );
	return undef unless defined $handler;
	return undef unless &{$handler->{can_write}}( $self, $args );
	return undef unless defined $handler->{open_write};

	my $fh = &{$handler->{open_write}}( $self, $args, $append );

	$WRITE_SETTINGS{$fh} = {
		handler => $handler,
		args => $args,
		append => $append,
	};

	return $fh;
}

=item $filesys->close_write( fh )

=cut

sub close_write
{
	my( $self, $fh ) = @_;

	my $settings = delete $WRITE_SETTINGS{$fh};

	&{$settings->{handler}->{close_write}}(
		$self,
		$settings->{args},
		$settings->{append},
		$fh
	);
}

=item $filesys->seek

Unimplemented.

=cut

sub seek
{
}

=item $filesys->utime

Unimplemented

=cut

sub utime
{
}

=back

=head2 EPrints Extended Methods

=over 4

=cut

=item $mime_type = $vfs->mime_type( $path )

Returns the mime type of the file at $path. Returns undef if path doesn't exist or is a directory.

=cut

sub mime_type
{
	my( $self, $path ) = @_;

print STDERR "MIME_TYPE($path)\n" if DEBUG;

	my( $handler, $args ) = $self->_get_handler( $path );
	return undef unless defined $handler;
	return undef unless &{$handler->{exists}}( $self, $args );
	return undef if &{$handler->{is_dir}}( $self, $args );
	return "application/octet-stream" unless defined $handler->{mime_type};

	return &{$handler->{mime_type}}( $self, $args );
}

=item $ok = $vfs->rename( $src, $tgt )

Move $src to $tgt. Returns 1 if successful.

If $tgt already exists the rename will fail.

=cut

sub rename
{
	my( $self, $path, $tgt ) = @_;

print STDERR "RENAME($path,$tgt)\n" if DEBUG;

	$path = $self->_resolve_path( $path );
	$tgt = $self->_resolve_path( $tgt );

	# Can't move root
	return 0 if $path eq "/";

	# Move to itself?
	return 1 if $path eq $tgt;

	my( $handler, $args, $stack ) = $self->_get_handler( $path );
	return 0 unless defined $handler;
	return 0 unless &{$handler->{exists}}( $self, $args );
	return 0 unless &{$handler->{can_delete}}( $self, $args );
	return 0 unless defined $handler->{rename};

	# Resolve any symlinks in the pathing
	my( $real_path ) = $self->_resolve_symlinks( $path );
	my( $real_tgt ) = $self->_resolve_symlinks( $tgt );

	my $r = &{$handler->{rename}}( $self, $args, $real_path, $real_tgt );
	return 0 unless $r;

	# If the file renamed was a symlink, remove it
	if( scalar @$stack && $stack->[0]->get_value( "target" ) eq $real_path )
	{
		$stack->[0]->remove();
	}

	return 1;
}

=back

=head2 Misc. File System Methods

=over 4

=cut

###
#    Methods below are file system location-specific
###

sub list_root
{
	my( $self, $args, $f ) = @_;

	my @entries;
	push @entries, inbox => &$f(
		"inbox",
		"drwxr-xr-x",
		"root",
		"root",
		0,
		time() );
#	push @entries, test => &$f(
#		"test",
#		"drwxr-xr-x",
#		"root",
#		"root",
#		0,
#		time() );
	push @entries, view => &$f(
		"view",
		"drwxr-xr-x",
		"root",
		"root",
		0,
		time() );

	return @entries;
};

sub register_user
{
	my( $self, $user ) = @_;

	$self->{current_user} = $user;

	push @{$self->{filesys}}, @USER_FILESYS;
}

sub get_object_size
{
	my( $self, $object ) = @_;

	return 0 unless defined $object;

	if( $object->isa( "EPrints::DataObj::File" ) )
	{
		return $object->get_value( "filesize" );
	}
	else
	{
		return 4096; # directory
	}
}

sub get_object_mtime
{
	my( $self, $object ) = @_;

	return 0 unless defined $object;

	my $field = $object->get_dataset->get_datestamp_field();

	return 0 unless defined $field;

	my $datetime = $object->get_value( $field->get_name );
	$datetime =~ /(\d+)\D(\d{2})\D(\d{2})\D(\d{2})\D(\d{2})\D(\d{2})/;
	my $time = Time::Local::timegm($6,$5,$4,$3,$2-1,$1-1900);

	return $time;
}

sub virtual_delete
{
	my( $self, $args, $path ) = @_;

print STDERR "VIRTUAL_DELETE($path)\n";

	my $user = $self->{current_user} or return 0;
	my $session = $self->{session};

	$path = $self->_resolve_path( $path );

	my $vfs = EPrints::DataObj::VFS->create_from_data(
		$session,
		{
			path => $path,
			userid => $user->get_id,
			type => "deletion",
			target => $path,
		},
		$session->get_repository->get_dataset( "vfs" )
		);

	return 1;
}

sub list_inbox_eprints
{
	my( $self, $args, $f ) = @_;

	my $user = $self->{current_user} or return ();

	my $dataset = $self->{session}->get_repository->get_dataset( "inbox" );

	my $searchexp = EPrints::Search->new(
		session => $self->{session},
		dataset => $dataset,
		filters => [
			{ meta_fields => [qw( userid )], match => "EX", value => $user->get_id, }
		],
		);

	my $list = $searchexp->perform_search;

	my @dirs;
	$list->map(sub {
		my( undef, undef, $eprint ) = @_;

		my $name = $eprint->get_id;

		push @dirs, $name => &$f(
			$name,
			"drwxr-xr-x", # mode
			$user->get_value( "username" ),
			$user->get_value( "usertype" ),
			0, # size
			$self->get_object_mtime( $eprint )
			);
	});

	$list->dispose;

#	push @dirs, &$f(
#			"incoming",
#			"drwxr-xr-x",
#			$user->get_value( "username" ),
#			$user->get_value( "usertype" ),
#			0, # size
#			time()
#		);

	return @dirs;
}

sub list_eprint_exports
{
	my( $self, $args, $f ) = @_;

	my $user = $self->{current_user} or return ();
	my $session = $self->{session};

	my $eprint = $self->retrieve_eprint( $args );
	return () unless $eprint;
	my $path = $args->[1];
	$path =~ s#/#::#g; # Foo/Bar => Foo::Bar

	my $fn = "eprint";

	my @plugins = $session->plugin_list(
		type => "Export",
		can_accept => "dataobj/eprint",
		is_visible => "all"
	);

	my @dirs;

	foreach my $name (@plugins)
	{
		my $plugin = $session->plugin( $name );
		$name =~ s/^Export:://;
		if( length($path) )
		{
			next unless $name =~ s/^$path//;
			$name =~ s/^:://;
		}
		$name =~ s/::.*//;
		if( length($name) )
		{
			push @dirs, $name => &$f(
				$name,
				"drwxr-xr-x",
				$user->get_value( "username" ),
				$user->get_value( "usertype" ),
				0, # size
				time()
			);
		}
		else
		{
			$name = sprintf("%s\_%06d%s", $fn, $eprint->get_id, $plugin->{suffix});
			push @dirs, $name => &$f(
				$name,
				"-rwxr-xr-x",
				$user->get_value( "username" ),
				$user->get_value( "usertype" ),
				0, # size
				time()
			);
		}
	}

	return @dirs;
}

sub eprint_export_size
{
	my( $self, $args ) = @_;

	my $user = $self->{current_user} or return ();
	my $session = $self->{session};

	my $eprint = $self->retrieve_eprint( $args );
	return undef unless $eprint;
	my $path = $args->[1];
	$path =~ s#/#::#g; # Foo/Bar => Foo::Bar

	my $plugin = $session->plugin( "Export::" . $path );
	return undef unless $plugin;

	my $tmpfile = File::Temp->new;
	$plugin->initialise_fh( $tmpfile );
	print $tmpfile $eprint->export( $path );
	CORE::seek($tmpfile,0,0);

	return -s "$tmpfile";
}

sub eprint_export_mime_type
{
	my( $self, $args ) = @_;

	my $user = $self->{current_user} or return ();
	my $session = $self->{session};

	my $eprint = $self->retrieve_eprint( $args );
	return undef unless $eprint;
	my $path = $args->[1];
	$path =~ s#/#::#g; # Foo/Bar => Foo::Bar

	my $plugin = $session->plugin( "Export::" . $path );
	return undef unless $plugin;

	return $plugin->param( "mimetype" );
}

sub open_eprint_export
{
	my( $self, $args ) = @_;

	my $user = $self->{current_user} or return ();
	my $session = $self->{session};

	my $eprint = $self->retrieve_eprint( $args );
	return undef unless $eprint;
	my $path = $args->[1];
	$path =~ s#/#::#g; # Foo/Bar => Foo::Bar

	my $plugin = $session->plugin( "Export::" . $path );
	return undef unless $plugin;

	my $tmpfile = File::Temp->new;
	$plugin->initialise_fh( $tmpfile );
	print $tmpfile $eprint->export( $path );
	CORE::seek($tmpfile,0,0);

	return $tmpfile;
}

sub make_eprint
{
	my( $self, $args, $path ) = @_;

	my $session = $self->{session};
	my $user = $self->{current_user};

	my $title = $args->[0];

	my $eprint = EPrints::DataObj::EPrint->create_from_data(
		$session,
		{
			userid => $user->get_id,
			eprint_status => "inbox",
			title => $title,
		},
		$session->get_repository->get_dataset( "inbox" )
		);

	my $vfs = EPrints::DataObj::VFS->create_from_data(
		$session,
		{
			path => $path,
			userid => $user->get_id,
			type => "directory",
			target => "/inbox/" . $eprint->get_id,
		},
		$session->get_repository->get_dataset( "vfs" )
		);

	return 1;
}

sub retrieve_eprint
{
	my( $self, $args ) = @_;

	my( $eprintid ) = @$args;

	my $dataset = $self->{session}->get_repository->get_dataset( "eprint" );
	
	my $eprint = $dataset->get_object( $self->{session}, $eprintid );
	return unless defined $eprint;

	return $eprint;
}

sub can_change_eprint
{
	my( $self, $args ) = @_;

	my $user = $self->{current_user};
	return 0 unless defined $user;

	my $eprint = $self->retrieve_eprint( $args );
	return 0 unless defined $eprint;
	return 0 unless $eprint->get_value( "eprint_status" ) eq "inbox";
	return 0 unless $eprint->has_owner( $user );

	return 1;
}

sub rename_eprint
{
	my( $self, $args, $path, $tgt ) = @_;

	$path =~ s# /([^/]+)$ ##x;
	my( $from_fn ) = $1;
	$tgt =~ s# /([^/]+)$ ##x;
	my( $to_fn ) = $1;

	# We can only rename eprints in-place, so far
	return 0 unless $path eq $tgt;

	my $eprint = $self->retrieve_eprint( $args );
	return 0 unless defined $eprint;

	$eprint->set_value( "title", $to_fn );
	$eprint->commit;

	my $source = "$tgt/$to_fn";
	my $target = "$path/$from_fn";

	my $vfs = $self->_vfs_create(
			"directory",
			$source,
			$target
		);

	return defined $vfs;
}

sub rename_document
{
	my( $self, $args, $path, $tgt ) = @_;

	$path =~ s# /([^/]+)$ ##x;
	my( $from_fn ) = $1;
	$tgt =~ s# /([^/]+)$ ##x;
	my( $to_fn ) = $1;

	# We can only rename documents in-place, so far
	return 0 unless $path eq $tgt;

	my $doc = $self->retrieve_document( $args );
	return 0 unless defined $doc;

	$doc->set_value( "formatdesc", $to_fn );
	$doc->commit;

	my $source = "$tgt/$to_fn";
	my $target = "$path/$from_fn";

	my $vfs = $self->_vfs_create(
			"directory",
			$source,
			$target
		);

	return defined $vfs;
}

sub rename_file
{
	my( $self, $args, $path, $tgt, $stack ) = @_;

	$path =~ s# /([^/]+)$ ##x;
	my( $from_fn ) = $1;
	$tgt =~ s# /([^/]+)$ ##x;
	my( $to_fn ) = $1;

	# We can only rename eprints in-place, so far
	return 0 unless $path eq $tgt;

	my $file = $self->retrieve_file( $args );
	return 0 unless defined $file;

	$file->set_value( "filename", $to_fn );
	$file->commit;

	return 1;
}

sub list_documents
{
	my( $self, $args, $f ) = @_;

	my $eprint = $self->retrieve_eprint( $args ) or return ();

	my $user = $self->{current_user};

	my @dirs;
	for($eprint->get_all_documents)
	{
		unless(
			$_->get_value( "security" ) eq "public" ||
			(defined($user) && $eprint->has_owner( $user ))
			)
		{
			next;
		}
		my $name = $_->get_value( "pos" );
		push @dirs, $name => &$f(
			$name,
			"drwxr-xr-x", # mode
			$user->get_value( "username" ),
			$user->get_value( "usertype" ),
			0, # size
			$self->get_object_mtime( $_ )
			);
	}
#	push @dirs, &$f(
#			"incoming",
#			"drwxr-xr-x",
#			$user->get_value( "username" ),
#			$user->get_value( "usertype" ),
#			0, # size
#			time()
#		);
	if( $eprint->get_value( "eprint_status" ) eq "archive" )
	{
		push @dirs, "export" => &$f(
			"export",
			"drwxr-xr-x",
			$user->get_value( "username" ),
			$user->get_value( "usertype" ),
			0, # size
			time()
		);
	}

	return @dirs;
}

sub make_document
{
	my( $self, $args, $path ) = @_;

	my $eprint = $self->retrieve_eprint( $args ) or return ();
	my $session = $self->{session};

	my $title = $args->[1];

	my $doc = EPrints::DataObj::Document->create_from_data(
		$session,
		{
			eprintid => $eprint->get_id,
			format => "other",
			formatdesc => $title,
		},
		$session->get_repository->get_dataset( "document" )
		);

	my $tgt = $path;
	$tgt =~ s# [^/]+$ # $doc->get_value( "pos" ) #xe;

	my $vfs = EPrints::DataObj::VFS->create_from_data(
		$session,
		{
			path => $path,
			userid => $self->{current_user}->get_id,
			type => "directory",
			target => $tgt,
		},
		$session->get_repository->get_dataset( "vfs" )
		);

	return 1;
}

sub retrieve_document
{
	my( $self, $args ) = @_;

	my( $eprintid, $position ) = @$args;
	($eprintid) = split / /, $eprintid, 2;

	my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos(
		$self->{session},
		$eprintid,
		$position,
		);

	return $doc;
}

sub list_document_contents
{
	my( $self, $args, $f ) = @_;

	my $doc = $self->retrieve_document( $args ) or return ();
	my $user = $self->{current_user};

	my @files;
	for(@{$doc->get_value( "files" )})
	{
		push @files, $_->get_value( "filename" ) => &$f(
			$_->get_value( "filename" ),
			"-r-xr-xr-x", # mode
			$user->get_value( "username" ),
			$user->get_value( "usertype" ),
			$_->get_value( "filesize" ), # size
			$self->get_object_mtime( $_ )
			);
	}

	return @files;
}

sub retrieve_file
{
	my( $self, $args ) = @_;

	my $doc = $self->retrieve_document( $args ) or return;
	my $filename = _unescape_filename( $args->[2] );

	return $doc->get_stored_file( $filename );
}

sub open_file
{
	my( $self, $args ) = @_;

	my $file = $self->retrieve_file( $args ) or return;

	my $tmpfile = File::Temp->new;
	binmode($tmpfile);
	$file->get_file( sub { print $tmpfile $_[0] } );
	CORE::seek($tmpfile,0,0);

	return $tmpfile;
}

sub open_write_eprint
{
	my( $self, $args, $append, $tmpfile ) = @_;

	my $filename = $args->[0];

	my $session = $self->{session};
	my $user = $self->{current_user};

	my $eprint = EPrints::DataObj::EPrint->create_from_data(
		$session,
		{ 
			userid => $user->get_id,
			eprint_status => "inbox",
		},
		$session->get_repository->get_dataset( "eprint" )
		);

	@$args = ( $eprint->get_id, $args->[0] );

	my $fh = $self->open_write_document( $args, $append );
	unless( defined $fh )
	{
		$eprint->remove;
		return undef;
	}

	$eprint->commit();

	return $fh;
}

sub open_write_document
{
	my( $self, $args, $append ) = @_;

	my $eprint = $self->retrieve_eprint( $args ) or return;
	my $filename = $args->[1];

	my $session = $self->{session};

	my $format = $session->get_repository->call( "guess_doc_type",
				$session,
				$filename,
				);

	my $doc = EPrints::DataObj::Document->create_from_data(
		$session,
		{
			eprintid => $eprint->get_id,
			format => $format,
		},
		$session->get_repository->get_dataset( "document" )
		);


	@$args = ( $args->[0], $doc->get_value( "pos" ), $args->[1] );

	my $fh = $self->open_write_file( $args, $append );
	unless( defined $fh )
	{
		$doc->remove();
		return 0;
	}

	$doc->commit();
	
	return $fh;
}

sub open_write_file
{
	my( $self, $args, $append ) = @_;

	my $tmpfile = File::Temp->new();

	my $doc = $self->retrieve_document( $args );
	my $filename = $args->[2];

	return unless defined $doc;

	if( $append )
	{
		my $file = $doc->get_stored_file( $filename );
		if( defined $file )
		{
			$file->write_copy_fh( $tmpfile );
		}
	}

	return $tmpfile;
}

sub close_write_file
{
	my( $self, $args, $append, $tmpfile ) = @_;

	my $doc = $self->retrieve_document( $args );
	my $filename = $args->[2];

	CORE::seek($tmpfile,0,0);
	return $doc->add_stored_file( $filename, $tmpfile, -s $tmpfile );
}

sub delete_eprint
{
	my( $self, $args ) = @_;

	my $eprint = $self->retrieve_eprint( $args );

	return $eprint->remove();
}

sub delete_document
{
	my( $self, $args, $path ) = @_;

	my $doc = $self->retrieve_document( $args );

	return $doc->remove();
}

sub delete_file
{
	my( $self, $args ) = @_;

	my $file = $self->retrieve_file( $args );

	return $file->remove();
}

sub register_browse_views
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $ds = $session->get_repository->get_dataset( "archive" );

	my @views;

	foreach my $view ( @{$session->get_repository->get_conf( "browse_views" )} )
	{
		my $name = $session->get_view_name( $ds, $view->{id} );
		$name = quotemeta( _escape_filename( $name ) );
		my @fields = EPrints::Update::Views::get_fields_from_config( $ds, $view->{fields} );
		my $value_count = scalar @fields;
		push @views, qr#/view/($name)((?:/[^/]+){$value_count})# => {
			is_dir => sub { 1 },
			can_write => sub { 0 },
			can_delete => sub { 0 },
			exists => sub { 1 },
			size => sub { 4096 },
			modtime => sub { time() },
			list => \&list_browse_view_contents,
		};
		push @views, qr#/view/($name)((?:/[^/]+){0,$value_count})# => {
			is_dir => sub { 1 },
			can_write => sub { 0 },
			can_delete => sub { 0 },
			exists => sub { 1 },
			size => sub { 4096 },
			modtime => sub { time() },
			list => \&list_browse_view_menu,
		};
		push @views, qr#/view/(?:$name)(?:(?:/[^/]+){$value_count})/([^/]+)# => {
			is_dir => sub { 1 },
			can_write => sub { 0 },
			can_delete => sub { 0 },
			exists => sub { 1 },
			size => sub { 4096 },
			modtime => sub { time() },
			list => \&list_documents,
		};
		push @views, qr#/view/(?:$name)(?:(?:/[^/]+){$value_count})/([^/]+)/export/?(.*)/eprint_.*# => {
			is_dir => sub { 0 },
			can_write => sub { 0 },
			can_delete => sub { 0 },
			exists => sub { 1 },
			size => \&eprint_export_size,
			modtime => sub { $_[0]->get_object_mtime( &retrieve_eprint(@_) ) },
			open_read => \&open_eprint_export,
			mime_type => \&eprint_export_mime_type,
		};
		push @views, qr#/view/(?:$name)(?:(?:/[^/]+){$value_count})/([^/]+)/export/?(.*)# => {
			is_dir => sub { 1 },
			can_write => sub { 0 },
			can_delete => sub { 0 },
			exists => sub { 1 },
			size => sub { 4096 },
			modtime => sub { time() },
			list => \&list_eprint_exports,
		};
		push @views, qr#/view/(?:$name)(?:(?:/[^/]+){$value_count})/([^/]+)/([^/]+)# => {
			is_dir => sub { 1 },
			can_write => sub { 0 },
			can_delete => sub { 0 },
			exists => sub { 1 },
			size => sub { 4096 },
			modtime => sub { time() },
			list => \&list_document_contents,
		};
		push @views, qr#/view/(?:$name)(?:(?:/[^/]+){$value_count})/([^/]+)/([^/]+)/([^/]+)# => {
			is_dir => sub { 0 },
			can_write => sub { 0 },
			can_delete => sub { 0 },
			exists => sub { defined &retrieve_file(@_) },
			size => sub { $_[0]->get_object_size( &retrieve_file(@_) ) },
			modtime => sub { $_[0]->get_object_mtime( &retrieve_file(@_) ) },
			open_read => \&open_file,
		};
	}

	push @{$self->{filesys}}, @PUBLIC_FILESYS, @views;
}

sub list_browse_views
{
	my( $self, $args, $f ) = @_;

	my $session = $self->{session};

	my @dirs;

	my $ds = $session->get_repository->get_dataset( "archive" );

	foreach my $view ( @{$session->get_repository->get_conf( "browse_views" )} )
	{
		my $name = $session->get_view_name( $ds, $view->{id} );
		$name = _escape_filename( $name );
		push @dirs, $name => &$f(
			$name,
			"drwxr-xr-x", # mode
			"root",
			"root",
			4096, # size
			time(),
			);
	}

	return @dirs;
}

sub retrieve_browse_view
{
	my( $self, $args ) = @_;

	my( $view_name ) = @$args;
	$view_name = _unescape_filename( $view_name );

	my $session = $self->{session};

	my $ds = $session->get_repository->get_dataset( "archive" );

	foreach my $view ( @{$session->get_repository->get_conf( "browse_views" )} )
	{
		my $name = $session->get_view_name( $ds, $view->{id} );
		return $view if $name eq $view_name;
	}

	return undef;
}

sub retrieve_browse_view_values
{
	my( $self, $args, $fields ) = @_;

	my @view_values = grep { length($_) } split /\//, $args->[1];
	@view_values = map { _unescape_filename( $_ ) } @view_values;

	for(my $i = 0; $i < @view_values; ++$i)
	{
		if( $fields->[$i]->[0]->is_type( "name" ) )
		{
			my %name;
			@name{qw( family given lineage honourific )} = split /:/, $view_values[$i];
			$view_values[$i] = \%name;
		}
	}

	return @view_values;
}

sub list_browse_view_menu
{
	my( $self, $args, $f ) = @_;

	my $view = $self->retrieve_browse_view( $args );
	return () unless defined $view;

	my $session = $self->{session};

	my $ds = $session->get_repository->get_dataset( "archive" );

	my @fields = EPrints::Update::Views::get_fields_from_config( $ds, $view->{fields} );
	my @view_values = $self->retrieve_browse_view_values( $args, \@fields );
	my $filters = EPrints::Update::Views::get_filters( $session, $view, \@view_values );

	my $menu_level = scalar @view_values;
	my @menu_fields = @{$fields[$menu_level]};

	my $key_values = EPrints::Update::Views::get_fieldlist_values( $session, $ds, \@menu_fields );

	my @dirs;

	foreach my $value (keys %$key_values)
	{
		my $name = _escape_filename( $value );
		push @dirs, $name => &$f(
			$name,
			"drwxr-xr-x", # mode
			"root",
			"root",
			4096, # size
			time(),
			);
	}

	return @dirs;
}

sub list_browse_view_contents
{
	my( $self, $args, $f ) = @_;

	my $view = $self->retrieve_browse_view( $args );
	return () unless defined $view;

	my $session = $self->{session};

	my $ds = $session->get_repository->get_dataset( "archive" );

	my @fields = EPrints::Update::Views::get_fields_from_config( $ds, $view->{fields} );
	my @view_values = $self->retrieve_browse_view_values( $args, \@fields );

	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $ds,
		satisfy_all => 1,
		filters => [
			{ meta_fields => [qw( metadata_visibility )], match => "EQ", value => "show" },
		],
		);
	for(my $i = 0; $i < scalar @view_values; ++$i)
	{
		$searchexp->add_field( $fields[$i], $view_values[$i], "EX", undef, "filter$i", 1 );
	}
	
	my $list = $searchexp->perform_search;

	my @dirs;
	$list->map(sub {
		my( undef, undef, $eprint ) = @_;

		my $name = $eprint->get_id;

		push @dirs, $name => &$f(
			$name,
			"drwxr-xr-x", # mode
			"root",
			"root",
			0, # size
			$self->get_object_mtime( $eprint )
			);
	});

	$list->dispose;

	return @dirs;
}

1;
