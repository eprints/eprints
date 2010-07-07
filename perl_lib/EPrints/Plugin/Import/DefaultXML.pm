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

	my $handler = EPrints::Plugin::Import::DefaultXML::Handler->new(
		dataset => $opts{dataset},
		plugin => $plugin,
		depth => 0,
		imported => [],
	);

	eval { EPrints::XML::event_parse( $opts{fh}, $handler ) };
	die $@ if $@ and "$@" ne "\n";

	return EPrints::List->new(
			dataset => $opts{dataset},
			session => $plugin->{session},
			ids => $handler->{imported} );
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
	}

	if( $self->{depth} == 1 )
	{
	}
	elsif( $self->{depth} == 2 )
	{
		delete $self->{state};
		delete $self->{handler};

		my $epdata = delete $self->{epdata};
#print STDERR Data::Dumper::Dumper( $epdata );
		my $dataobj = $self->{plugin}->epdata_to_dataobj( $self->{dataset}, $epdata );
		push @{$self->{imported}}, $dataobj->id if defined $dataobj;
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
