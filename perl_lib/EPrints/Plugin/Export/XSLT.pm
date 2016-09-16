=for Pod2Wiki

=head1 NAME

EPrints::Plugin::Export::XSLT - XSLT-based exports

=head1 SYNOPSIS

Create a file in C<Plugins/Export/XSLT/> called 'Title.xsl' containing:

	<?xml version="1.0"?> 
	
	<xsl:stylesheet
		version="1.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		ept:name="Titles"
		ept:visible="all"
		ept:advertise="1"
		ept:accept="list/eprint dataobj/eprint"
		ept:mimetype="application/xml; charset=utf-8"
		ept:qs="0.1"
		xmlns:ept="http://eprints.org/ep2/xslt/1.0"
		xmlns:ep="http://eprints.org/ep2/data/2.0"
		exclude-result-prefixes="ept ep"
	>
	
	<xsl:param name="results" />
	
	<xsl:template match="text()" />
	
	<xsl:template match="ept:template">
	<titles><xsl:value-of select="$results"/></titles>
	</xsl:template>
	
	<xsl:template match="/ep:eprints/ep:eprint">
	  <title><xsl:value-of select="ep:title"/></title>
	</xsl:template>
	
	</xsl:stylesheet>

=head1 DESCRIPTION

This export plugin allows you to use XSL Transforms to export data from EPrints. The plugin is fed EPrints XML and can output any resulting data supported by XSLT.

This is the inverse process of L<EPrints::Plugin::Import::XSLT>.

=head2 Headers and Footers

You can specify a template to use for your output:

	<xsl:template match="ept:template">
		<html>
			<body>
				<xsl:value-of select="$results"/>
			</body>
		</html>
	</xsl:template>

Note: you can output unbalanced XML by using disable-output-escaping:

	<xsl:template match="ept:template">
		<xsl:text disable-output-escaping="yes">
			&lt;html&gt;
				&lt;body&gt;
		</xsl:text>
		<xsl:value-of select="$results"/>
	</xsl:template>

=head2 Controlling XML Declarations

If your stylesheet outputs XML (the default):

	<xsl:output method="xml"/>

The XML declaration will only be outputted once at the start of the export, regardless of how many records there are.

To output as XML and suppress the XML declaration entirely define an empty prefix:

	<xsl:stylesheet
		xmlns:ept="http://eprints.org/ep2/xslt/1.0"
		ept:prefix=""
	>

=head1 PLUGIN OPTIONS

All attributes on <xsl:stylesheet> that are in the EPT namespace are treated as plugin parameters. In addition to those parameters used by all L<EPrints::Plugin::Export> plugins XSLT uses:

	prefix
		Value is printed before any content (defaults to XML decl.)
	postfix
		Value is printed after any content.

=head1 STYLESHEET PARAMETERS

The following parameters are passed to the transform for each item:

	total
		Total items in result set.
	position
		1-indexed position in result set.
	dataset
		Base id of the item's dataset (e.g. "eprint").

=head1 EXTENDED FUNCTIONS

The standard EPrints global extended XPath functions are supported, see L<EPrints::XSLT>.

=head1 SEE ALSO

L<EPrints::Plugin::Export>

=cut

package EPrints::Plugin::Export::XSLT;

use constant {
	NS_XSLT => "http://www.w3.org/1999/XSL/Transform",
};

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

# class-specific settings (e.g. the stylesheets)
our %SETTINGS;

sub new
{
	my( $class, @args ) = @_;

	return $class->SUPER::new(
		%{$SETTINGS{$class}},
		@args
	);
}

sub init_xslt
{
	my( $class, $repo, $xslt ) = @_;

	my $doc = delete $xslt->{doc};
	my $root = $doc->documentElement;

	my $ep_xsl_prefix = $root->lookupNamespacePrefix( EPrints::Const::EP_NS_XSLT );

	# omit XML declarations (which we add by hand)
	my( $output ) = $root->getElementsByTagNameNS( NS_XSLT, "output" );
	if( !$output )
	{
		$output = $root->appendChild(
			$doc->createElementNS( NS_XSLT, "output"
			) );
	}
	if( !$output->hasAttribute( "method" ) )
	{
		$output->setAttribute( method => "xml" );
	}
	$xslt->{method} = lc($output->getAttribute( "method" ));
	if( !$output->hasAttribute( "encoding" ) )
	{
		$output->setAttribute( encoding => "UTF-8" );
	}
	$xslt->{encoding} = $output->getAttribute( "encoding" );
	if( lc($xslt->{method}) eq "xml" )
	{
		$xslt->{prefix} = "<?xml version='1.0' encoding='".$xslt->{encoding}."'?>\n"
			if !defined $xslt->{prefix};
		$output->setAttribute( "omit-xml-declaration" => "yes" );
	}

	# header/footer
	$xslt->{template} = 0;
	foreach my $template ($root->getElementsByTagNameNS( NS_XSLT, "template" ))
	{
		my $match = $template->getAttribute( "match" ) or next;
		$xslt->{template} = 1 if $match eq "$ep_xsl_prefix:template";
	}

	$xslt->{prefix} = "" if !defined $xslt->{prefix};
	$xslt->{postfix} = "" if !defined $xslt->{postfix};

	my $stylesheet = XML::LibXSLT->new->parse_stylesheet( $doc );
	$xslt->{stylesheet} = $stylesheet;

	$SETTINGS{$class} = $xslt;
}

