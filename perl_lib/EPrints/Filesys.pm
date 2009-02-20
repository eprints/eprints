package EPrints::Filesys;

=head1 NAME

B<EPrints::Filesys> - virtual file system for EPrints

=head1 METHODS

=over 4

=cut

use strict;
use warnings;

use Carp;
use Filesys::Virtual;
use Filesys::Virtual::Plain;
use Time::Local;
use Fcntl ':mode';
use constant DEBUG => 0;

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

our @USER_FILESYS = (
	qr{/inbox/incoming} => {
		is_dir => sub { 1 },
		can_write => sub { 0 },
		can_delete => sub { 0 },
		exists => sub { 1 },
		size => sub { 4096 },
		modtime => sub { time() },
		list => sub { qw() },
	},
	qr{/inbox/incoming/([^/]+)} => {
		is_dir => sub { 0 },
		can_write => sub { 1 },
		can_delete => sub { 0 },
		exists => sub { 0 },
		open_write => \&open_write_eprint,
		close_write => \&close_write_file,
	},
	qr{/inbox/([^/]+)} => {
		is_dir => sub { 1 },
		can_write => sub { 1 },
		can_delete => sub { 1 },
		exists => sub { defined &retrieve_eprint },
		size => sub { 4096 },
		modtime => sub { $_[0]->get_object_mtime( &retrieve_eprint ) },
		list => \&list_documents,
		delete => \&delete_eprint,
	},
	qr{/inbox/([^/]+)/incoming} => {
		is_dir => sub { 1 },
		can_write => sub { 0 },
		can_delete => sub { 1 },
		exists => sub { 1 },
		size => sub { 4096 },
		modtime => sub { time() },
		list => sub { qw() },
		delete => sub { 1 }, # fake delete
	},
	qr{/inbox/([^/]+)/incoming/([^/]+)} => {
		is_dir => sub { 0 },
		can_write => sub { 1 },
		can_delete => sub { 0 },
		exists => sub { 0 },
		open_write => \&open_write_document,
		close_write => \&close_write_file,
	},
	qr{/inbox/([^/]+)/(\d+)} => {
		is_dir => sub { 1 },
		can_write => sub { 0 },
		can_delete => sub { 1 },
		exists => sub { defined &retrieve_document },
		size => sub { 4096 },
		modtime => sub { $_[0]->get_object_mtime( &retrieve_document ) },
		list => \&list_document_contents,
		delete => \&delete_document,
	},
	qr{/inbox/([^/]+)/(\d+)/([^/]+)} => {
		is_dir => sub { 0 },
		can_write => sub { 1 },
		can_delete => sub { 1 },
		exists => sub { defined &retrieve_file },
		size => sub { $_[0]->get_object_size( &retrieve_file ) },
		modtime => sub { $_[0]->get_object_mtime( &retrieve_file ) },
		open_read => \&open_file,
		open_write => \&open_write_file,
		close_write => \&close_write_file,
		delete => \&delete_file,
	},
);

