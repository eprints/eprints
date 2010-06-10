package EPrints::Plugin::Import::PDF;

@ISA = qw( EPrints::Plugin::Import );

use strict;

use ParaTools::DocParser::Standard;

sub input_fh
{
	my( $self, %opts ) = @_;

	my $session = $self->{session};
	my $eprint = $opts{dataobj};
	my $filename = $opts{filename};

	my $flags = $opts{flags};

	my $main_doc = $eprint->create_subdataobj( 'documents', {
		format => 'application/pdf',
		main => $filename,
		files => [{
			filename => $filename,
			filesize => (-s $opts{fh}),
			_content => $opts{fh}
		}],
	} );

	$opts{document} = $main_doc;

	my @new_docs;

	if( $flags->{metadata} || $flags->{bibliography} )
	{
		my $main_file = $main_doc->stored_file( $main_doc->get_main );
		my $cp = $main_file->get_local_copy;

		my $cmd = sprintf("pdftotext -f 2 -enc UTF-8 -layout -htmlmeta %s -",
			quotemeta($cp)
		);
		open(my $fh, "$cmd|") or die "Error in $cmd: $!";
		binmode($fh);
		my $buffer = "";
		while(<$fh>)
		{
			$buffer .= $_;
			last if length($buffer) > 10 * 1024 * 1024; # 10 MB
		}
		close($fh);

		if( $flags->{metadata} )
		{
			$self->_parse_metadata( $buffer, %opts );
		}

		if( $flags->{bibliography} )
		{
			push @new_docs, $self->_parse_bibliography( $buffer, %opts );
		}
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
	$eprint->commit;

	return EPrints::List->new(
		session => $self->{session},
		dataset => $main_doc->dataset,
		ids => [map { $_->id } $main_doc, @new_docs ]
	);
}

sub _parse_metadata
{
	my( $self, $buffer, %opts ) = @_;

	my $eprint = $opts{dataobj};

	my %data;

	$buffer =~ /<title>([^<]+)<\/title>/;
	if( $1 )
	{
		$data{title} = $1;
	}

	pos($buffer) = 0;
	while( $buffer =~ m/<meta name="([a-z]+)" content="([^"]+)">/ig )
	{
		my( $name, $value ) = (lc($1), $2);
		next if !$value;
		if( $name eq "keywords" )
		{
			$data{keywords} = Encode::decode_utf8( $value );
		}
		elsif( $name eq "author" )
		{
			$data{creators_name} = Encode::decode_utf8( $value );
		}
	}

	while(my( $n, $v ) = each %data)
	{
		next if !$eprint->dataset->has_field( $n );
		next if $eprint->is_set( $n );
		if( $n eq "creators_name" )
		{
			my @names = split /\s*,\s*/, $v;
			for(@names)
			{
				s/\s*(\S+)$//;
				$_ = {
					family => $1,
					given => $_,
				};
			}
			$v = \@names;
		}

		$eprint->set_value( $n, $v );
	}
}

sub _parse_bibliography
{
	my( $self, $buffer, %opts ) = @_;

	my $eprint = $opts{dataobj};

	return () if !$eprint->dataset->has_field( "referencetext" );

	$buffer =~ s/^.*?<pre>//s;
	$buffer =~ s/<\/pre>.*?$//s;

	local $ParaTools::DocParser::Standard::DEBUG = 1;
	my $parser = ParaTools::DocParser::Standard->new;

	my $main_doc = $opts{document};

	my $bibl_doc = $eprint->create_subdataobj( "documents", {
			format => "text/plain",
			content => "bibliography",
			main => "bibliography.txt",
			relation => [{
				type => EPrints::Utils::make_relation( "isVolatileVersionOf" ),
				uri => $main_doc->internal_uri(),
				},{
				type => EPrints::Utils::make_relation( "isVersionOf" ),
				uri => $main_doc->internal_uri(),
				},{
				type => EPrints::Utils::make_relation( "isPartOf" ),
				uri => $main_doc->internal_uri(),
			}],
			files => [{
				filename => "bibliography.txt",
				filesize => length( $buffer ),
				_content => \$buffer,
			}],
		});
	if( !defined $bibl_doc )
	{
		EPrints->abort( "Error creating bibliography document" );
	}

	my @refs = $parser->parse( Encode::decode_utf8( $buffer ) );

	if( @refs )
	{
		$eprint->set_value( "referencetext", join("\n\n", @refs ) );
	}

	return( $bibl_doc );
}

1;
