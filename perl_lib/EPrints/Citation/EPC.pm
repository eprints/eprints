######################################################################
#
# EPrints::Citation::EPC
#
######################################################################
#
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

	# only apply <linkhere> processing on the outer-most citation
	if( !exists $opts{finalize} || $opts{finalize} != 0 )
	{
		$collapsed = _render_citation_aux( $collapsed, %opts );
		EPrints::XML::trim_whitespace( $collapsed );
	}

	return $collapsed;
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

