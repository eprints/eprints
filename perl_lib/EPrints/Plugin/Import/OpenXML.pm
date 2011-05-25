=head1 NAME

EPrints::Plugin::Import::OpenXML

=cut

package EPrints::Plugin::Import::OpenXML;

use EPrints::Plugin::Import;

@ISA = qw( EPrints::Plugin::Import );

use strict;

# adpated from Import::DSpace:
our $GRAMMAR = {
                'dcterms:created' => [ 'date' ],
                'dc:publisher' => [ 'publisher' ],
                'dc:title' => [ 'title' ],
                'dc:description' => [ 'abstract', \&ep_dc_join ],
                'dc:creator' => [ 'creators_name', \&ep_dc_creator ],
                'dc:rights' => [ 'notes' ],
};


our $SWORD_GRAMMAR = {
		'my:kwd.controltype.richtextbox.' => ['keywords'],
		'my:contrib.' => ['creators_name']
};

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Import (openxml)";
	$self->{produce} = [qw( dataobj/eprint )];
	$self->{accept} = [qw( application/vnd.openxmlformats-officedocument.wordprocessingml.document application/vnd.openxmlformats application/msword )];
	$self->{advertise} = 1;
	$self->{actions} = [qw( metadata media bibliography )];

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $session = $self->{session};

	my %flags = map { $_ => 1 } @{$opts{actions}};
	my $filename = $opts{filename};

	my $format = $session->call( "guess_doc_type", $session, $filename );

	my $epdata = {
		documents => [{
			format => $format,
			main => $filename,
			files => [{
				filename => $filename,
				filesize => (-s $opts{fh}),
				_content => $opts{fh}
			}],
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
	if( !$dir )
	{
		$self->error( $self->phrase( "zip_failed" ) );
	}
	$epdata->{$dir} = $dir; # keep our temp files as long as epdata exists

	my @new_docs;

	if( $flags{metadata} )
	{
		$self->_parse_dc( $dir, %opts, epdata => $epdata );
	}

	if( $flags{media} )
	{
		$self->_extract_media_files( $dir, %opts, epdata => $epdata );
	}

	if( $flags{bibliography} )
	{
		$self->_extract_bibl( $dir, %opts, epdata => $epdata );
	}

	my @ids;
	my $dataobj = $self->epdata_to_dataobj( $opts{dataset}, $epdata );
	push @ids, $dataobj->id if $dataobj;

	return EPrints::List->new(
		session => $session,
		dataset => $opts{dataset},
		ids => \@ids,
	);
}

sub _extract_bibl
{
	my( $self, $dir, %opts ) = @_;

	my $session = $self->{session};
	my $xml = $session->xml;
	my $epdata = $opts{epdata};

	my $bibl_file = File::Temp->new;
	binmode($bibl_file, ":utf8");

	my $custom_dir = "$dir/customXml";

	opendir(my $dh, $custom_dir) or return;
	while(my $fn = readdir($dh))
	{
		next if $fn !~ /^itemProps(\d+)\.xml$/;
		my $idx = $1;

		next if !-e "$custom_dir/item$idx.xml";

		my $doc = eval { $xml->parse_file( "$custom_dir/$fn" ) };
		next if !defined $doc;

		my( $schemaRef ) = $doc->documentElement->getElementsByTagNameNS(
			"http://schemas.openxmlformats.org/officeDocument/2006/customXml",
			"schemaRef"
		);
		next if !defined $schemaRef;

		my $uri = $schemaRef->getAttributeNS(
			"http://schemas.openxmlformats.org/officeDocument/2006/customXml",
			"uri" );		
		next if !defined $uri;
		next if $uri ne "http://schemas.openxmlformats.org/officeDocument/2006/bibliography";

		$doc = eval { $xml->parse_file( "$custom_dir/item$idx.xml" ) };
		next if !defined $doc;

		$self->_extract_references( $bibl_file, $doc );
		last;
	}
	closedir($dh);

	seek($bibl_file,0,0);
	return if !-s $bibl_file;

	push @{$epdata->{documents}}, {
		format => "text/xml",
		content => "bibliography",
		files => [{
			filename => "eprints.xml",
			filesize => (-s $bibl_file),
			mime_type => "text/xml",
			_content => $bibl_file,
		}],
#		relation => [{
#			type => EPrints::Utils::make_relation( "isVolatileVersionOf" ),
#			uri => $main_doc->internal_uri(),
#			},{
#			type => EPrints::Utils::make_relation( "isVersionOf" ),
#			uri => $main_doc->internal_uri(),
#			},{
#			type => EPrints::Utils::make_relation( "isPartOf" ),
#			uri => $main_doc->internal_uri(),
#		}],
	};
}

sub _extract_references
{
	my( $self, $tmp, $doc ) = @_;

	my $session = $self->{session};

	my $translator = $session->plugin( "Import::XSLT::OpenXMLBibl" );
	return if !defined $translator;

	my $epxml = $translator->transform( $doc );
	if( !$epxml->documentElement->getElementsByTagName( 'eprint' )->length )
	{
		return;
	}

	print $tmp $session->xml->to_string( $epxml );
}

sub _extract_media_files
{
	my( $self, $dir, %opts ) = @_;

	my $session = $self->{session};
	my $epdata = $opts{epdata};

	my $content_dir;

	if( -d "$dir/word" )
	{
		$content_dir = "word";
	}
	elsif( -d "$dir/ppt" )
	{
		$content_dir = "ppt";
	}
	else
	{
		return; # unknown doc type
	}

	my @new_docs;
	
	my $media_dir = "$dir/$content_dir/media";

	return @new_docs if !-d $media_dir;

	my @files;

	opendir( my $dh, $media_dir ) or return; # error ?
	foreach my $fn (readdir($dh))
	{
		next if $fn =~ /^\./;
		push @files, [$fn => "$media_dir/$fn"];
	}
	closedir $dh;

	if( $content_dir eq 'ppt' )
	{
		my $thumbnail = "$dir/docProps/thumbnail.jpeg";
		if( -e $thumbnail )
		{
			push @files, ["thumbnail.jpeg" => $thumbnail];
		}
	}

	foreach my $file (@files)
	{
		my( $filename, $filepath ) = @$file;
		open(my $fh, "<", $filepath) or die "Error opening $filename: $!";
		push @{$epdata->{documents}}, {
			main => $filename,
			format => $session->call( "guess_doc_type", $session, $filename ),
			files => [{
				filename => $filename,
				filesize => (-s $fh),
				_content => $fh
			}],
#			relation => [{
#				type => EPrints::Utils::make_relation( "isVersionOf" ),
#				uri => $doc->internal_uri(),
#				},{
#				type => EPrints::Utils::make_relation( "isPartOf" ),
#				uri => $doc->internal_uri(),
#			}],
		};
	}
}

sub _parse_dc
{
	my( $self, $dir, %opts ) = @_;

	my $epdata = $opts{epdata};
	my $xml = $self->{session}->xml;

	my $dom_doc = eval { $xml->parse_file( "$dir/docProps/core.xml" ) };
	return if !defined $dom_doc;
	my $root = $dom_doc->documentElement;

	return if lc($root->tagName) ne 'cp:coreproperties';

	my %dc;

	foreach my $node ($root->childNodes)
	{
		my $name = lc($node->nodeName);
		my $value = $xml->text_contents_of( $node );
		next unless exists $GRAMMAR->{$name};
		next unless EPrints::Utils::is_set( $value );

		push @{$dc{$name}}, $value;
	}

	while(my( $name, $values ) = each %dc)
	{
		my( $fieldname, $f ) = @{$GRAMMAR->{$name}};
		next unless $opts{dataset}->has_field( $fieldname );
		my $field = $opts{dataset}->field( $fieldname );

		if( defined $f )
		{
			$values = &$f( $self, $values, $fieldname );
		}

		$epdata->{$fieldname} = $field->property( "multiple" ) ?
			$values :
			$values->[0];
	}

	$dom_doc = eval { $xml->parse_file( "$dir/word/document.xml" ) };

	if( defined $dom_doc )
	{
		$root = $dom_doc->documentElement;
		foreach my $alias ($root->getElementsByLocalName( "alias" ))
		{

			my $type = lc($alias->getAttribute( "w:val" ));

			if( $type eq "title" || $type eq "abstract" )
			{
				my $sdt = $alias;
				while( $sdt && $sdt->nodeName ne "w:sdt" )
				{
					$sdt = $sdt->parentNode;
				}
				next if !defined $sdt;
				$epdata->{$type} = $xml->text_contents_of( $sdt );
			}
		}
	}
	
	my @names;
	my @emails;
	my $keys;

	my $custom_dir = "$dir/customXml";

	opendir(my $dh, $custom_dir) or return;
	while(my $fn = readdir($dh))
	{
		next if $fn !~ /^item(\d+)\.xml$/;
		my $idx = $1;

		next if !-e "$custom_dir/item$idx.xml";

		my $dom_doc = eval { $xml->parse_file( "$custom_dir/$fn" ) };
		next if !defined $dom_doc;
	
		$root = $dom_doc->documentElement;

		foreach my $contrib ($root->getElementsByLocalName("contrib."))
		{
			my $name = ($contrib->getChildrenByLocalName("name."))[0];
			my( $surname ) = $name->getElementsByLocalName("surname.");
			my( $given ) = $name->getElementsByLocalName("given-names.");
			my $address = ($contrib->getChildrenByLocalName("address."))[0];
			my $email_node = ($address->getElementsByLocalName("email-details"))[0];
			my( $email ) = ($email_node->getElementsByLocalName("email."))[0];
			push @names, {
				family => $surname->textContent,
				given => $given->textContent,
			};
			push @emails, $email->textContent;
		}

		my $kwd_node = ($root->getElementsByLocalName("kwd-group."))[0];
		if (defined $kwd_node) {
			foreach my $keyword($kwd_node->getElementsByLocalName("title.controltype.richtextbox.")) {
				$keys .= $keyword->textContent . ", ";
			}
			foreach my $node($kwd_node->getElementsByLocalName("kwd")) {
				my $keyword = ($node->getElementsByLocalName("kwd.controltype.richtextbox."))[0];
				$keys .= $keyword->textContent . ", ";
			}
		}
	}
	$epdata->{creators_id} = \@emails if scalar @emails;
	$epdata->{creators_name} = \@names if scalar @names;
	if (defined $keys) {
		$keys =  substr($keys,0,length($keys)-2);
		$epdata->{keywords} = $keys;
	}
}

# there's only one creator in openxml (the owner of the doc I guess)
sub ep_dc_creator
{
	my( $self, $values, $fieldname ) = @_;

	return [map {
		my( $given, $family ) = split /\s* \s*/, $_;
		{
			family => $family,
			given => $given,
		}
	} @$values];
}

sub ep_dc_join
{
	my( $self, $values, $fieldname ) = @_;

	return [join("\n", @$values)];
}

sub unpack
{
	my( $self, $tmpfile, %opts ) = @_;

	my $dir = File::Temp->newdir();

	my $rc = $self->{session}->exec( "zip",
		DIR => $dir,
		ARC => $tmpfile
	);

	return $rc == 0 ? $dir : undef;
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

