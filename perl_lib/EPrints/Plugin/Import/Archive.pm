=head1 NAME

EPrints::Plugin::Import::Archive

=cut

package EPrints::Plugin::Import::Archive;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

$EPrints::Plugin::Import::DISABLE = 1;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Base archive inport plugin: This should have been subclassed";
	$self->{visible} = "all";

	# limit the total number of files we'll read from a zip file
	$self->{max_files} = 100;

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};

	

}


######################################################################
=pod

=item $success = $doc->add_archive( $file, $archive_format )

$file is the full path to an archive file, eg. zip or .tar.gz 

This function will add the contents of that archive to the document.

=cut
######################################################################

sub add_archive
{
        my( $self, $file, $archive_format ) = @_;

        my $tmpdir = File::Temp->newdir();

        # Do the extraction
        my $rc = $self->{session}->get_repository->exec(
                        $archive_format,
                        DIR => $tmpdir,
                        ARC => $file );
	unlink($file);	
	
	return( $tmpdir );
}

sub create_epdata_from_directory
{
	my( $self, $dir, $single ) = @_;

	my $repo = $self->{repository};
	my $max_files = $self->param("max_files") || 0;

	my $epdata = $single ?
		{ files => [] } :
		[];

	my $media_info = {};

	eval { File::Find::find( {
		no_chdir => 1,
		wanted => sub {
			return if -d $File::Find::name;
			my $filepath = $File::Find::name;
			my $filename = substr($filepath, length($dir) + 1);

			$media_info = {};
			$repo->run_trigger( EPrints::Const::EP_TRIGGER_MEDIA_INFO,
				filename => $filename,
				filepath => $filepath,
				epdata => $media_info,
				);

			open(my $fh, "<", $filepath) or die "Error opening $filename: $!";
			if( $single )
			{
				push @{$epdata->{files}}, {
					filename => $filename,
					filesize => -s $fh,
					mime_type => $media_info->{mime_type},
					_content => $fh,
				};
				die "Too many files" if $max_files && @{$epdata} > $max_files;
			}
			else
			{
				push @{$epdata}, {
					%$media_info,
					main => $filename,
					files => [{
						filename => $filename,
						filesize => -s $fh,
						mime_type => $media_info->{mime_type},
						_content => $fh,
					}],
				};
				die "Too many files" if $max_files && @{$epdata} > $max_files;
			}
		},
	}, $dir ) };

	if( $single )
	{
		# bootstrap the document data from the last file
		$epdata = {
			%$media_info,
			%$epdata,
			main => $epdata->{files}->[-1]->{filename},
		};
	}

	return !$@ ? $epdata : undef;
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