sub padding
{
	my( $self, %opts ) = @_;

	my( $prefix, $postfix ) = ($self->{prefix}, $self->{postfix});

	my $xslt = EPrints::XSLT->new(
		repository => $self->{session},
		stylesheet => $self->{stylesheet},
	);

	# header
	if( $self->{template} )
	{
		my $key = "d0a1cb555951d9f88fb03fc4247d9ba0";
		my $template = XML::LibXML::Document->new;
		$template->setDocumentElement( $template->createElementNS(
			EPrints::Const::EP_NS_XSLT, "template"
			) );
		my $result = $xslt->transform( $template,
			dataset => $opts{dataset}->base_id,
			results => $key,
			);
		my @parts = split $key, $xslt->output_as_bytes( $result ), 2;
		if( defined $parts[1] )
		{
			$prefix = $prefix . $parts[0];
			$postfix = $parts[1] . $postfix;
		}
		else
		{
			Carp::carp( "ept:template used but missing \$result" );
		}
	}

	return( $prefix, $postfix );
}

sub output_list
{
	my( $self, %opts ) = @_;

	$opts{dataset} ||= $opts{list}->{dataset};

	my $r = "";

	my $f = $opts{fh} ?
		sub { print {$opts{fh}} $_[0] } :
		sub { $r .= $_[0] };

	my( $prefix, $postfix ) = $self->padding( %opts );

	&$f( $prefix );

	my $total = $opts{list}->count;
	my $position = 1;

	$opts{list}->map(sub {
		my( undef, undef, $item ) = @_;

		&$f( $self->output_dataobj( $item, %opts,
			total => $total,
			position => $position++,
		) );
	});

	&$f( $postfix );

	return $r;
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	local $self->{session}->{xml};

	$opts{dataset} ||= $opts{list} ? $opts{list}->{dataset} : $dataobj->dataset;

	my( $prefix, $postfix );
	if( !$opts{list} )
	{
		( $prefix, $postfix ) = $self->padding( %opts );
	}

	my $xml = $dataobj->to_xml;
	my $doc = $xml->ownerDocument;

	my $toplevel = $dataobj->dataset->base_id . "s";
	my $root = $doc->createElementNS( EPrints::Const::EP_NS_DATA, $toplevel );
	$root->appendChild( $xml );
	$doc->setDocumentElement( $root );

	my $xslt = EPrints::XSLT->new(
		repository => $self->{session},
		stylesheet => $self->{stylesheet},
		dataobj => $dataobj,
	);

	my $result = $xslt->transform( $doc, 
			single => defined($opts{list}),
			dataset => $opts{dataset}->base_id,
			total => (defined($opts{total}) ? $opts{total} : 1),
			position => (defined($opts{position}) ? $opts{position} : 1)
		);

	if( !$opts{list} )
	{
		return
			$prefix .
			$xslt->output_as_bytes( $result ) .
			$postfix;
	}
	else
	{
		return $xslt->output_as_bytes( $result );
	}
}

sub xml_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	return $self->{session}->xml->create_document_fragment
		if $self->{method} ne "xml";

	my $xml = $dataobj->to_xml;
	my $doc = $xml->ownerDocument;

	my $toplevel = $dataobj->dataset->base_id . "s";
	my $root = $doc->createElementNS( EPrints::Const::EP_NS_DATA, $toplevel );
	$root->appendChild( $xml );
	$doc->setDocumentElement( $root );

	my $xslt = EPrints::XSLT->new(
		repository => $self->{session},
		stylesheet => $self->{stylesheet},
		dataobj => $dataobj,
	);

	my $result = $xslt->transform( $doc, 
			dataset => $dataobj->dataset->base_id,
			total => $opts{total},
			position => $opts{position}
		);

	$xml = $self->{session}->xml->clone( $result->documentElement );

	return $xml;
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

