######################################################################
#
# EPrints::Citation::EPC
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

B<EPrints::Citation::EPC> - loading and rendering of citation styles

=cut

package EPrints::Citation::EPC;

@ISA = qw( EPrints::Citation );

use strict;

sub load_source
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $file = $self->{filename};

	my $doc = $repo->parse_xml( $file, 1 );
	return if !$doc;

	my $citation = ($doc->getElementsByTagName( "citation" ))[0];
	if( !defined $citation )
	{
		$repo->log(  "Missing <citations> tag in $file\n" );
		$repo->xml->dispose( $doc );
		return;
	}
	my $type = $citation->getAttribute( "type" );
	$type = "default" unless EPrints::Utils::is_set( $type );

	$self->{type} = $type;
	$self->{style} = $repo->xml->contents_of( $citation );
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

	my $repo = $self->{repository};

	my $style = $repo->xml->clone( $self->{style} );

	$opts{repository} = $repo;
	$opts{session} = $repo;

	my $collapsed = EPrints::XML::EPC::process( $style,
		%opts,
		item => $dataobj );
	my $r = _render_citation_aux( $collapsed, %opts );

	EPrints::XML::trim_whitespace( $r );

	return $r;
}

sub _render_citation_aux
{
	my( $node, %params ) = @_;

	my $addkids = $node->hasChildNodes;

	my $rendered;
	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $name = $node->tagName;
		$name =~ s/^ep://;
		$name =~ s/^cite://;

		if( $name eq "iflink" )
		{
			$rendered = $params{repository}->make_doc_fragment;
			$addkids = defined $params{url};
		}
		elsif( $name eq "ifnotlink" )
		{
			$rendered = $params{repository}->make_doc_fragment;
			$addkids = !defined $params{url};
		}
		elsif( $name eq "linkhere" )
		{
			if( defined $params{url} )
			{
				$rendered = $params{repository}->make_element( 
					"a",
					onclick=>$params{onclick},
					target=>$params{target},
					href=> $params{url} );
			}
			else
			{
				$rendered = $params{repository}->make_doc_fragment;
			}
		}
	}

	if( !defined $rendered )
	{
		$rendered = $params{repository}->clone_for_me( $node );
	}

	if( $addkids )
	{
		foreach my $child ( $node->getChildNodes )
		{
			$rendered->appendChild(
				_render_citation_aux( 
					$child,
					%params ) );			
		}
	}
	return $rendered;
}

1;
