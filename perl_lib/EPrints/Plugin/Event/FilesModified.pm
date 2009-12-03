package EPrints::Plugin::Event::FilesModified;

use EPrints::Plugin::Event;

@ISA = qw( EPrints::Plugin::Event );

sub files_modified
{
	my( $self, $doc ) = @_;

	my $rc = $doc->files_modified();

	return $rc;
}

1;
