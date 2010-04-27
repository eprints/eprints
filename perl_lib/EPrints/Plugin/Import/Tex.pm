package EPrints::Plugin::Import::Tex;

use EPrints::Plugin::Import;
@ISA = qw( EPrints::Plugin::Import );

use strict;

sub input_fh
{
	my( $self, %opts ) = @_;

	my $eprint = $opts{dataobj};

	my @new_docs;

	my $tmpfile = File::Temp->new;
	binmode($tmpfile);

	while(sysread($opts{fh}, my $buffer, 4096))
	{
		syswrite($tmpfile, $buffer);
	}
	seek($tmpfile,0,0);

	my $filename = $opts{filename} || "main.tgz";

	my $main_doc = $eprint->create_subdataobj( "documents", {
		format => "application/x-gzip",
		main => $filename,
		files => [{
			filename => $filename,
			filesize => (-s "$tmpfile"),
			_content => $tmpfile,
		}],
	});
	if( !defined $main_doc )
	{
		$self->error( $self->phrase( "create_failed" ) );
	}

	$opts{document} = $main_doc;

	my $dir = $self->unpack( $tmpfile, %opts );

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
	if( $opts{flags}->{media} && -f $pdf )
	{
		push @new_docs, $self->add_pdf( $pdf, %opts );
	}

	my $aux = $parts{main} . ".aux";
	my $bib = $parts{main} . ".bib";
	if( $opts{flags}->{bibliography} && -f $aux && -f $bib )
	{
		push @new_docs, $self->add_bibl( $aux, $bib, %opts );
	}

	for(@new_docs)
	{
		$_->add_object_relations( $main_doc,
			EPrints::Utils::make_relation( "isVolatileVersionOf" ),
			EPrints::Utils::make_relation( "hasVolatileVersion" ),
		);
		$_->commit;
	}

	$main_doc->commit;

	return EPrints::List->new(
		session => $self->{session},
		dataset => $main_doc->get_dataset,
		ids => [map { $_->id } $main_doc, @new_docs] );
}

sub unpack
{
	my( $self, $tmpfile, %opts ) = @_;

	my $dir = EPrints::TempDir->new( CLEANUP => 1 );

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

	my $fh;
	open($fh, "<", $pdf) or EPrints->abort( "Error opening $pdf: $!" );

	return $opts{dataobj}->create_subdataobj( "documents", {
		format => "application/pdf",
		main => $filename,
		files => [{
			filename => $filename,
			filesize => (-s $pdf),
			_content => $fh,
		}],
	});
}

sub add_bibl
{
	my( $self, $aux, $bib, %opts ) = @_;

	my @new_docs;

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
			my $xml = $dataobj->render_citation;
			push @bibls, join '', $self->{session}->xhtml->to_xhtml( $xml );
		}
	}

	$opts{dataobj}->set_value( "bibliography", \@bibls );

	return @new_docs;
}

1;
