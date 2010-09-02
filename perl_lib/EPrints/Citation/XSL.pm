######################################################################
#
# EPrints::Citation::XSL
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::Citation::XSL> - loading and rendering of citation styles

=cut

package EPrints::Citation::XSL;

@ISA = qw( EPrints::Citation );

use XML::LibXSLT 1.70;
use strict;

sub load_source
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $file = $self->{filename};

	my $doc = $repo->parse_xml( $file, 1 );
	return if !$doc;

	my $type = $doc->getDocumentElement->getAttribute( "ept:type" );
	$type = "default" unless EPrints::Utils::is_set( $type );

	my $xslt = XML::LibXSLT->new;
	$self->_ep( $xslt );

	my $stylesheet = $xslt->parse_stylesheet( $doc );

	$self->{xslt} = $xslt;
	$self->{type} = $type;
	$self->{style} = $stylesheet;
	$self->{mtime} = EPrints::Utils::mtime( $file );

	$repo->xml->dispose( $doc );

	return 1;
}
=item $frag = $citation->render( $dataobj, %opts )

Renders a L<EPrints::DataObj> using this citation style.

=cut

sub render
{
	my( $self, $dataobj, %opts ) = @_;

	local $self->{item} = $dataobj;
	local $self->{opts} = \%opts;

	my $xml = $dataobj->to_xml;
	my $doc = $xml->ownerDocument;
	$doc->setDocumentElement( $xml );

	my $r = $self->{style}->transform( $doc );

	return $self->{repository}->xml->contents_of( $r->documentElement );
}

sub _ep
{
	my( $self, $xslt ) = @_;

	my $repo = $self->{repository};

	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"phrase",
		sub { $repo->phrase( $_[0] ) }
	);
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"html_phrase",
		sub { &_nodelist( $repo->html_phrase( $_[0] ) ) }
	);
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"value",
		sub { $self->{item}->value( $_[0] ) }
	);
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"render_value",
		sub { &_nodelist( $self->{item}->render_value( $_[0] ) ) }
	);
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"citation",
		sub { &_nodelist( $self->{item}->render_citation( $_[0], %{$self->{opts}} ) ) }
	);
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"param",
		sub {
			my $p = $self->{opts}->{$_[0]};
			return $p if ref($p) ne "ARRAY";
			return $p->[1] eq "XHTML" ?
				&_nodelist( $p->[0] ) :
				$p->[0];
		}
	);
}

sub _nodelist
{
	my( $frag ) = @_;

	# WARNING: things break if it isn't exactly like this!
	my $nl = XML::LibXML::NodeList->new;
	$nl->push( map { $frag->removeChild( $_ ) } $frag->childNodes );
	return $nl;
}

$EPrints::Citation::XSL = 1;
1;
