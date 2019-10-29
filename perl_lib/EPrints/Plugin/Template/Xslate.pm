package EPrints::Plugin::Template::Xslate;

use strict;
use warnings;

#use base qw(EPrints::Plugin::Template);
use base qw(EPrints::Plugin);

our $DEFAULT_CACHE = 1;
our $TEMPLATE_EXTENSION = '.tx';

sub new
{
    my( $class, %params ) = @_;
    
    my $self = $class->SUPER::new( %params );

    my $repo = $self->{repository};
    my @template_dirs = $repo->template_dirs();
    $self->{xslate_opts} = {
	syntax => 'Kolon',
	type => 'xml',
	path => \@template_dirs,
    };

    $self->{disable} = !EPrints::Utils::require_if_exists( 'Text::Xslate' );

    return $self;
}

sub matches
{
    my( $self, $test, $param ) = @_;
    
    if ( $test eq 'template_file' )
    {
	for my $path ( @{$self->{xslate_opts}->{path}} )
	{
	    return 1 if ( -e "${path}/${param}${TEMPLATE_EXTENSION}" );
	}
    }

    return $self->SUPER::matches( $test, $param );
}


#
# Returns text output from $template using $vars
#
sub render
{
    my( $self, $template, $vars ) = @_;

    my $tx = $self->_tx();

    $vars->{repo} = $self->{repository};

    return $tx->render( "${template}${TEMPLATE_EXTENSION}", $vars );
}


#
# Returns XML DOM output from $template using $vars
#
# This is pretty much a convenience while EPrints expects DOM in
# certain places.
#
sub get_xml
{
    my( $self, $template, $vars ) = @_;

    my $rendered = $self->render( $template, $vars );

    my $repo = $self->{repository};
    my $dom = $repo->make_doc_fragment();
    eval 
    {
	$dom->appendChild( $repo->xml->parse_string( $rendered )->documentElement() );
	1;
    } or do
    {
	$repo->log( "[Error] Couldn't parse citation output as XML: $@" );
    };

    return $dom;
}

#
# Return an EPrints::Page for the content specified by $map
#
# This code is taken pretty much verbatim from EPrints::XHTML::page()
# - perhaps this code should go in EPrints::Plugin::Template.
#
# Requires the template specify the doctype
#
sub page
{
    my( $self, $map, %options ) = @_;

    my $repo = $self->{repository};

    # if mainonly=yes is in effect return the page content
    if ( $repo->get_online &&
	 $repo->param( "mainonly" ) &&
	 $repo->param( "mainonly" ) eq "yes" )
    {
	if ( defined $map->{'utf-8.page'} )
	{
	    return EPrints::Page->new( $repo, $map->{'utf-8.page'}, add_doctype=>0 );
	}
	elsif ( defined $map->{page} )
	{
	    return EPrints::Page::DOM->new( $repo, $map->{page}, add_doctype=>0 );
	}
	else
	{
	    EPrints->abort( "Can't generate mainonly without page" );
	}
    }

    # languages pin
    my $plugin = $repo->plugin( "Screen::SetLang" );
    $map->{languages} = $plugin->render_action_link if ( defined $plugin );
    
    $repo->run_trigger( EPrints::Const::EP_TRIGGER_DYNAMIC_TEMPLATE,
			pins => $map,
	);

    # we've been called by an older script
    if( !defined $map->{login_status} )
    {
	$map->{login_status} = EPrints::ScreenProcessor->new( session => $repo )->render_toolbar;
    }

    my $pagehooks = $repo->config( "pagehooks" );
    $pagehooks = {} if !defined $pagehooks;
    my $ph = $pagehooks->{$options{page_id}} if defined $options{page_id};
    $ph = {} if !defined $ph;
    if( defined $options{page_id} )
    {
	$ph->{bodyattr}->{id} = "page_".$options{page_id};
    }

    # only really useful for head & pagetop, but it might as
    # well support the others
    foreach ( keys %{$map} )
    {
	next if ( !defined $ph->{$_} );

	my $pt = $repo->xml->create_document_fragment;
	$pt->appendChild( $map->{$_} );
	my $ptnew = $repo->clone_for_me( $ph->{$_}, 1 );
	$pt->appendChild( $ptnew );
	$map->{$_} = $pt;
    }

    if( !defined $options{template} )
    {
	$options{template} = 'default';
    }

    # Convert DOM bits to plain text
    my $vars = {};
    for my $part_key ( keys %{$map} )
    { 
	my $part = $map->{$part_key};
	my $new_key = $part_key;
	$new_key =~ s/utf-8\.//;
	$new_key =~ s/\./_/;
	if ( ref( $part ) =~ m/^XML::LibXML/ )
	{
	    $vars->{$new_key} = $repo->xhtml->to_xhtml( $part );
	}
	else
	{
	    $vars->{$new_key} = $part;
	}
    }

    my $rendered = $self->render( $options{template}, $vars );

    my $opts = { add_doctype => 0 };

    return EPrints::Page->new( $repo, $rendered, %{$opts} );
}


#
# Returns a Text::Xslate object
#
sub _tx
{
    my( $self ) = @_;

    $self->{tx} = Text::Xslate->new( 
        module => [
	    'Text::Xslate::Bridge::Star',
	    'EPrints::Template::Xslate::Functions'
	],
	%{$self->{xslate_opts}}
	) if ( !defined $self->{tx} );

    return $self->{tx};
}

1;

#
# Extension template functions - incomplete mirror of
# EPrints::Script::Compiled
#
package EPrints::Template::Xslate::Functions;

use parent qw(Text::Xslate::Bridge);

use Carp qw(carp);
use URI::QueryParam;

sub documents
{
    my ( $eprint ) = @_;

    my @result = $eprint->get_all_documents();

    return \@result;

}

sub doc_size
{
    my( $doc ) = @_;

    if ( !defined $doc || ref($doc) ne 'EPrints::DataObj::Document' )
    {
	carp( 'Can only call doc_size() on document objects not ' . ref( $doc ) );
    }

    if ( !$doc->is_set( 'main' ) )
    {
	return 0;
    }

    my %files = $doc->files;

    return $files{$doc->get_main} || 0;
}

sub human_filesize
{
    my( $bytes ) = @_;

    return EPrints::Utils::human_filesize( $bytes || 0 );
}

sub magicstop
{
    my ( $str ) = @_;
    $str =~ s/([^.])$/$1\./;
    return $str;
}

#
# Returns a URL to the current resource. Any querystring params in
# $whitelist that are already set are preserved except where overriden
# by values in %overrides.
#
sub link_self
{
    my ( $repo, $whitelist, %overrides ) = @_;

    my $url = URI->new( $repo->get_full_url() );

    my $params = $url->query_form_hash();

    # Remove params not in the whitelist
    for my $param ( keys( %{$params} ) )
    {
	if ( !grep( /^$param$/, @{$whitelist} ) )
	{
	    delete( $params->{$param} );
	}
    }

    # Apply overrides
    for my $key ( keys %overrides )
    { 
	$params->{$key} = $overrides{$key};
    }
    $url->query_form_hash( $params );

    return $url->as_string();
}

my %functions = (
    documents => \&documents,
    doc_size => \&doc_size,
    human_filesize => \&human_filesize,
    magicstop => \&magicstop,
    link_self => \&link_self,
    );

__PACKAGE__->bridge(
#    nil    => \%nil_methods,
#    scalar => \%scalar_methods,
#    array  => \%array_methods,
#    hash   => \%hash_methods,

    function => \%functions,
    );

1;
