=head1 NAME

B<EPrints::Plugin::Import::DefaultXML> - Import XML

=head1 DESCRIPTION

It is ABSTRACT - its methods should not be called directly.

You probably want to look at L<EPrints::Plugin::Import::XML> for importing from XML.

This plugin reads in all the second level XML elements and passes them as DOM to xml_to_dataobj.

(Maybe needs an input_dataobj method which parses the XML from a single record?)

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::Import::DefaultXML;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

$EPrints::Plugin::Import::DISABLE = 1;

##############################################################################

=item $plugin = EPrints::Plugin::Import::DefaultXML->new()

ABSTRACT.

=cut
##############################################################################

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Default XML";
	$self->{visible} = "";
	#$self->{produce} = [ 'list/*', 'dataobj/*' ];

	return $self;
}


##############################################################################

=item $name = $plugin->top_level_tag( $dataset )

Return the expected root element node name or undef to not check at all. If the names do not match calls $plugin->unknown_start_element.

=cut
##############################################################################

sub top_level_tag
{
	my( $plugin, $dataset ) = @_;

	return undef;
}

##############################################################################

=item $plugin->unknown_start_element( $found, $expected )

Prints the error and exits.

=cut
##############################################################################

sub unknown_start_element
{
	my( $self, $found, $expected ) = @_;

	print STDERR "Unexpected tag: expected <$expected> found <$found>\n";
	exit 1;
}

##############################################################################

=item $list = $plugin->input_fh( %opts )

Import objects in XML format from $opts{fh}. Returns an L<EPrints::List> of all the imported objects.

=cut
##############################################################################

sub input_fh
{
	my( $plugin, %opts ) = @_;

	my $handler = {
		dataset => $opts{dataset},
		state => 'toplevel',
		plugin => $plugin,
		depth => 0,
		tmpfiles => [], # temporary files for Base64
		imported => [], };
	bless $handler, "EPrints::Plugin::Import::DefaultXML::Handler";

	EPrints::XML::event_parse( $opts{fh}, $handler );

	return EPrints::List->new(
			dataset => $opts{dataset},
			session => $plugin->{session},
			ids => $handler->{imported} );
}

##############################################################################

=item $dataobj = $plugin->xml_to_dataobj( $dataset, $xml )

Import an object in XML format from $xml into $dataset. Calls $plugin->xml_to_dataobj to convert the XML to epdata (hashrefs) and then $plugin->epdata_to_dataobj to actually create the object.

Returns the object created.

=cut
##############################################################################

sub xml_to_dataobj
{
	my( $plugin, $dataset, $xml ) = @_;

	my $epdata = $plugin->xml_to_epdata( $dataset, $xml );

	return $plugin->epdata_to_dataobj( $dataset, $epdata );
}

##############################################################################

=item $epdata = $plugin->xml_to_epdata( $dataset, $xml )

ABSTRACT.

Converts $xml into $epdata.

=cut
##############################################################################

sub xml_to_epdata
{
	my( $plugin, $dataset, $xml ) = @_;

	$plugin->error( $plugin->phrase( "no_subclass" ) );
}

##############################################################################

=item $string = $plugin->xml_to_text( $node )

Returns the text content of $node and gives a warning if $node contains any elements.

=cut
##############################################################################

sub xml_to_text
{
	my( $plugin, $xml ) = @_;

	my @list = $xml->getChildNodes;
	my $ok = 1;
	my @v = ();
	foreach my $node ( @list ) 
	{  
		if( EPrints::XML::is_dom( $node,
                        "Text",
                        "CDATASection",
                        "EntityReference" ) ) 
		{
			push @v, $node->nodeValue;
		}
		else
		{
			$ok = 0;
		}
	}

	unless( $ok )
	{
		$plugin->warning( $plugin->phrase( "unexpected_xml", xml => $xml->toString ) );
	}
	my $r = join( "", @v );

	return $r;
}

=back

=cut


package EPrints::Plugin::Import::DefaultXML::Handler;

use strict;

##############################################################################

=head1 NAME

EPrints::Plugin::Import::DefaultXML::Handler - SAX handler

=head1 METHODS

=over 4

