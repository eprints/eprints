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
		push @new_docs, $self->add_pdf( $main_doc, $pdf, %opts );
	}

	my $aux = $parts{main} . ".aux";
	my $bib = $parts{main} . ".bib";
	if( $opts{flags}->{bibliography} && -f $aux && -f $bib )
	{
		push @new_docs, $self->add_bibl( $main_doc, $aux, $bib, %opts );
	}

	# add the reciprocal relations
	foreach my $new_doc ( @new_docs )
	{
		foreach my $relation ( @{$new_doc->value( "relation" )} )
		{
			next if $relation->{uri} ne $main_doc->internal_uri;
			my $type = $relation->{type};
			next if $type !~ s# /is(\w+)Of$ #/has$1#x;
			$main_doc->add_object_relations(
				$new_doc,
				$type
			);
		}
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

	my $dir = File::Temp->newdir();

	my $rc = $self->{session}->exec( "targz",
		DIR => $dir,
		ARC => $tmpfile
	);

	return $rc == 0 ? $dir : undef;
}

sub add_pdf
{
	my( $self, $main_doc, $pdf, %opts ) = @_;

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
		relation => [{
			type => EPrints::Utils::make_relation( "isVersionOf" ),
			uri => $main_doc->internal_uri(),
		}],
	});
}

sub add_bibl
{
	my( $self, $main_doc, $aux, $bib, %opts ) = @_;

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

	push @new_docs, $opts{dataobj}->create_subdataobj( "documents", {
		format => "text/xml",
		content => "bibliography",
		relation => [{
			type => EPrints::Utils::make_relation( "isPartOf" ),
			uri => $main_doc->internal_uri(),
		},{
			type => EPrints::Utils::make_relation( "isVolatileVersionOf" ),
			uri => $main_doc->internal_uri(),
		}],
		files => [{
			filename => "eprints.xml",
			filesize => -s $bibl_file,
			_content => $bibl_file,
		}],
	} );

	return @new_docs;
}

1;
