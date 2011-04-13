=head1 NAME

EPrints::Plugin::Import::Tex

=cut

package EPrints::Plugin::Import::Tex;

use EPrints::Plugin::Import;
@ISA = qw( EPrints::Plugin::Import );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Import (LaTeX)";
	$self->{produce} = [qw( dataobj/eprint )];
	$self->{accept} = [qw( application/x-latex )];
	$self->{advertise} = 0;

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $filename = $opts{filename};
	my %flags = map { $_ => 1 } @{$opts{actions}};

	my $epdata = {
		format => "application/x-gzip",
		main => $filename,
		files => [{
			filename => $filename,
			filesize => (-s $opts{fh}),
			_content => $opts{fh},
		}],
	};

	my $filepath = "$opts{fh}";
	if( !-f $filepath ) # need to make a copy for our purposes :-(
	{
		$filepath = File::Temp->new;
		binmode($filepath);
		while(sysread($opts{fh},$_,4096))
		{
			syswrite($filepath,$_);
		}
		seek($opts{fh},0,0);
		seek($filepath,0,0);
	}

	my $dir = $self->unpack( $filepath, %opts );

	my %parts;

	File::Find::find( {
		no_chdir => 1,
		wanted => sub {
			my $filepath = $File::Find::name;
			my $filename = substr( $filepath, length($dir) );
			$parts{main} = $filepath if $filename =~ /\.out$/;
			push @{$parts{bib}}, $filepath if $filename =~ /\.bib$/;
		},
	}, "$dir" );

	if( !$parts{main} )
	{
		$self->warning( $self->html_phrase( "missing_out_file" ) );
		$parts{main} = "";
	}
	else
	{
		$parts{main} =~ s/\.out$//;
	}

	my $pdf = $parts{main} . ".pdf";
	if( $flags{media} && -f $pdf )
	{
		$self->add_pdf( $pdf, %opts, epdata => $epdata );
	}

	my $aux = $parts{main} . ".aux";
	my $bib = $parts{main} . ".bib";
	if( $flags{bibliography} && -f $aux && -f $bib )
	{
		$self->add_bibl( $aux, $bib, %opts, epdata => $epdata );
	}

	my @ids;
	my $dataobj = $self->epdata_to_dataobj( $opts{dataset}, $epdata );
	push @ids, $dataobj->id if $dataobj;

	return EPrints::List->new(
		session => $self->{session},
		dataset => $opts{dataset},
		ids => \@ids
	);
}

sub unpack
{
	my( $self, $tmpfile, %opts ) = @_;

	my $dir = File::Temp->newdir();

	my $rc = $self->{session}->exec( "targz",
		DIR => $dir,
		ARC => $tmpfile
	);

	return $rc == 0 ? $dir : undef;
}

sub add_pdf
{
	my( $self, $pdf, %opts ) = @_;

	my $filename = $pdf;
	$filename =~ s/^.*\///;

	open(my $fh, "<", $pdf) or EPrints->abort( "Error opening $pdf: $!" );

	push @{$opts{epdata}->{documents}}, {
		format => "application/pdf",
		main => $filename,
		files => [{
			filename => $filename,
			filesize => (-s $pdf),
			_content => $fh,
		}],
	};
}

sub add_bibl
{
	my( $self, $aux, $bib, %opts ) = @_;

	my $fh;

	my $filename = $bib;
	$filename =~ s/^.*\///;

	open($fh, "<", $bib) or die "Error opening $bib: $!";

	my %entries;

	my $parser = BibTeX::Parser->new( $fh );
	while(my $entry = $parser->next)
	{
		next if !$entry->parse_ok;

		$entries{$entry->key} = $entry;
	}

	my $translator = $self->{session}->plugin( "Import::BibTeX" );

	open($fh, "<", $aux) or die "Error opening $aux: $!";

	my @bibls;

	my $dataset = $self->{session}->dataset( "eprint" );
	my $class = $dataset->get_object_class;

	my $bibl_file = File::Temp->new;
	binmode($bibl_file, ":utf8");
	print $bibl_file "<?xml version='1.0'?>\n<eprints>";

	while(<$fh>)
	{
		if( /\\bibcite\{([^\}]+)\}/ )
		{
			my $entry = $entries{$1};
			next if !defined $entry;

			my $epdata = $translator->convert_input( $entry );
			$epdata->{eprint_status} = "inbox";
			my $dataobj = $class->new_from_data(
					$self->{session},
					$epdata,
					$dataset );
			print $bibl_file $self->{session}->xml->to_string(
				$dataobj->to_xml
			);
		}
	}

	print $bibl_file "</eprints>";
	seek($bibl_file,0,0);

	push @{$opts{epdata}->{documents}}, {
		format => "text/xml",
		content => "bibliography",
		files => [{
			filename => "eprints.xml",
			filesize => (-s $bibl_file),
			mime_type => "text/xml",
			_content => $bibl_file,
		}],
	};
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