=item $handler->characters( $node_info )

Concantenate Base64 data if we're in a Base64 container, otherwise just add the text to the current node.

=cut
##############################################################################

sub characters
{
        my( $self , $node_info ) = @_;

	if( $self->{depth} > 1 )
	{
		if( $self->{base64} )
		{
			push @{$self->{base64data}}, $node_info->{Data};
		}
		else
		{
			$self->{xmlcurrent}->appendChild( $self->{plugin}->{session}->make_text( $node_info->{Data} ) );
		}
	}
}

##############################################################################

=item $handler->end_element( $node_info )

At the end of each item calls $plugin->xml_to_dataobj( $dataset, $xml ).

If Base64 data was included it is written to a temporary file before xml_to_dataobj is called and unlinked afterwards.

=cut
##############################################################################

sub end_element
{
        my( $self , $node_info ) = @_;

	$self->{depth}--;

	if( $self->{depth} == 1 )
	{
		my $item = $self->{plugin}->xml_to_dataobj( $self->{dataset}, $self->{xml} );

		if( defined $item )
		{
			push @{$self->{imported}}, $item->get_id;
		}

		# don't keep tmpfiles between items...
		$self->{tmpfiles} = [];
	}

	if( $self->{depth} > 1 )
	{
		if( $self->{base64} )
		{
			$self->{base64} = 0;
			my $tmpfile = File::Temp->new( UNLINK => 1 );
			push @{$self->{tmpfiles}}, $tmpfile;
			print $tmpfile MIME::Base64::decode( join('',@{$self->{base64data}}) );

			$self->{xmlcurrent}->appendChild( 
				$self->{plugin}->{session}->make_text( "$tmpfile" ) );
			delete $self->{basedata};
		}
		elsif( $self->{href} )
		{
			my $href = delete $self->{href};
			$href =~ s/^file:\/\///;
			if( $self->{plugin}->{session}->get_repository->get_conf( "enable_file_imports" ) )
			{
				$self->{xmlcurrent}->appendChild( 
					$self->{plugin}->{session}->make_text( $href ) );
			}
			else
			{
				$self->{plugin}->warning( $self->{plugin}->phrase( "file_import_disabled", filename => $href ) );
			}
		}
		pop @{$self->{xmlstack}};
		
		$self->{xmlcurrent} = $self->{xmlstack}->[-1]; # the end!
	}

}

##############################################################################

=item $handler->start_element( $node_info )

Build a DOM tree for the incoming XML elements. Spots Base64 encoded and references to files, which are stored for later handling in end_element.

 <foo encoding="base64">YmFy</foo>

 <foo href="file:///tmp/bar.pdf" />

=cut
##############################################################################

sub start_element
{
        my( $self, $node_info ) = @_;

	my %params = ();
	foreach ( keys %{$node_info->{Attributes}} )
	{
		$params{$node_info->{Attributes}->{$_}->{Name}} = 
			$node_info->{Attributes}->{$_}->{Value};
	}

	if( $self->{depth} == 0 )
	{
		my $tlt = $self->{plugin}->top_level_tag( $self->{dataset} );
		if( defined $tlt && $tlt ne $node_info->{Name} )
		{
			$self->{plugin}->unknown_start_element( $node_info->{Name}, $tlt ); #dies
		}
	}

	if( $self->{depth} == 1 )
	{
		$self->{xml} = $self->{plugin}->{session}->make_element( $node_info->{Name} );
		$self->{xmlstack} = [$self->{xml}];
		$self->{xmlcurrent} = $self->{xml};
	}

	if( $self->{depth} > 1 )
	{
		my $new = $self->{plugin}->{session}->make_element( $node_info->{Name} );
		$self->{xmlcurrent}->appendChild( $new );
		push @{$self->{xmlstack}}, $new;
		$self->{xmlcurrent} = $new;
		# this is a base64 container
		if( $params{encoding} && $params{encoding} eq "base64" )
		{
			$self->{base64} = 1;
			$self->{base64data} = [];
		}
		# file reference
		elsif( $params{href} )
		{
			$self->{href} = $params{href};
		}
	}

	$self->{depth}++;
}

1;

=back

