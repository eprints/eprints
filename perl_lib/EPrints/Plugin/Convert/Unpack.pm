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
	application/x-zip unzip
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

	# Get the main file name
	my $mt = $doc->mime_type() or return ();
	return $TYPES{$mt} ? ($TYPES{$mt}=>{plugin=>$plugin}) : ();
}

sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	# What to call the temporary file
	my $fn = $doc->local_path . '/' . $doc->get_main;
	
	my $cmd = $plugin->get_repository->get_conf( 'executables', $type ) or die "Executable location not set for $type conversion";
	my $invo = $plugin->get_repository->get_conf->( 'invocation', $type ) or die "Invocation not set for $type conversion";
	system(EPrints::Utils::prepare_cmd($invo,
		$type => $cmd,
		DIR => $dir,
		ARC => $fn,
		FILENAME => $doc->get_main,
		FILEPATH => $doc->local_path,
	));

	local *DIR;
	opendir DIR, $dir or die "Unable to open directory $dir: $!";
	my @files = grep { $_ !~ /^\./ } readdir(DIR);
	closedir DIR;

	foreach( @files ) { EPrints::Utils::chown_for_eprints( $_ ); }
	
	return @files;
}

1;
