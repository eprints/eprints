package EPrints::Plugin::Screen::Admin::Backup;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ backup_repository /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions", 
			position => 1240, 
			action => "backup_repository",
		},
	];

	return $self;
}


sub action_backup_repository
{
	my( $self ) = @_;

	#do some stuff

	my $database_name = $self->{session}->get_repository->get_conf('dbname');
	my $database_password = $self->{session}->get_repository->get_conf('dbpass');
	my $database_user = $self->{session}->get_repository->get_conf('dbuser');
	my $repository_id = $self->{session}->get_repository->get_id;
	my $eprints_base_path = $self->{session}->get_repository->get_conf('base_path');

	my $tmpfile = File::Temp->new( SUFFIX => ".tgz" );
	my $sqlfile = File::Temp->new( SUFFIX => ".sql" );

	my $tar_executable = $self->{session}->get_repository->get_conf('executables','tar');
	my $mysqldump_executable = 'mysqldump';

	`$mysqldump_executable -u $database_user -p$database_password $database_name > $sqlfile`;

	`$tar_executable -czf $tmpfile $sqlfile -C $eprints_base_path . `; 

	my $result = 1;
	if( !-s "$tmpfile" )
	{
		$result = 0;
	}

        if( $result == 1 )
        {
                $self->{processor}->add_message(
                        "message",
                        $self->{session}->make_text( "repository_backed_up" )
                );
		seek($tmpfile, 0, 0);
		$self->{processor}->{tarball} = $tmpfile;
        }
        else
        {
                $self->{processor}->add_message(
                        "error",
                        $self->html_phrase( "couldnt_back_up_repository" )
                );
		$self->{processor}->{screenid} = "Admin";
        }
}


sub allow_backup_repository
{
	my( $self ) = @_;
	return $self->allow( "repository/backup" );
}

sub wishes_to_export
{
	my( $self ) = @_;

	if( !defined( $self->{processor}->{tarball} ) )
	{
		return 0;
	}

	my $filename = $self->{session}->get_repository->get_id . ".tgz";

	EPrints::Apache::AnApache::header_out(
		$self->{session}->get_request,
		"Content-Disposition: attachment; filename=$filename;"
	);

	return 1;
}

sub export
{
	my( $self ) = @_;

	binmode(STDOUT);
	while(sysread($self->{processor}->{tarball}, my $buffer, 4096))
	{
		print $buffer;
	}
}

sub export_mimetype
{
	my( $self ) = @_;

	return "application/x-gzip";
}

sub render
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef;
}

1;
