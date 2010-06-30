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


sub input_fh
{
	my( $plugin, %opts ) = @_;

	my $handler = {
		dataset => $opts{dataset},
		state => 'toplevel',
		plugin => $plugin,
		depth => 0,
		tmpfiles => [],
		imported => [],
		encoding => undef,
		buffer => '' };
	bless $handler, "EPrints::Plugin::Import::DefaultXML::Handler";

	eval { EPrints::XML::event_parse( $opts{fh}, $handler ) };
	die $@ if $@ and "$@" ne "\n";

	return EPrints::List->new(
			dataset => $opts{dataset},
			session => $plugin->{session},
			ids => $handler->{imported} );
}

sub xml_to_dataobj
{
	my( $plugin, $dataset, $xml, %opts ) = @_;

	my $epdata = $plugin->xml_to_epdata( $dataset, $xml, %opts );

	return $plugin->epdata_to_dataobj( $dataset, $epdata, %opts );
}

sub xml_to_epdata
{
	my( $plugin, $dataset, $xml, %opts ) = @_;

	$plugin->error( $plugin->phrase( "no_subclass" ) );
}

# takes a chunck of XML and returns it as a utf8 string.
# If the text contains anything but elements then this gives 
# a warning.

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
		$plugin->warning( $plugin->{session}->phrase( "Plugin/Import/DefaultXML:unexpected_xml", xml => $xml->toString ) );
	}
	my $r = join( "", @v );

	return $r;
}



package EPrints::Plugin::Import::DefaultXML::Handler;

use strict;

sub characters
{
	my( $self, $node_info ) = @_;

	return if $self->{depth} <= 1;

	if( $self->{encoding} )
	{
		my $tmpfile = $self->{tmpfiles}->[$#{$self->{tmpfiles}}];
		if( $self->{encoding} eq "base64" )
		{
			use bytes;
			for($node_info->{Data})
			{
				substr($_,0,0) = $self->{buffer};
				print $tmpfile MIME::Base64::decode_base64( substr($_,0,length($_) - length($_)%77) );
				$_ = substr($_,length($_) - length($_)%77);
				$self->{buffer} = $_;
			}
		}
		else
		{
			print $tmpfile $node_info->{Data};
		}
	}
	elsif( $self->{xmlcurrent}->hasChildNodes )
	{
		$self->{xmlcurrent}->firstChild->appendData( $node_info->{Data} );
	}
	else
	{
		$self->{xmlcurrent}->appendChild( $self->{plugin}->{session}->make_text( $node_info->{Data} ) );
	}
}

sub end_element
{
        my( $self , $node_info ) = @_;

	$self->{depth}--;

	if( $self->{depth} == 1 )
	{
		seek($_,0,0) for @{$self->{tmpfiles}};

		my $item = $self->{plugin}->xml_to_dataobj( $self->{dataset}, $self->{xml},
			tmpfiles => { map { $_ => $_ } @{$self->{tmpfiles}} },
		);
		EPrints::XML::dispose( $self->{xml} );
		delete $self->{xml};
		if( defined $item )
		{
			push @{$self->{imported}}, $item->get_id;
		}

		# don't keep tmpfiles between items...
		@{$self->{tmpfiles}} = ();
	}

	if( $self->{depth} > 1 )
	{
		my $node = pop @{$self->{xmlstack}};
		if( $self->{href} )
		{
			my $href = delete $self->{href};
			my $file = $self->{xmlcurrent}->getParentNode;
			$file->removeChild( $self->{xmlcurrent} );
			my $url = $self->{plugin}->{session}->make_element( "url" );
			$file->insertBefore( $url, $file->firstChild() );
			$url->appendChild( $self->{plugin}->{session}->make_text( $href ) );
		}
		if( $self->{encoding} )
		{
			delete $self->{encoding};
			my $tmpfile = $self->{tmpfiles}->[$#{$self->{tmpfiles}}];
			print $tmpfile MIME::Base64::decode_base64( $self->{buffer} );
			$self->{buffer} = "";
		}
		
		$self->{xmlcurrent} = $self->{xmlstack}->[-1]; # the end!
	}
}

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
		$self->{xml} = $self->{plugin}->{session}->make_element( $node_info->{Name}, %params );
		$self->{xmlstack} = [$self->{xml}];
		$self->{xmlcurrent} = $self->{xml};
	}

	if( $self->{depth} > 1 )
	{
		my $new = $self->{plugin}->{session}->make_element( $node_info->{Name}, %params );
		$self->{xmlcurrent}->appendChild( $new );
		push @{$self->{xmlstack}}, $new;
		$self->{xmlcurrent} = $new;

		if( $params{href} )
		{
			$self->{href} = $params{href};
		}
		if( $params{encoding} )
		{
			$self->{encoding} = $params{encoding};
			push @{$self->{tmpfiles}}, my $tmpfile = File::Temp->new;
			binmode( $tmpfile );
			$new->setAttribute( encoding => "tmpfile" );
			$new->appendChild( $self->{plugin}->{session}->make_text( "$tmpfile" ) );
		}
	}

	$self->{depth}++;
}

1;
