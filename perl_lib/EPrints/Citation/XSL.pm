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

# libxslt extensions are library-global, so we only initialise them once
# that also means we have to use a global pointer to keep track of the current
# citation object (yuck)
our $__ep = 0;
our $CTX = undef;

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
	$self->_ep( $xslt ) if !$__ep;
	$__ep = 1;

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

	EPrints->abort( "Requires dataobj" )
		if !defined $dataobj;

	$self->freshen;

	# save and set the global context
	my $ctx = $EPrints::Citation::XSL::CTX;
	$EPrints::Citation::XSL::CTX = $self;

	local $self->{item} = $dataobj;
	local $self->{opts} = \%opts;
	local $self->{dataobjs} = {};

#	my $xml = $dataobj->to_xml;
#	my $doc = $xml->ownerDocument;
#	$doc->setDocumentElement( $xml );

	my $doc = XML::LibXML::Document->new( '1.0', 'utf-8' );
	$doc->setDocumentElement( $doc->createElement( 'root' ) );

	my $r = $self->{style}->transform( $doc );

	$EPrints::Citation::XSL::CTX = $ctx;

	return $self->{repository}->xml->contents_of( $r );
}

sub _ep
{
	my( $self, $xslt ) = @_;

	my $repo = $self->{repository};

	# ept:one_of
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"one_of",
		\&run_one_of
	);
	# ept:param
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"param",
		sub { &_self->run_param( @_ ) }
	);
	# ept:phrase
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"phrase",
		sub { &_nodelist( &_self->{repository}->html_phrase( $_[0] ) ) }
	);
	# ept:config
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"config",
		sub { &_self->{repository}->config( @_ ) }
	);
	# ept:value
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"value",
		sub { &_ctx_item; &_self->run_value( @_ ) }
	);
	# ept:render_value
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"render_value",
		sub { &_ctx_item; &_self->run_render_value( @_ ) }
	);
	# ept:citation
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"citation",
		sub { &_ctx_item; &_self->run_citation( @_ ) }
	);
	# ept:documents
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"documents",
		sub { &_ctx_item; &_self->run_documents( @_ ) }
	);
	# ept:icon
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"icon",
		sub { &_ctx_item; &_self->run_icon( @_ ) }
	);
	# ept:url
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"url",
		sub { &_ctx_item; &_self->run_url( @_ ) }
	);
	# ept:is_set
	$xslt->register_function(
		EPrints::Const::EP_NS_XSLT,
		"is_set",
		sub { &_ctx_item; $_[0]->exists_and_set( $_[1] ) ?
			XML::LibXML::Boolean->True :
			XML::LibXML::Boolean->False }
	);
}

# Turn a DocumentFragment into a NodeList
sub _nodelist
{
	my( $frag ) = @_;

	return $frag if !$frag->isa( "XML::LibXML::DocumentFragment" );

	# WARNING: things break if it isn't exactly like this!
	my $nl = XML::LibXML::NodeList->new;
	$nl->push( map { $frag->removeChild( $_ ) } $frag->childNodes );
	return $nl;
}

sub _self
{
	return $EPrints::Citation::XSL::CTX;
}

# Retrieve the current item in-context
sub _ctx_item
{
	my $self = &_self;

	if( UNIVERSAL::isa( $_[0], "XML::LibXML::NodeList" ) )
	{
		my $uri = shift @_;
		$uri = $uri->item( 0 );
		$uri = $uri->toString;
		unshift @_, $self->{dataobjs}->{$uri};
	}
	else
	{
		if( !defined $self->{item} )
		{
			EPrints->abort( "Something went wrong with the item: $self" );
		}
		unshift @_, $self->{item};
	}
}

sub error
{
	my( $self, $type, $message ) = @_;

	my $msg = "$self->{filename}: $message";
	$self->{repository}->log( $msg );

	return XML::LibXML::Text->new( "[ $msg ]" );
}

sub run_value
{
	my( $self, $item, $fieldid ) = @_;

	my $field = $item->dataset->field( $fieldid );
	return undef if !defined $field;

	if( $field->isa( "EPrints::MetaField::Subobject" ) )
	{
		my $nl = XML::LibXML::NodeList->new;
		foreach my $dataobj ( @{$field->get_value( $item )} )
		{
			my $uri = $dataobj->internal_uri;
			$self->{dataobjs}->{$uri} = $dataobj;
			$nl->push( XML::LibXML::Text->new( $uri ) );
		}
		return $nl;
	}
	elsif( $field->property( "multiple" ) )
	{
		my $nl = XML::LibXML::NodeList->new;
		foreach my $v ( @{$field->get_value( $item )} )
		{
			$nl->push( XML::LibXML::Text->new( $v ) );
		}
		return $nl;
	}
	else
	{
		return $field->get_value( $item );
	}
}

sub run_param
{
	my( $self, $key ) = @_;

	my $param = $self->{opts}->{$key};
	return $param if !ref $param; # simple type

	if( ref( $param ) eq "ARRAY" )
	{
		if( $param->[1] eq "XHTML" )
		{
			return &_nodelist( $param->[0] );
		}
		return $param->[0]; # simple type
	}

	return $param; # don't know?
}

sub run_citation
{
	my( $self, $item, $style, %params ) = @_;

	return &_nodelist( $item->render_citation( $style, %params ) );
}

sub run_documents
{
	my( $self, $item ) = @_;

	if( !$item->isa( "EPrints::DataObj::EPrint" ) )
	{
		return $self->error( "error", "documents() expected EPrints::DataObj::EPrint but got ".ref($item) );
	}

	my $nl = XML::LibXML::NodeList->new;
	foreach my $dataobj ($item->get_all_documents)
	{
		my $uri = $dataobj->internal_uri;
		$self->{dataobjs}->{$uri} = $dataobj;
		$nl->push( XML::LibXML::Text->new( $uri ) );
	}
	return $nl;
}

sub run_icon
{
	my( $self, $doc, @opts ) = @_;

	if( !$doc->isa( "EPrints::DataObj::Document" ) )
	{
		return $self->error( "error", "icon() expected EPrints::DataObj::Document but got ".ref($doc) );
	}

	my %args = ();
	foreach my $opt ( @opts )
	{
		if( $opt eq "HoverPreview" ) { $args{preview}=1; }
		elsif( $opt eq "noHoverPreview" ) { $args{preview}=0; }
		elsif( $opt eq "NewWindow" ) { $args{new_window}=1; }
		elsif( $opt eq "noNewWindow" ) { $args{new_window}=0; }
		else { return $self->error( "error", "Unknown option to icon(): $opt" ) }
	}

	return &_nodelist( $doc->render_icon_link( %args ) );
}

sub run_render_value
{
	my( $self, $item, $fieldid, %opts ) = @_;

	my $field = $item->dataset->field( $fieldid );
	return $self->error( "error", "No such field '$fieldid'" )
		if !defined $field;
	
	if( %opts )
	{
		$field = $field->clone;

		while(my( $k, $v ) = each %opts)
		{
			$field->set_property( "render_$k" => $v );
		}
	}

	return &_nodelist( $field->render_value( $self->{repository}, $field->get_value( $item ), 0, 0, $item ) );
}

sub run_url
{
	my( $self, $item, $staff ) = @_;

	return $staff ? $item->get_control_url : $item->get_url;
}

sub run_one_of
{
	my( $needle, @haystack ) = @_;

	for(@haystack)
	{
		return XML::LibXML::Boolean->True if $needle eq $_;
	}

	return XML::LibXML::Boolean->False;
}

$EPrints::Citation::XSL = 1;
1;
