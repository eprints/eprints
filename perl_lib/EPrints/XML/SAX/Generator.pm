# $Id: Generator.pm 772 2009-01-23 21:42:09Z pajas 
#
# This is free software, you may use it and distribute it under the same terms as
# Perl itself.
#
# Copyright 2001-2003 AxKit.com Ltd., 2002-2006 Christian Glahn, 2006-2009 Petr Pajas
#
#

package EPrints::XML::SAX::Generator;

use EPrints::Const;
use XML::NamespaceSupport;

our %NS;

use strict;

sub new {
    my $class = shift;
    unshift @_, 'Handler' unless @_ != 1;
    return bless {@_}, $class;
}

sub generate {
    my $self = shift;
    my ($node) = @_;
    
	$NS{$self->{Handler}} = XML::NamespaceSupport->new;

    $self->{Handler}->start_document({});
    process_node($self->{Handler}, $node);
    my $r = $self->{Handler}->end_document({});

	delete $NS{$self->{Handler}};
	
	return $r;
}

sub process_node {
    my ($handler, $node) = @_;
    
    my $node_type = $node->nodeType();
    if ($node_type == XML_COMMENT_NODE) {
        $handler->comment( { Data => $node->nodeValue } );
    }
    elsif ($node_type == XML_TEXT_NODE || $node_type == XML_CDATA_SECTION_NODE) {
        $handler->characters( { Data => $node->nodeValue } );
    }
    elsif ($node_type == XML_ELEMENT_NODE) {
        process_element($handler, $node);
    }
    elsif ($node_type == XML_ENTITY_REFERENCE_NODE) {
        foreach my $kid ($node->childNodes) {
            process_node($handler, $kid);
        }
    }
    elsif ($node_type == XML_DOCUMENT_NODE) {
		process_element($handler,$node->documentElement);
    }
    else {
        warn("unknown node type: $node_type");
    }
}

sub process_element {
    my ($handler, $element) = @_;
    
    my @attr;
    
	my $ns = $NS{$handler};

	$ns->push_context;

	if( $element->can( "namespaceURI" ) && !defined($ns->get_uri( $element->prefix || '' )) )
	{
		$ns->declare_prefix( $element->prefix || '', $element->namespaceURI );
		$handler->start_prefix_mapping({
			Prefix => $element->prefix || '',
			NamespaceURI => $element->namespaceURI,
		});
	}

    foreach my $attr ($element->attributes) {
		next if $attr->isa( "XML::LibXML::Namespace" ); # urg

		if( $attr->can( "namespaceURI" ) && !defined($ns->get_uri( $attr->prefix || '' )) )
		{
			$ns->declare_prefix( $attr->prefix || '', $attr->namespaceURI );
			$handler->start_prefix_mapping({
				Prefix => $attr->prefix || '',
				NamespaceURI => $attr->namespaceURI,
			});
		}

        push @attr, {
            Name => $attr->nodeName,
            Value => $attr->nodeValue,
            LocalName => $attr->localName,
            Prefix => $attr->prefix,
            NamespaceURI => $attr->can( "namespaceURI" ) ? $attr->namespaceURI : '',
        };
    }
    
    my $node = {
        Name => $element->nodeName,
        Attributes => { map { sprintf("{%s}%s", $_->{namespaceURI}||'', $_->{LocalName}) => $_ } @attr },
        LocalName => $element->localName,
        Prefix => $element->prefix,
        NamespaceURI => $element->can( "namespaceURI" ) ? $element->namespaceURI : '',
    };
    
    $handler->start_element($node);
    
    foreach my $child ($element->childNodes) {
        process_node($handler, $child);
    }
    
    $handler->end_element($node);

	foreach my $prefix ($ns->get_declared_prefixes)
	{
		$handler->end_prefix_mapping({
			Prefix => $prefix,
			NamespaceURI => $ns->get_uri( $prefix ),
		});
	}

	$ns->push_context;
}

1;

__END__

=head1 NAME

XML::LibXML::SAX::Generator - Generate SAX events from a LibXML tree

=head1 SYNOPSIS

  my $handler = MySAXHandler->new();
  my $generator = XML::LibXML::SAX::Generator->new(Handler => $handler);
  my $dom = XML::LibXML->new->parse_file("foo.xml");
  
  $generator->generate($dom);

=head1 DESCRIPTION

THIS CLASS IS DEPRACED! Use XML::LibXML::SAX::Parser instead!

This helper class allows you to generate SAX events from any XML::LibXML
node, and all it's sub-nodes. This basically gives you interop from
XML::LibXML to other modules that may implement SAX.

It uses SAX2 style, but should be compatible with anything SAX1, by use
of stringification overloading.

There is nothing to really know about, beyond the synopsis above, and
a general knowledge of how to use SAX, which is beyond the scope here.

=cut
