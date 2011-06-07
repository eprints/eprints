=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::XSLT> - utilities for XSLT processing

=head1 SYNOPSIS

	my $xslt = EPrints::XSLT->new(
		repository => $repository,
		stylesheet => $stylesheet,
	);

	my $result = $xslt->transform( $doc );
	print $xslt->output_as_bytes( $result );

Using ept functions:

	<xsl:value-of select="ept:value('title')" />
	<xsl:copy-of select="ept:render_value('title')" />

=head1 DESCRIPTION

Because XSLT requires very careful treatment this module should probably be only used by internal code.

For the correct context to be set for 'ept:' functions this module B<must> be used for every transform.

=head1 METHODS

=over 4

=cut

package EPrints::XSLT;

use strict;

# libxslt extensions are library-global, so we only initialise them once
# that also means we have to use a global pointer to keep track of the current
# citation object (yuck)

our $SELF;

eval "use XML::LibXSLT 1.70";
if( !$@ )
{
	register_globals() if !$EPrints::XSLT;
	$EPrints::XSLT = 1;
}

=item $xslt = EPrints::XSLT->new( repository => $repo, ... )

Options:

	repository
	stylesheet
	dataobj
	dataobjs
	opts
	error_cb

=cut

sub new
{
	my( $class, %self ) = @_;

	$self{dataobj} ||= undef;
	$self{dataobjs} ||= {};
	$self{opts} ||= {};
	$self{error_cb} ||= sub {
		my( $type, $message ) = @_;

		return XML::LibXML::Text->new( "[ $message ]" );
	};

	my $self = bless \%self, $class;

	Scalar::Util::weaken( $self->{repository} )
		if defined(&Scalar::Util::weaken);

	Carp::croak "Requires stylesheet" if !$self{stylesheet};

	return $self;
}

=item $result = $xslt->transform( $doc [, @parameters ] )

Transforms $doc with the given stylesheet. @parameters is an optional list of key-value pairs to pass to the stylesheet.

=cut

sub transform
{
	my( $self, $doc, @params ) = @_;

	my $ctx = $SELF;
	$SELF = $self;

	my $result = $self->{stylesheet}->transform( $doc,
		XML::LibXSLT::xpath_to_string( @params )
	);

	$SELF = $ctx; # restore previous context (as transforms may be nested!)

	return $result;
}

=item $bytes = $xslt->output_as_bytes( $result )

See L<XML::LibXSLT/output_as_bytes>.

=cut

sub output_as_bytes { shift->{stylesheet}->output_as_bytes( @_ ) }
sub output_encoding { shift->{stylesheet}->output_encoding( @_ ) }
sub media_type { shift->{stylesheet}->media_type( @_ ) }

sub self_ctx
{
	$SELF;
}

# Retrieve the current dataobj in-context
sub dataobj_ctx
{
	my $self = &self_ctx;

	if( UNIVERSAL::isa( $_[0], "XML::LibXML::NodeList" ) )
	{
		my $uri = shift @_;
		$uri = $uri->item( 0 );
		$uri = $uri->toString;
		unshift @_, $self->{dataobjs}->{$uri};
	}
	else
	{
		if( !defined $self->{dataobj} )
		{
			EPrints->abort( "Something went wrong with the dataobj: $self" );
		}
		unshift @_, $self->{dataobj};
	}
}

