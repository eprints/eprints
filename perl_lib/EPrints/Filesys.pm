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
use Time::Local;

our @ISA = qw( Filesys::Virtual );

# Here's the EPrints virtual file system
our @FILESYS = (
	qw{/} => {
		is_dir => sub { 1 },
		can_write => sub { 0 },
		can_delete => sub { 0 },
		exists => sub { 1 },
		list => sub { $_[0]->_dir_entry( "inbox", "drwxr-xr-x", 0, time() ) },
	},
	qr{/inbox} => {
		is_dir => sub { 1 },
		can_write => sub { 0 },
		can_delete => sub { 0 },
		exists => sub { 1 },
		list => \&list_inbox_eprints,
	},
	qw{/inbox/incoming} => {
		is_dir => sub { 1 },
		can_write => sub { 0 },
		can_delete => sub { 0 },
		exists => sub { 1 },
		list => sub { qw() },
	},
	qw{/inbox/incoming/([^/]+)} => {
		is_dir => sub { 0 },
		can_write => sub { 1 },
		can_delete => sub { 0 },
		exists => sub { 1 },
		list => sub { qw() },
		open_write => \&open_write_eprint,
		close_write => \&close_write_file,
	},
	qr{/inbox/([^/]+)} => {
		is_dir => sub { 1 },
		can_write => sub { 1 },
		can_delete => sub { 1 },
		exists => \&check_eprint,
		list => \&list_documents,
		delete => \&delete_eprint,
	},
	qw{/inbox/([^/]+)/incoming} => {
		is_dir => sub { 1 },
		can_write => sub { 0 },
		can_delete => sub { 1 },
		exists => sub { 1 },
		list => sub { qw() },
		delete => sub { 1 }, # fake delete
	},
	qw{/inbox/([^/]+)/incoming/([^/]+)} => {
		is_dir => sub { 0 },
		can_write => sub { 1 },
		can_delete => sub { 0 },
		exists => sub { 1 },
		list => sub { qw() },
		open_write => \&open_write_document,
		close_write => \&close_write_file,
	},
	qr{/inbox/([^/]+)/(\d+)} => {
		is_dir => sub { 1 },
		can_write => sub { 0 },
		can_delete => sub { 1 },
		exists => \&check_document,
		list => \&list_document_contents,
		delete => \&delete_document,
	},
	qr{/inbox/([^/]+)/(\d+)/([^/]+)} => {
		is_dir => sub { 0 },
		can_write => sub { 1 },
		can_delete => sub { 1 },
		exists => \&check_file,
		open => \&open_file,
		open_write => \&open_write_file,
		close_write => \&close_write_file,
		delete => \&delete_file,
	},
);

our %WRITE_SETTINGS;

