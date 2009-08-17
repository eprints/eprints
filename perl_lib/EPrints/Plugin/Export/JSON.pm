package EPrints::Plugin::Export::JSON;

use EPrints::Plugin::Export::TextFile;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "JSON";
	$self->{accept} = [ 'list/*', 'dataobj/*' ];
	$self->{visible} = "all";
	$self->{suffix} = ".js";
	$self->{mimetype} = "text/javascript; charset=utf-8";

	return $self;
}



sub output_list
{
	my( $plugin, %opts ) = @_;

	my $r = [];

	my $part;
	$part = "[\n\n";
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}

	$opts{json_indent} = 1;
	my $first = 1;
	$opts{list}->map( sub {
		my( $handle, $dataset, $item ) = @_;
		my $part = "";
		if( $first ) { $part = "  "; $first = 0; } else { $part = ",\n  "; }
		$part .= $plugin->output_dataobj( $item, %opts );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	} );

	$part= "\n\n]\n\n";
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}


	if( defined $opts{fh} )
	{
		return;
	}

	return join( '', @{$r} );
}

sub output_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $itemtype = $dataobj->get_dataset->confid;

	my $xml = $dataobj->to_xml;
	my $obj_node = $xml;
	# pull the <eprint> out of the document fragment, if it is in one.
	foreach my $node ( $xml->getChildNodes() )
	{
		if( $node->getName() eq $dataobj->get_dataset->confid )
		{
			$obj_node = $node;
			last;
		}
	}

	return $plugin->ep3xml_to_json( $obj_node, $opts{json_indent} );
}

sub ep3xml_to_json
{
	my( $plugin, $xml, $indent ) = @_;

	$indent = 0 if !defined $indent;

	my $pad = "  "x$indent;
	#$pad= "|$pad";

	my $type = "text";
	foreach my $node ( $xml->getChildNodes() )
	{
		if( EPrints::XML::is_dom( $node, "Element" ) )
		{
			if( $node->tagName eq "item" )
			{
				$type = "list";
			}
			else
			{
				$type = "hash";
			}
			last;
		}
	}
	
	my $name = $xml->tagName;
	$type = "list" if( $name eq "documents" );
	$type = "list" if( $name eq "files" );

	if( $type eq "list" )
	{
		my @r = ();	
		foreach my $node ( $xml->getChildNodes() )
		{
			next unless( EPrints::XML::is_dom( $node, "Element" ) );
			push @r, $plugin->ep3xml_to_json( $node, $indent+1 );
		}
		return "[\n$pad  ".join( ",\n$pad  ", @r )."\n$pad]";
	}

	if( $type eq "hash" )
	{
		my @r = ();	
		foreach my $node ( $xml->getChildNodes() )
		{
			next unless( EPrints::XML::is_dom( $node, "Element" ) );
			my $n = $node->getName();
			$n =~ s/["\\]/\\$&/g;
			push @r, '"'.$n.'": '.$plugin->ep3xml_to_json( $node, $indent+1 );
		}
		return "{\n$pad  ".join( ",\n$pad  ", @r )."\n$pad}";
	}

	# must be text
	
	my $v = EPrints::Utils::tree_to_utf8( EPrints::XML::contents_of( $xml ) );
	$v =~ s/["\\]/\\$&/g;
	$v =~ s/\n/\\n/g;
	return '"'.$v.'"';
}


1;
