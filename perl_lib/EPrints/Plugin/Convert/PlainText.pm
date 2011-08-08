package EPrints::Plugin::Convert::PlainText;

=pod

=head1 NAME

EPrints::Plugin::Convert::PlainText - Convert documents to plain-text

=head1 DESCRIPTION

Uses the file extension to determine file type.

=cut

use EPrints::Plugin::Convert;

@ISA = qw/ EPrints::Plugin::Convert /;

use strict;

# xml = ?
%EPrints::Plugin::Convert::PlainText::APPS = qw(
pdf		pdftotext
doc		doc2txt
htm		elinks
html		elinks
xml		elinks
ps		ps2ascii
txt		_special
);

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Plain text conversion";
	$self->{visible} = "all";

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;

	# Get the main file name
	my $fn = $doc->get_main() or return ();

	my $mimetype = 'text/plain';

	my @type = ($mimetype => {
		plugin => $plugin,
		encoding => 'utf-8',
		phraseid => $plugin->html_phrase_id( $mimetype ),
	});

	if( $fn =~ /\.txt$/ )
	{
		return @type;
	}

	foreach my $ext ( keys %EPrints::Plugin::Convert::PlainText::APPS )
	{
		my $cmd_id = $EPrints::Plugin::Convert::PlainText::APPS{$ext};

		if( $fn =~ /\.$ext$/ )
		{
			if( $plugin->get_repository->can_execute( $cmd_id ) )
			{
				return @type;
			}
		}
	}
	
	return ();
}

sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	# What to call the temporary file
	my $main = $doc->get_main;
	
	my( $file_extension, $cmd_id );
	
	my $repository = $plugin->get_repository();

	# Find the app to use
	foreach my $ext ( keys %EPrints::Plugin::Convert::PlainText::APPS )
	{
		$file_extension = $ext;
		if( $main =~ /\.$ext$/i )
		{
			$cmd_id = $EPrints::Plugin::Convert::PlainText::APPS{$ext};
			last if $repository->can_execute( $cmd_id );
			last if $cmd_id eq "_special";
		}

		undef $cmd_id;
	}
	return () unless defined $cmd_id;
	
	my @txt_files;
	foreach my $file ( @{($doc->get_value( "files" ))} )
	{
		my $filename = $file->get_value( "filename" );
		my $tgt = $filename;
		next unless $tgt =~ s/\.$file_extension$/\.txt/;
		my $outfile = "$dir/$tgt";
		
		if( $file->get_value( "mime_type" ) eq "text/plain" )
		{
			open( my $fo, ">", $outfile );
			binmode($fo, ":utf8");
			$file->get_file(sub {
				my( $buffer ) = @_;

				print $fo $buffer;
			});
			close( $fo );
		}
		else
		{
			my $infile = $file->get_local_copy;
			if( !$infile )
			{
				$repository->log( "get_local_copy failed for file.".$file->id );
				return ();
			}
			$repository->exec( $cmd_id,
				SOURCE => $infile,
				TARGET_DIR => $dir,
				TARGET => $outfile,
			);
		}
		EPrints::Utils::chown_for_eprints( $outfile );
	
		if( !-e $outfile || -z $outfile )
		{		
			if( $filename eq $doc->get_main )
			{
				return ();
			}
			else
			{
				next;
			}
		}

		if( $filename eq $doc->get_main ) 
		{
			unshift @txt_files, $tgt;
		} 
		else 
		{
			push @txt_files, $tgt;
		}
	}

	return @txt_files;
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