sub error
{
	my( $self, $type, $message ) = @_;

	my $f = $self->{error_cb};
	return &$f( $type, $message );
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

sub register_globals
{
	# ept:one_of
	XML::LibXSLT->register_function(
		EPrints::Const::EP_NS_XSLT,
		"one_of",
		\&run_one_of
	);
	# ept:param
	XML::LibXSLT->register_function(
		EPrints::Const::EP_NS_XSLT,
		"param",
		sub { &self_ctx->run_param( @_ ) }
	);
	# ept:phrase
	XML::LibXSLT->register_function(
		EPrints::Const::EP_NS_XSLT,
		"phrase",
		sub { &_nodelist( &self_ctx->{repository}->html_phrase( $_[0] ) ) }
	);
	# ept:config
	XML::LibXSLT->register_function(
		EPrints::Const::EP_NS_XSLT,
		"config",
		sub { &self_ctx->{repository}->config( @_ ) }
	);
	# ept:value
	XML::LibXSLT->register_function(
		EPrints::Const::EP_NS_XSLT,
		"value",
		sub { &dataobj_ctx; &self_ctx->run_value( @_ ) }
	);
	# ept:render_value
	XML::LibXSLT->register_function(
		EPrints::Const::EP_NS_XSLT,
		"render_value",
		sub { &dataobj_ctx; &self_ctx->run_render_value( @_ ) }
	);
	# ept:citation
	XML::LibXSLT->register_function(
		EPrints::Const::EP_NS_XSLT,
		"citation",
		sub { &dataobj_ctx; &self_ctx->run_citation( @_ ) }
	);
	# ept:documents
	XML::LibXSLT->register_function(
		EPrints::Const::EP_NS_XSLT,
		"documents",
		sub { &dataobj_ctx; &self_ctx->run_documents( @_ ) }
	);
	# ept:icon
	XML::LibXSLT->register_function(
		EPrints::Const::EP_NS_XSLT,
		"icon",
		sub { &dataobj_ctx; &self_ctx->run_icon( @_ ) }
	);
	# ept:url
	XML::LibXSLT->register_function(
		EPrints::Const::EP_NS_XSLT,
		"url",
		sub { &dataobj_ctx; &self_ctx->run_url( @_ ) }
	);
	# ept:is_set
	XML::LibXSLT->register_function(
		EPrints::Const::EP_NS_XSLT,
		"is_set",
		sub { &dataobj_ctx; $_[0]->exists_and_set( $_[1] ) ?
			XML::LibXML::Boolean->True :
			XML::LibXML::Boolean->False }
	);
}

=back

=head1 EPT FUNCTIONS

=over 4

=cut

=item ept:citation( [ STYLE [, OPTIONS ] ] )

Returns the citation of style STYLE (or "default") for the current item.

=cut

sub run_citation
{
	my( $self, $dataobj, $style, %params ) = @_;

	return &_nodelist( $dataobj->render_citation( $style, %params ) );
}

=item ept:config( KEY1 [, KEY2 [, ... ] ] )

Returns the repository configuration value.

=cut

=item ept:documents()

Returns a list of the current item's documents (errors if current item is not an eprint).

=cut

sub run_documents
{
	my( $self, $dataobj ) = @_;

	if( !$dataobj->isa( "EPrints::DataObj::EPrint" ) )
	{
		return $self->error( "error", "documents() expected EPrints::DataObj::EPrint but got ".ref($dataobj) );
	}

	my $nl = XML::LibXML::NodeList->new;
	foreach my $dataobj ($dataobj->get_all_documents)
	{
		my $uri = $dataobj->internal_uri;
		$self->{dataobjs}->{$uri} = $dataobj;
		$nl->push( XML::LibXML::Text->new( $uri ) );
	}
	return $nl;
}

=item ept:icon( [ OPTIONS ] )

Returns a link to a document with icon.

Options:

	HoverPreview
	noHoverPreview
	NewWindow
	noNewWindow

=cut

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

=item ept:one_of( NEEDLE [, HAYSTACK ] )

Returns true if NEEDLE is in HAYSTACK based on string equality.

=cut

sub run_one_of
{
	my( $needle, @haystack ) = @_;

	for(@haystack)
	{
		return XML::LibXML::Boolean->True if $needle eq $_;
	}

	return XML::LibXML::Boolean->False;
}

=item ept:param( KEY )

Returns the value of the parameter KEY e.g. in plugin arguments.

=cut

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

=item ept:phrase( PHRASEID )

Returns the HTML phrase for PHRASEID.

=cut

=item ept:render_value( FIELDID [, OPTIONS ] )

Returns the rendered value of FIELDID for the current item.

=cut

sub run_render_value
{
	my( $self, $dataobj, $fieldid, %opts ) = @_;

	my $field = $dataobj->dataset->field( $fieldid );
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

	return &_nodelist( $field->render_value( $self->{repository}, $field->get_value( $dataobj ), 0, 0, $dataobj ) );
}

=item ept:url( [ STAFF ] )

Returns the URL of the current item (or control page if STAFF is true).

=cut

sub run_url
{
	my( $self, $dataobj, $staff ) = @_;

	return $staff ? $dataobj->get_control_url : $dataobj->get_url;
}

=item ept:value( FIELDID )

Returns the value of FIELDID for the current item.

=cut

sub run_value
{
	my( $self, $dataobj, $fieldid ) = @_;

	my $field = $dataobj->dataset->field( $fieldid );
	return undef if !defined $field;

	if( $field->isa( "EPrints::MetaField::Subobject" ) )
	{
		my $nl = XML::LibXML::NodeList->new;
		foreach my $dataobj ( @{$field->get_value( $dataobj )} )
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
		foreach my $v ( @{$field->get_value( $dataobj )} )
		{
			$nl->push( XML::LibXML::Text->new( $v ) );
		}
		return $nl;
	}
	else
	{
		return $field->get_value( $dataobj );
	}
}

=back

=cut

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

