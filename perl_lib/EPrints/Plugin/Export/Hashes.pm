package EPrints::Plugin::Export::Hashes;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;


sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Hashes";
	$self->{accept} = [ 'list/document' ];
	$self->{visible} = "staff";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";

	return $self;
}


sub output_list
{
	my( $plugin, %opts ) = @_;

	my $handle = $plugin->{handle};

	if( !defined $opts{fh} )
	{
		$opts{fh} = *STDOUT;
	}

	my @files = ();
	$opts{list}->map( sub {
		my( $handle, $dataset, $item ) = @_;

		my $file = find_latest_doc_hash( $handle, $item );
		push @files, $file if defined $file;
	} );

	EPrints::Probity::create_log_fh(
		$handle,
		\@files,
		$opts{fh} );
}


sub find_latest_doc_hash
{
	my( $handle, $doc ) = @_;

	my $id = $doc->get_id;
	my $eprint = $doc->get_eprint;
	if( !defined $eprint )
	{
		$handle->get_repository->log( "No eprint for document: $id" );
		return ();
	}
	my $path = $eprint->local_path;

 	opendir CDIR, $path or return;
	my @filesread = readdir CDIR;
	closedir CDIR;

	my $latest;
	foreach my $file ( sort @filesread )
	{
		if( $file =~ m/^$id\.(.*).xsh$/ )
		{
			my $filename = $path."/".$file;
			$latest = $filename;
		}
	}

	return $latest;
}

1;
