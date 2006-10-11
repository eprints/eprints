package EPrints::Plugin::Import::DefaultXML;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;


# This reads in all the second level XML elements and passes them
# as DOM to xml_to_dataobj.

use XML::Parser;

# maybe needs an input_dataobj method which parses the XML from
# a single record.


$EPrints::Plugin::Import::ABSTRACT = 1;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Default XML";
	$self->{visible} = "";
	$self->{tmpfiles} = [];
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


sub input_list
{
	my( $plugin, %opts ) = @_;

        my $parser = new XML::Parser(
                Style => "Subs",
                ErrorContext => 5,
                Handlers => {
                        Start => \&_handle_start,
                        End => \&_handle_end,
                        Char => \&_handle_char
                } );
	$parser->{eprints}->{dataset} = $opts{dataset};
	$parser->{eprints}->{state} = 'toplevel';
	$parser->{eprints}->{plugin} = $plugin;
	$parser->{eprints}->{depth} = 0;
	$parser->{eprints}->{imported} = [];
	$parser->parse( $opts{fh} );

	return EPrints::List->new(
			dataset=>$opts{dataset},
			session=>$plugin->{session},
			ids=>$parser->{eprints}->{imported} );
}

sub xml_to_dataobj
{
	my( $plugin, $dataset, $xml ) = @_;

	my $epdata = $plugin->xml_to_epdata( $dataset, $xml );

	return $plugin->epdata_to_dataobj( $dataset, $epdata );
}

sub xml_to_epdata
{
	my( $plugin, $dataset, $xml ) = @_;

	$plugin->error( "xml_to_epdata should be overridden." );
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
			push @v, $node->getNodeValue;
		}
		else
		{
			$ok = 0;
		}
	}

	unless( $ok )
	{
		$plugin->warning( "Expected only text, found: ".$xml->toString );
	}
	my $r = join( "", @v );

	return $r;
}

sub _handle_char
{
        my( $parser , $text ) = @_;
                                                                                                                                                             
	if( $parser->{eprints}->{depth} > 1 )
	{
		if( $parser->{eprints}->{base64} )
		{
			push @{$parser->{eprints}->{base64data}}, $text;
		}
		else
		{
			$parser->{eprints}->{xmlcurrent}->appendChild( $parser->{eprints}->{plugin}->{session}->make_text( $text ) );
		}
	}
}

sub _handle_end
{
        my( $parser , $tag , %params ) = @_;

	$parser->{eprints}->{depth}--;

	if( $parser->{eprints}->{depth} == 1 )
	{
		my $item = $parser->{eprints}->{plugin}->xml_to_dataobj( $parser->{eprints}->{dataset}, $parser->{eprints}->{xml} );

		if( defined $item )
		{
			push @{$parser->{eprints}->{imported}}, $item->get_id;
		}

		# don't keep tmpfiles between items...
		foreach( @{$parser->{eprints}->{plugin}->{tmpfiles}} )
		{
			unlink( $_ );
		}
	}

	if( $parser->{eprints}->{depth} > 1 )
	{
		if( $parser->{eprints}->{base64} )
		{
			$parser->{eprints}->{base64} = 0;
			my $tf = $parser->{eprints}->{tmpfiles}++;
			my $tmpfile = "/tmp/epimport.$$.".time.".$tf.data";
			$parser->{eprints}->{tmpfile} = $tmpfile;
			push @{$parser->{eprints}->{plugin}->{tmpfiles}},$tmpfile;
			open( TMP, ">$tmpfile" );
			print TMP MIME::Base64::decode( join('',@{$parser->{eprints}->{base64data}}) );
			close TMP;

			$parser->{eprints}->{xmlcurrent}->appendChild( 
				$parser->{eprints}->{plugin}->{session}->make_text( $tmpfile ) );
			delete $parser->{eprints}->{basedata};
		}
		pop @{$parser->{eprints}->{xmlstack}};
		
		$parser->{eprints}->{xmlcurrent} = $parser->{eprints}->{xmlstack}->[-1]; # the end!
	}

}
sub _handle_start
{
        my( $parser , $tag , %params ) = @_;

	if( $parser->{eprints}->{depth} == 0 )
	{
		my $tlt = $parser->{eprints}->{plugin}->top_level_tag( $parser->{eprints}->{dataset} );
		if( defined $tlt && $tlt ne $tag )
		{
			die "Unexpected tag: $tag\n";
		}
	}

	if( $parser->{eprints}->{depth} == 1 )
	{
		$parser->{eprints}->{xml} = $parser->{eprints}->{plugin}->{session}->make_element( $tag );
		$parser->{eprints}->{xmlstack} = [$parser->{eprints}->{xml}];
		$parser->{eprints}->{xmlcurrent} = $parser->{eprints}->{xml};
	}

	if( $parser->{eprints}->{depth} > 1 )
	{
		my $new = $parser->{eprints}->{plugin}->{session}->make_element( $tag );
		$parser->{eprints}->{xmlcurrent}->appendChild( $new );
		push @{$parser->{eprints}->{xmlstack}}, $new;
		$parser->{eprints}->{xmlcurrent} = $new;
		if( $params{encoding} && $params{encoding} eq "base64" )
		{
			$parser->{eprints}->{base64} = 1;
			$parser->{eprints}->{base64data} = [];
		}
	}

	$parser->{eprints}->{depth}++;
}
	


sub DESTROY
{
	my( $self ) = @_;

	foreach( @{$self->{tmpfiles}} )
	{
		unlink( $_ );
	}
}

 


1;
