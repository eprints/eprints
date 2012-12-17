=head1 NAME

B<EPrints::Template::EPC> - loading and rendering of templates

=head1 DESCRIPTION

See L<EPrints::Template>.

=head1 METHODS

=cut

package EPrints::Template::EPC;

@ISA = qw( EPrints::Template );

use strict;

=item $parts = $template->parts()

Access the parts of the template.

=cut

sub parts { shift->{parts} }

=item $ok = $template->load_source()

Reads the source file.

=cut

sub load_source
{
	my( $self ) = @_;

	my $filename = $self->{filename};
	my $repo = $self->{repository};

	my $xml = $repo->parse_xml( $filename );

	$self->{parts} = $self->_template_to_text( $xml->documentElement );

	$repo->xml->dispose( $xml );
}

sub _template_to_text
{
	my( $self, $template ) = @_;

	my $xml = $self->{repository}->xml;

	my $divide = "61fbfe1a470b4799264feccbbeb7a5ef";

	foreach my $pin ( $template->getElementsByTagName("pin") )
	{
		#$template
		my $parent = $pin->getParentNode;
		my $textonly = $pin->getAttribute( "textonly" );
		my $ref = "pin:".$pin->getAttribute( "ref" );
		if( defined $textonly && $textonly eq "yes" )
		{
			$ref.=":textonly";
		}
		my $textnode = $xml->create_text_node( $divide.$ref.$divide );
		$parent->replaceChild( $textnode, $pin );
	}

	foreach my $print ( $template->getElementsByTagName("print") )
	{
		my $parent = $print->getParentNode;
		my $ref = "print:".$print->getAttribute( "expr" );
		my $textnode = $xml->create_text_node( $divide.$ref.$divide );
		$parent->replaceChild( $textnode, $print );
	}

	foreach my $phrase ( $template->getElementsByTagName("phrase") )
	{
		my $parent = $phrase->getParentNode;
		my $ref = "phrase:".$phrase->getAttribute( "ref" );
		my $textnode = $xml->create_text_node( $divide.$ref.$divide );
		$parent->replaceChild( $textnode, $phrase );
	}

	$self->_divide_attributes( $template, $divide );

	my @r = split( "$divide", $self->{repository}->xhtml->to_xhtml( $template ) );

	return \@r;
}

sub _divide_attributes
{
	my( $self, $node, $divide ) = @_;

	return unless( $self->{repository}->xml->is( $node, "Element" ) );

	foreach my $kid ( $node->childNodes )
	{
		$self->_divide_attributes( $kid, $divide );
	}
	
	my $attrs = $node->attributes;

	return unless defined $attrs;
	
	for( my $i = 0; $i < $attrs->length; ++$i )
	{
		my $attr = $attrs->item( $i );
		my $v = $attr->nodeValue;
		next unless( $v =~ m/\{/ );
		my $name = $attr->nodeName;
		my @r = EPrints::XML::EPC::split_script_attribute( $v, $name );
		my @r2 = ();
		for( my $i = 0; $i<scalar @r; ++$i )
		{
			if( $i % 2 == 0 )
			{
				push @r2, $r[$i];
			}
			else
			{
				push @r2, "print:".$r[$i];
			}
		}
		if( scalar @r % 2 == 0 )
		{
			push @r2, "";
		}
		
		my $newv = join( $divide, @r2 );
		$attr->setValue( $newv );
	}

	return;
}

=item $template->write_page( $fh, $page )

Renders the $page to $fh using this template.

=cut

sub write_page
{
	my( $self, $fh, $page ) = @_;

	my $repo = $self->{repository};

	binmode($fh, ":utf8");

	print $fh $repo->xhtml->doc_type;

	PART: foreach my $i (0..$#{$self->{parts}})
	{
		if( $i % 2 == 0 ) {
			print $fh $self->{parts}[$i];
			next PART;
		}

		# either 
		#  print:epscript-expr
		#  pin:id-of-a-pin
		#  pin:id-of-a-pin.textonly
		#  phrase:id-of-a-phrase
		my( $type, $rest ) = split /:/, $self->{parts}[$i], 2;

		if( $type eq "print" )
		{
			my $frag = EPrints::Script::print( $rest, { session=>$repo } );
			print $fh $repo->xhtml->to_xhtml( $frag );
			$repo->xml->dispose( $frag );
		}

		elsif( $type eq "phrase" )
		{	
			my $phrase = $repo->html_phrase( $rest );
			print $fh $repo->xhtml->to_xhtml( $phrase );
			$repo->xml->dispose( $phrase );
		}

		elsif( $type eq "pin" )
		{	
			my( $pinid, $modifier ) = split /:/, $rest, 2;
			if( defined $modifier && $modifier eq "textonly" )
			{
				# escape any entities in the text (<>&" etc.)
				my $xml = $repo->xml->create_text_node( $page->text_pin( $pinid ) );
				print $fh $repo->xml->to_string( $xml );
				$repo->xml->dispose( $xml );
			}
			else
			{
				print $fh $page->utf8_pin( $pinid );
			}
		}

		# otherwise this element is missing. Leave it blank.
	}
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2012 University of Southampton.

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

