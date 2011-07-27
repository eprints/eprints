=head1 NAME

EPrints::Plugin::Import::DefaultXML

=cut

package EPrints::Plugin::Import::DefaultXML;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;


# This reads in all the second level XML elements and passes them
# as DOM to xml_to_dataobj.

# maybe needs an input_dataobj method which parses the XML from
# a single record.


$EPrints::Plugin::Import::DISABLE = 1;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Default XML";
	$self->{visible} = "";
	#$self->{produce} = [ 'list/*', 'dataobj/*' ];

	return $self;
}




# if this is defined then it is used to check that the top
# level XML element is correct.

sub top_level_tag
{
	my( $plugin, $dataset ) = @_;

	return undef;
}

sub unknown_start_element
{
	my( $self, $found, $expected ) = @_;

	$self->error("Unexpected tag: expected <$expected> found <$found>\n");
	die "\n"; # Break out of the parsing
}

=item $class = $import->handler_class

Returns the class to use as the SAX handler for parsing.

This class provides two handlers:

	::DOMHandler - calls xml_to_epdata with a DOM of the complete object
	::Handler - calls dataobj class with SAX events

=cut

sub handler_class { __PACKAGE__ . "::Handler" }

sub input_fh
{
	my( $self, %opts ) = @_;

	my $handler = $self->handler_class->new(
		dataset => $opts{dataset},
		plugin => $self,
		depth => 0,
		imported => [],
	);

	eval { EPrints::XML::event_parse( $opts{fh}, $handler ) };
	die $@ if $@ and "$@" ne "\n";

	return EPrints::List->new(
			dataset => $opts{dataset},
			session => $self->{session},
			ids => $handler->{imported} );
}

sub xml_to_dataobj
{
	my( $self, $dataset, $xml ) = @_;

	my $epdata = $self->xml_to_epdata( $dataset, $xml );
	return $self->epdata_to_dataobj( $dataset, $epdata );
}

sub xml_to_text
{
	my( $plugin, $xml ) = @_;

	my @list = $xml->childNodes;
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
		$plugin->warning( $plugin->{session}->phrase( "Plugin/Import/DefaultXML:unexpected_xml", xml => $xml->toString ) );
	}

	return join( "", @v );
}

package EPrints::Plugin::Import::DefaultXML::Handler;

use strict;

sub new
{
	my( $class, %self ) = @_;

	return bless \%self, $class;
}

sub AUTOLOAD {}

sub start_element
{
	my( $self, $info ) = @_;

#print STDERR "start_element: ".Data::Dumper::Dumper( $info )."\n";
	++$self->{depth};

	if( defined(my $handler = $self->{handler}) )
	{
		$handler->start_element( $info, $self->{epdata}, $self->{state} );
	}
	elsif( $self->{depth} == 1 )
	{
		my $tlt = $self->{plugin}->top_level_tag( $self->{dataset} );
		if( defined $tlt && $tlt ne $info->{Name} )
		{
			$self->{plugin}->unknown_start_element( $info->{Name}, $tlt ); #dies
		}
	}
	elsif( $self->{depth} == 2 )
	{
		$self->{epdata} = {};
		$self->{state} = { dataset => $self->{dataset} };

		my $class = $self->{dataset}->get_object_class;
		$self->{handler} = $class;

		$class->start_element( $info, $self->{epdata}, $self->{state} );
	}
}

sub end_element
{
	my( $self, $info ) = @_;

	if( defined(my $handler = $self->{handler}) )
	{
		$handler->end_element( $info, $self->{epdata}, $self->{state} );

		if( $self->{depth} == 2 )
		{
			delete $self->{state};
			delete $self->{handler};

			my $epdata = delete $self->{epdata};
			my $dataobj = $self->{plugin}->epdata_to_dataobj( $self->{dataset}, $epdata );
			push @{$self->{imported}}, $dataobj->id if defined $dataobj;
		}
	}

	--$self->{depth};
}

sub characters
{
	my( $self, $info ) = @_;

	if( defined(my $handler = $self->{handler}) )
	{
		$handler->characters( $info, $self->{epdata}, $self->{state} );
	}
}

package EPrints::Plugin::Import::DefaultXML::DOMHandler;

use strict;

sub new
{
	my( $class, %self ) = @_;

	return bless \%self, $class;
}

sub AUTOLOAD {}

sub start_element
{
	my( $self, $info ) = @_;

	++$self->{depth};

	if( defined(my $handler = $self->{handler}) )
	{
		$handler->start_element( $info, $self->{epdata}, $self->{state} );
	}
	elsif( $self->{depth} == 1 && $info->{Name} ne $self->{plugin}->top_level_tag( $self->{dataset} ) )
	{
		$self->{plugin}->unknown_start_element( $info->{Name}, $self->{plugin}->top_level_tag( $self->{dataset} ) ); #dies
	}
	elsif( $self->{depth} == 2 )
	{
		$self->{handler} = EPrints::XML::SAX::Builder->new(
			repository => $self->{plugin}->{session}
		);
		$self->{handler}->start_document;
		$self->{handler}->start_element( $info );
	}
}

sub end_element
{
	my( $self, $info ) = @_;

	if( defined(my $handler = $self->{handler}) )
	{
		$handler->end_element( $info, $self->{epdata}, $self->{state} );
		if( $self->{depth} == 2 )
		{
			delete $self->{handler};

			$handler->end_document;
			my $xml = $handler->result;
			my $epdata = $self->{plugin}->xml_to_epdata( $self->{dataset}, $xml );
			my $dataobj = $self->{plugin}->epdata_to_dataobj( $self->{dataset}, $epdata );
			push @{$self->{imported}}, $dataobj->id if defined $dataobj;
		}
	}

	--$self->{depth};
}

sub characters
{
	my( $self, $info ) = @_;

	if( defined(my $handler = $self->{handler}) )
	{
		$handler->characters( $info, $self->{epdata}, $self->{state} );
	}
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

