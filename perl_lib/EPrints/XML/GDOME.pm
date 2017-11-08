######################################################################
#
# EPrints::XML::GDOME
#
######################################################################
#
#
######################################################################


=pod

=head1 NAME

B<EPrints::XML::GDOME> - GDOME subs for EPrints::XML

=head1 DESCRIPTION

This module is not a package, it's a set of subroutines to be
loaded into EPrints::XML namespace if we're using XML::GDOME

=over 4

=cut

require XML::GDOME;
use XML::Parser;

$EPrints::XML::CLASS = "EPrints::XML::GDOME";

$EPrints::XML::LIB_LEN = length("XML::GDOME::");

# DOM spec fixes
*XML::GDOME::Attr::localName = sub {
		my $name = shift->getNodeName(@_);
		$name =~ s/^.*://;
		return $name;
	};

*XML::GDOME::Document::setDocumentElement = sub {
		my( $self, $node ) = @_;
		$node->parentNode->removeChild( $node );
		$self->appendChild( $node );
	};

# Need to clone children for DocumentFragment::cloneNode 
*XML::GDOME::DocumentFragment::cloneNode = sub {
		my( $self, $deep ) = @_;

		$deep = 0 if !defined $deep;

		my $f = $self->ownerDocument->createDocumentFragment;
		for($self->childNodes)
		{
			$f->appendChild( $_->cloneNode( $deep ) );
		}

		return $f;
	};

sub parse_xml_frag_string
{
	# FIXME: bet this doesn't like missing <?xml?> and stuff
	my $doc = parse_xml_string( @_ );

	my $frag = XML::GDOME->createDocument->createDocumentFragment;
	for($doc->childNodes)
	{
		$frag->appendChild( $_->cloneNode( 1 ) );
	}
	return $frag;
}

sub parse_xml_string
{
	my( $string ) = @_;

	my $doc;
	# For some reason the GDOME constants give an error,
	# using their values instead (could cause a problem if
	# they change in a subsequent version).

	my $opts = 8; #GDOME_LOAD_COMPLETE_ATTRS
	#unless( $no_expand )
	#{
		#$opts += 4; #GDOME_LOAD_SUBSTITUTE_ENTITIES
	#}
	$doc = XML::GDOME->createDocFromString( $string, $opts );

	return $doc;
}

sub _parse_url
{
	my( $url, $no_expand ) = @_;

	my $opts = 8; #GDOME_LOAD_COMPLETE_ATTRS
	unless( $no_expand )
	{
		$opts += 4; #GDOME_LOAD_SUBSTITUTE_ENTITIES
	}
	my $doc = XML::GDOME->createDocFromURI( "$url", $opts );

	return $doc;
}

sub parse_xml
{
	my( $file, $basepath, $no_expand ) = @_;

	unless( -r $file )
	{
		EPrints::abort( "Can't read XML file: '$file'" );
	}

	my $tmpfile = $file;
	if( defined $basepath )
	{	
		$tmpfile =~ s#/#_#g;
		$tmpfile = $basepath."/".$tmpfile;
		symlink( $file, $tmpfile );
	}

	# For some reason the GDOME constants give an error,
	# using their values instead (could cause a problem if
	# they change in a subsequent version).

	my $opts = 8; #GDOME_LOAD_COMPLETE_ATTRS
	unless( $no_expand )
	{
		$opts += 4; #GDOME_LOAD_SUBSTITUTE_ENTITIES
	}
	my $doc = XML::GDOME->createDocFromURI( $tmpfile, $opts );
	if( defined $basepath )
	{
		unlink( $tmpfile );
	}
	return $doc;
}

=item event_parse( $fh, $handler )

Parses the XML from filehandle $fh, calling the appropriate events
in the handler where necessary.

=cut

sub event_parse
{
	my( $fh, $handler ) = @_;	
	
	my $parser = new XML::Parser(
		Style => "Subs",
		ErrorContext => 5,
		Handlers => {
		Start => sub { 
			my( $p, $v, %a ) = @_; 
			my $attr = {};
			foreach my $k ( keys %a )
			{
				my( $prefix, $localname ) = split /:/, $k;
				($prefix,$localname) = ('',$prefix) if !$localname;
				$attr->{'{}'.$k} = { Prefix=>$prefix, LocalName=>$localname, Name=>$k, Value=>$a{$k} };
			}
			my( $prefix, $localname ) = split /:/, $v;
			($prefix,$localname) = ('',$prefix) if !$localname;
			$handler->start_element( { Prefix=>$prefix, LocalName=>$localname, Name=>$v, Attributes=>$attr } );
		},
		End => sub { 
			my( $p, $v ) = @_; 
			my( $prefix, $localname ) = split /:/, $v;
			($prefix,$localname) = ('',$prefix) if !$localname;
			$handler->end_element( { Prefix=>$prefix, LocalName=>$localname, Name=>$v } );
		},
		Char => sub { 
			my( $p, $data ) = @_; 
			$handler->characters( { Data=>$data } );
		},
	} );

	$parser->parse( $fh );
}


sub _dispose
{
	my( $node ) = @_;
}

sub clone_and_own
{
	my( $node, $doc, $deep ) = @_;

	if( !defined $node )
	{
		EPrints::abort( "no node passed to clone_and_own" );
	}

	my $newnode;
	$deep = 0 unless defined $deep;

	# XML::GDOME
	if( is_dom( $node, "DocumentFragment" ) )
	{
		$newnode = $doc->createDocumentFragment;

		if( $deep )
		{	
			foreach my $c ( $node->getChildNodes )
			{
				$newnode->appendChild( 
					$doc->importNode( $c, 1 ) );
			}
		}
	}
	else
	{
		$newnode = $doc->importNode( $node, $deep );
		# bug in importNode NOT being deep that it does
		# not appear to clone attributes, so lets work
		# around it!

		my $attrs = $node->getAttributes;
		if( $attrs )
		{
			for my $i ( 0..$attrs->getLength-1 )
			{
				my $attr = $attrs->item( $i );
				my $k = $attr->getName;
				my $v = $attr->getValue;
				$newnode->setAttribute( $k, $v );
			}
		}
	}

	return $newnode;
}

sub document_to_string
{
	my( $doc, $enc ) = @_;

	my $xml = $doc->toStringEnc( $enc );
	utf8::decode($xml);

	return $xml;
}

sub make_document
{
	# no params

	my $doc = XML::GDOME->createDocument( undef, "thing", undef );
	$doc->removeChild( $doc->getFirstChild );

	return $doc;
}

sub version
{
	"XML::GDOME $XML::GDOME::VERSION ".$INC{'XML/GDOME.pm'};
}

package EPrints::XML::GDOME;

our @ISA = qw( EPrints::XML );

use strict;

sub clone_node
{
	my( $self, $node ) = @_;

	# backwards compatibility
	if( !$self->isa( "EPrints::XML" ) )
	{
		my $deep = $node;
		$node = $self;
		return EPrints::XML::clone_and_own( $node, $node->ownerDocument, $deep );
	}

	return EPrints::XML::clone_and_own( $node, $self->{doc}, 0 );
}

sub to_string
{
	if( !$_[0]->isa( "EPrints::XML" ) )
	{
		return &_to_string;
	}

	my( $self, $node, %opts ) = @_;

	# XML:GDOME::Node doesn't support indenting
	my $string = $node->toString();
	utf8::decode($string) unless utf8::is_utf8($string);

	return $string;
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

