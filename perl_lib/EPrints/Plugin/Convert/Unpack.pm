package EPrints::Plugin::Convert::Unpack;

=pod

=head1 NAME

EPrints::Plugin::Convert::Unpack - Unpack archive files (zip, tarball etc)

=head1 DESCRIPTION

This *only* handles single-files.

=cut

use strict;
use warnings;

use Carp;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

our %TYPES = qw(
	application/x-gzip gunzip
	application/x-tar tar
	application/zip unzip
	application/x-bzip2 bzip2
);

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Archive unpacking";
	$self->{visible} = "api";

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	my $mimetype = $doc->mime_type() or return ();

	my $cmd_id = $EPrints::Plugin::Convert::Unpack::TYPES{$mimetype};

	if( !$cmd_id or !$plugin->get_repository->can_execute( $cmd_id ) )
	{
		return ();
	}

	my $format = "unknown_" . $plugin->get_id;

	my @type = ( $format => {
		plugin => $plugin,
		phraseid => $plugin->html_phrase_id( $mimetype ),
	} );

	return @type;
}

sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	my $repository = $plugin->get_repository;

	# Get the main file name
	my $mimetype = $doc->mime_type();

	my $file = $doc->get_stored_file( $doc->get_main )->get_local_copy();

	my $cmd_id = $EPrints::Plugin::Convert::Unpack::TYPES{$mimetype};

	my %opts = (
		SOURCE => "$file",
		DIRECTORY => $dir,
	);

	if( !$mimetype or !$cmd_id or !$repository->can_invoke( $cmd_id, %opts ) )
	{
		return ();
	}

	$repository->exec( $cmd_id, %opts );
		
	opendir my $dh, $dir or die "Unable to open directory $dir: $!";
	my @files = grep { $_ !~ /^\./ } readdir($dh);
	closedir $dh;

	foreach( @files ) { EPrints::Utils::chown_for_eprints( $_ ); }
	
	return @files;
}

1;