sub new
{
	my( $class, $self ) = @_;

	Carp::croak "Requires session argument" unless $self->{session};

	$self->{cwd} = [];
	$self->{current_user} = undef;

	$self = bless $self, $class;

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
	my( $self, $name, $mode, $size, $mtime ) = @_;

	my( $day, $mm, $dd, $time, $yr ) = (gmtime($mtime) =~
		m/(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/ );

	return sprintf("%1s%9s %4s %-8s %-8s %8s %3s %2s %5s %s",
			substr($mode,0,1),
			substr($mode,1),
			2, # nlinks
			$self->{current_user}->get_value( "username" ),
			$self->{current_user}->get_value( "usertype" ),
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

	my( $handler, $args );

	for(my $i = 0; $i < @FILESYS; $i+=2)
	{
		if( $path =~ m/^$FILESYS[$i]$/ )
		{
			$handler = $FILESYS[$i+1];
			$args = [$1,$2,$3,$4,$5,$6,$7,$8,$9];
			last;
		}
	}

	return( $handler, $args );
}

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

	$self->{current_user} = EPrints::DataObj::User::user_with_username( $self->{session}, $username );

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

=item $filesys->modtime

Unimplemented.

=cut

sub modtime
{
	my( $self, $path ) = @_;

	return( 1, "000000000000" ); # 2-digit year?
}

=item $filesys->size

Unimplemented.

=cut

sub size
{
	my( $self, $path ) = @_;

	return 0;
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

	return 0 unless defined $self->{current_user};

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

=item $filesys->mkdir

Unimplemented.

=cut

sub mkdir
{
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

	return &{$handler->{list}}( $self, $args );
}

=item $filesys->list_details( [ PATH ] )

List items contained in CWD + PATH, with full detail.

=cut

sub list_details
{
	return &list( @_ );
}

=item $filesys->stat

Unimplemented.

=cut

sub stat
{
}

=item $filesys->test

Unimplemented.

=cut

sub test
{
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

	return &{$handler->{open}}( $self, $args );
}

=item $filesys->close_read( fh )

=cut

sub close_read
{
	my( $self, $fh ) = @_;
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

sub get_object_mtime
{
	my( $self, $object ) = @_;

	my $field = $object->get_dataset->get_datestamp_field();

	return 0 unless defined $field;

	my $datetime = $object->get_value( $field->get_name );
	$datetime =~ /(\d+)\D(\d{2})\D(\d{2})\D(\d{2})\D(\d{2})\D(\d{2})/;
	my $time = Time::Local::timegm($6,$5,$4,$3,$2-1,$1-1900);

	return $time;
}

sub list_inbox_eprints
{
	my( $self, $args ) = @_;

	my $user = $self->{current_user};

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

		push @dirs, $self->_dir_entry(
			$eprint->get_id . " " . EPrints::Utils::tree_to_utf8( $citation ),
			"drwxr-xr-x", # mode
			0, # size
			$self->get_object_mtime( $eprint )
			);

		EPrints::XML::dispose( $citation );
	});

	$list->dispose;

	push @dirs, $self->_dir_entry(
			"incoming",
			"drwxr-xr-x",
			0, # size
			time()
		);

	return @dirs;
}

sub check_eprint
{
	my( $self, $args ) = @_;

	my( $eprintid ) = @$args;
	($eprintid) = split / /, $eprintid, 2;

	my $dataset = $self->{session}->get_repository->get_dataset( "inbox" );
	
	my $eprint = $dataset->get_object( $self->{session}, $eprintid );

	return defined $eprint;
}

sub list_documents
{
	my( $self, $args ) = @_;

	my( $eprintid ) = @$args;
	($eprintid) = split / /, $eprintid, 2;

	my $user = $self->{current_user};

	my $dataset = $self->{session}->get_repository->get_dataset( "inbox" );
	
	my $eprint = $dataset->get_object( $self->{session}, $eprintid );

	my @dirs;
	for($eprint->get_all_documents)
	{
		push @dirs, $self->_dir_entry(
			$_->get_value( "pos" ),
			"drwxr-xr-x", # mode
			0, # size
			$self->get_object_mtime( $_ )
			);
	}
	push @dirs, $self->_dir_entry(
			"incoming",
			"drwxr-xr-x",
			0, # size
			time()
		);

	return @dirs;
}

sub check_document
{
	my( $self, $args ) = @_;

	my( $eprintid, $position ) = @$args;
	($eprintid) = split / /, $eprintid, 2;

	my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos(
		$self->{session},
		$eprintid,
		$position,
		);

	return defined $doc;
}

sub list_document_contents
{
	my( $self, $args ) = @_;

	my( $eprintid, $position ) = @$args;
	($eprintid) = split / /, $eprintid, 2;

	my $user = $self->{current_user};

	my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos(
		$self->{session},
		$eprintid,
		$position,
		);

	my @files;
	for(@{$doc->get_value( "files" )})
	{
		push @files, $self->_dir_entry(
			$_->get_value( "filename" ),
			"-r-xr-xr-x", # mode
			$_->get_value( "filesize" ), # size
			$self->get_object_mtime( $_ )
			);
	}

	return @files;
}

sub check_file
{
	my( $self, $args ) = @_;

	my( $eprintid, $position, $filename ) = @$args;
	($eprintid) = split / /, $eprintid, 2;
	$filename = _unescape_filename( $filename );

	my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos(
		$self->{session},
		$eprintid,
		$position,
		);

	return defined $doc->get_stored_file( $filename );
}

sub open_file
{
	my( $self, $args ) = @_;

	my( $eprintid, $position, $filename ) = @$args;
	($eprintid) = split / /, $eprintid, 2;
	$filename = _unescape_filename( $filename );

	my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos(
		$self->{session},
		$eprintid,
		$position,
		);

	my $file = $doc->get_stored_file( $filename );

	my $tmpfile = File::Temp->new;
	binmode($tmpfile);
	$file->get_file( sub { print $tmpfile $_[0] } );
	CORE::seek($tmpfile,0,0);

	return $tmpfile;
}

sub open_write_eprint
{
	my( $self, $args, $append, $tmpfile ) = @_;

	my( $filename ) = @$args;
	$filename = _unescape_filename( $filename );

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

	my( $eprintid, $filename ) = @$args;
	($eprintid) = split / /, $eprintid, 2;
	$filename = _unescape_filename( $filename );

	my $session = $self->{session};

	my $format = $session->get_repository->call( "guess_doc_type",
				$session,
				$filename,
				);

	my $doc = EPrints::DataObj::Document->create_from_data(
		$session,
		{
			eprintid => $eprintid,
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

	my( $eprintid, $position, $filename ) = @$args;
	($eprintid) = split / /, $eprintid, 2;
	$filename = _unescape_filename( $filename );

	my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos(
		$self->{session},
		$eprintid,
		$position,
		);

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

	my( $eprintid, $position, $filename ) = @$args;
	($eprintid) = split / /, $eprintid, 2;
	$filename = _unescape_filename( $filename );

	my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos(
		$self->{session},
		$eprintid,
		$position,
		);

	CORE::seek($tmpfile,0,0);
	return $doc->upload( $tmpfile, $filename, 0, -s $tmpfile );
}

sub delete_eprint
{
	my( $self, $args ) = @_;

	my( $eprintid, $position ) = @$args;
	($eprintid) = split / /, $eprintid, 2;

	my $eprint = EPrints::DataObj::EPrint->new(
		$self->{session},
		$eprintid
		);

	return $eprint->remove();
}

sub delete_document
{
	my( $self, $args ) = @_;

	my( $eprintid, $position ) = @$args;
	($eprintid) = split / /, $eprintid, 2;

	my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos(
		$self->{session},
		$eprintid,
		$position,
		);

	return $doc->remove();
}

sub delete_file
{
	my( $self, $args ) = @_;

	my( $eprintid, $position, $filename ) = @$args;
	($eprintid) = split / /, $eprintid, 2;
	$filename = _unescape_filename( $filename );

	my $doc = EPrints::DataObj::Document::doc_with_eprintid_and_pos(
		$self->{session},
		$eprintid,
		$position,
		);

	my $file = $doc->get_stored_file( $filename );

	return 0 unless defined $file;

	return $file->remove();
}

1;