our @TEST_FILESYS = (
	qr{/test} => {
		is_dir => sub { 1 },
		can_write => sub { 1 },
		can_delete => sub { 1 },
		exists => sub { 1 },
		size => sub { $_[0]->{test}->size( "/" ) },
		modtime => sub { $_[0]->{test}->modtime( "/" ) },
		list => sub { $_[0]->{test}->list( "/" ) },
	},
	qr{/test(/.+)} => {
		is_dir => sub { $_[0]->{test}->test( "d", $_[1]->[0] ) },
		can_write => sub { 1 },
		can_delete => sub { 1 },
		exists => sub { $_[0]->{test}->test( "e", $_[1]->[0] ) },
		size => sub { $_[0]->{test}->size( $_[1]->[0] ) },
		modtime => sub { $_[0]->{test}->modtime( $_[1]->[0] ) },
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

sub new
{
	my( $class, $self ) = @_;

	$self = bless $self, $class;

	Carp::croak "Requires session argument" unless $self->{session};

	$self->{root_path} ||= "";
	$self->{cwd} = [];
	$self->{filesys} = [];

	push @{$self->{filesys}}, @ROOT_FILESYS;

	$self->{test} = Filesys::Virtual::Plain->new({
		root_path => "/tmp",
		});
	push @{$self->{filesys}}, @TEST_FILESYS;

	if( defined $self->{current_user} )
	{
		$self->register_user( $self->{current_user} );
	}

	return $self;
}

sub _escape_filename
{
	my( $fn ) = @_;
	$fn =~ s#([=/])#sprintf("=%02x",ord($1))#seg;
	$fn;
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

sub _get_handler
{
	my( $self, $path ) = @_;

	$path = $self->_resolve_path( $path );

print STDERR "_GET_HANDLER($path)\n" if DEBUG;

	my( $handler, $args );

	for(my $i = 0; $i < @{$self->{filesys}}; $i+=2)
	{
		my $re = $self->{filesys}->[$i];
		if( $path =~ m/^$re$/ )
		{
print STDERR "\tMATCHES($re)\n" if DEBUG;
			$handler = $self->{filesys}->[$i+1];
			$args = [$1,$2,$3,$4,$5,$6,$7,$8,$9];
			last;
		}
	}

	return( $handler, $args );
}

=head2 Virtual::Filesys Methods

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

	my( $handler, $args ) = $self->_get_handler( $path );
	return unless defined $handler;
	return unless &{$handler->{exists}}( $self, $args );

	return &{$handler->{modtime}}( $self, $args );
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

	return &{$handler->{delete}}( $self, $args );
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

	my( $handler, $args ) = $self->_get_handler( $path );
	return 0 unless defined $handler;

	return &{$handler->{mkdir}}( $self, $args );
}

=item $filesys->rmdir( PATH )

Like delete but can also be used with directories.

=cut

sub rmdir
{
	my( $self, $path ) = @_;

	my( $handler, $args ) = $self->_get_handler( $path );
	return 0 unless defined $handler;
	return 0 unless &{$handler->{can_delete}}( $self, $args );
	return 0 unless &{$handler->{exists}}( $self, $args );

	return &{$handler->{delete}}( $self, $args );
}

=item $filesys->list( [ PATH ] )

List items contained in CWD + PATH.

=cut

sub list
{
	my( $self, $path ) = @_;

	my( $handler, $args ) = $self->_get_handler( $path );
	return () unless defined $handler;
	return () unless &{$handler->{is_dir}}( $self, $args );
	return () unless &{$handler->{exists}}( $self, $args );

	return &{$handler->{list}}( $self, $args, sub { $_[0] } );
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
	my $mtime = &{$handler->{modtime}}( $self, $args );

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
		0, #ctime
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
		return 1; # exists
	}
	elsif( $test eq "f" )
	{
		return !&{$handler->{is_dir}}( $self, $args );
	}
	elsif( $test eq "d" )
	{
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
	return 0 unless defined $handler;
	return 0 unless !&{$handler->{is_dir}}( $self, $args );
	return 0 unless &{$handler->{exists}}( $self, $args );

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

	my( $handler, $args ) = $self->_get_handler( $path );
	return 0 unless defined $handler;
	return 0 unless &{$handler->{can_write}}( $self, $args );

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

###
#    Methods below are file system location-specific
###

sub list_root
{
	my( $self, $args, $f ) = @_;

	my @entries;
	push @entries, &$f(
		"inbox",
		"drwxr-xr-x",
		"root",
		"root",
		0,
		time() );
	push @entries, &$f(
		"test",
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

sub list_inbox_eprints
{
	my( $self, $args, $f ) = @_;

	my $user = $self->{current_user} or return ();

	my $dataset = $self->{session}->get_repository->get_dataset( "inbox" );

	my $searchexp = EPrints::Search->new(
		session => $self->{session},
		dataset => $dataset,
		filters => [
			{ meta_fields => [qw( userid )], value => $user->get_id, }
		],
		);

	my $list = $searchexp->perform_search;

	my @dirs;
	$list->map(sub {
		my( undef, undef, $eprint ) = @_;

		my $citation = $eprint->render_description();

		push @dirs, &$f(
			$eprint->get_id . " " . EPrints::Utils::tree_to_utf8( $citation ),
			"drwxr-xr-x", # mode
			$user->get_value( "username" ),
			$user->get_value( "usertype" ),
			0, # size
			$self->get_object_mtime( $eprint )
			);

		EPrints::XML::dispose( $citation );
	});

	$list->dispose;

	push @dirs, &$f(
			"incoming",
			"drwxr-xr-x",
			$user->get_value( "username" ),
			$user->get_value( "usertype" ),
			0, # size
			time()
		);

	return @dirs;
}

sub retrieve_eprint
{
	my( $self, $args ) = @_;

	my( $eprintid ) = @$args;
	($eprintid) = split / /, $eprintid, 2;

	my $dataset = $self->{session}->get_repository->get_dataset( "inbox" );
	
	my $eprint = $dataset->get_object( $self->{session}, $eprintid );

	return $eprint;
}

sub list_documents
{
	my( $self, $args, $f ) = @_;

	my $eprint = $self->retrieve_eprint( $args ) or return ();

	my $user = $self->{current_user};

	my @dirs;
	for($eprint->get_all_documents)
	{
		push @dirs, &$f(
			$_->get_value( "pos" ),
			"drwxr-xr-x", # mode
			$user->get_value( "username" ),
			$user->get_value( "usertype" ),
			0, # size
			$self->get_object_mtime( $_ )
			);
	}
	push @dirs, &$f(
			"incoming",
			"drwxr-xr-x",
			$user->get_value( "username" ),
			$user->get_value( "usertype" ),
			0, # size
			time()
		);

	return @dirs;
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
		push @files, &$f(
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

	my $filename = _unescape_filename( $args->[0] );

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
	my $filename = _unescape_filename( $args->[1] );

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
	my $filename = _unescape_filename( $args->[2] );

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
	my $filename = _unescape_filename( $args->[2] );

	CORE::seek($tmpfile,0,0);
	return $doc->upload( $tmpfile, $filename, 0, -s $tmpfile );
}

sub delete_eprint
{
	my( $self, $args ) = @_;

	my $eprint = $self->retrieve_eprint( $args );

	return $eprint->remove();
}

sub delete_document
{
	my( $self, $args ) = @_;

	my $doc = $self->retrieve_document( $args );

	return $doc->remove();
}

sub delete_file
{
	my( $self, $args ) = @_;

	my $file = $self->retrieve_file( $args );

	return $file->remove();
}

1;
