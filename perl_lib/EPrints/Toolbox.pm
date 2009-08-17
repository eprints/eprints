######################################################################
#
# EPrints::Toolbox
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

B<EPrints::Toolbox> - Toolbox for access to modify objects.

=head1 DESCRIPTION

The EPrints toolbox which provides a high level API for EPrints. This can be used via the toolbox commandline and CGI tools.

__GENERICPOD__

=cut

package EPrints::Toolbox;

use strict;

use EPrints;

sub ensure
{
	my( $params, @wanted ) = @_;

	my @problems = ();
	foreach my $wanted_param ( @wanted )
	{
		if( !defined $params->{$wanted_param} )
		{
			push @problems, "Missing param '$wanted_param'";
		}
	}

	return @problems;
}

sub get_data
{
	my( %opts ) = @_;

	if( defined $opts{data_fn} )
	{
		return &{$opts{data_fn}}( %opts );
	}

	return join( "", <STDIN> );
}

sub tool_getEprintField
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session', 'eprint', 'field' );
	return( 1, \@problems ) if( @problems );

	my $field = $opts{eprint}->get_dataset->get_field( $opts{field} );

	my $fieldxml = $field->to_xml( 
			$opts{handle},
			$opts{eprint}->get_value( $opts{field} ),
			$opts{eprint}->get_dataset );

	return( 0, EPrints::XML::to_string( $fieldxml ) );
}

sub tool_getEprint
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session', 'eprint' );
	return( 1, \@problems ) if( @problems );

	return( 0, $opts{eprint}->export( "XML" ) );
}

sub tool_getEprintCitation
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session', 'eprint', 'format' );
	return( 1, \@problems ) if( @problems );

	return( 0, EPrints::XML::to_string( $opts{eprint}->render_citation( $opts{format} ) ) );
}

sub tool_createEprint
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session' );
	return( 1, \@problems ) if( @problems );

	my $data = get_data( %opts );
	my $xml = EPrints::XML::parse_xml_string( $data );
	if( !defined $xml ) { return( 1, [ "Failed to parse XML" ] ); }

	my $plugin = $opts{handle}->plugin( "Import::XML" );
	my $ds = $opts{handle}->get_repository->get_dataset( "eprint" );
	my $eprint = $plugin->xml_to_dataobj( $ds, $xml->getDocumentElement );

	if( !defined $eprint )
	{
		return( 1, [ "Creation failed" ] );
	}
	
	return( 0, $eprint->get_id."\n" );
}

sub tool_removeEprint
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session', 'eprint' );
	return( 1, \@problems ) if( @problems );

	if( !$opts{eprint}->remove )
	{
		return( 1, [ "EPrint remove failed" ] );
	}

	return( 0, "OK\n" );
}
	
sub tool_modifyEprint
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session', 'eprint' );
	return( 1, \@problems ) if( @problems );

	my $data = get_data( %opts );
	my $xml = EPrints::XML::parse_xml_string( $data );
	if( !defined $xml ) { return( 1, [ "Failed to parse XML" ] ); }

	my $plugin = $opts{handle}->plugin( "Import::XML" );
	my $ds = $opts{handle}->get_repository->get_dataset( "eprint" );
	my $epdata = $plugin->xml_to_epdata( $ds, $xml->getDocumentElement );

	foreach my $fieldid ( keys %{$epdata} )
	{
		next if( $fieldid eq "documents" );
		$opts{eprint}->set_value( $fieldid, $epdata->{$fieldid} );
	}
	$opts{eprint}->commit;

	$opts{eprint}->generate_static;
		
	return( 0, "OK\n" );
}

sub tool_removeDocument
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session', 'document' );
	return( 1, \@problems ) if( @problems );

	my $eprint = $opts{document}->get_eprint;

	if( !$opts{document}->remove )
	{
		return( 1, [ "Document remove failed" ] );
	}

	$eprint->generate_static;

	return( 0, "OK\n" );
}


sub tool_modifyDocument
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session', 'document' );
	return( 1, \@problems ) if( @problems );

	my $data = get_data( %opts );
	my $xml = EPrints::XML::parse_xml_string( $data );
	if( !defined $xml ) { return( 1, [ "Failed to parse XML" ] ); }

	my $plugin = $opts{handle}->plugin( "Import::XML" );
	my $ds = $opts{handle}->get_repository->get_dataset( "document" );
	my $epdata = $plugin->xml_to_epdata( $ds, $xml->getDocumentElement );

	foreach my $fieldid ( keys %{$epdata} )
	{
		next if( $fieldid eq "files" );
		$opts{document}->set_value( $fieldid, $epdata->{$fieldid} );
	}
	$opts{document}->commit;

	$opts{document}->get_eprint->generate_static;
		
	return( 0, "OK\n" );
}

sub tool_getFile
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session', 'document', 'filename' );
	return( 1, \@problems ) if( @problems );

	my $fpath = $opts{document}->local_path."/".$opts{filename};

	if( !-e $fpath )
	{
		return( 1, [ "File $fpath not found." ] );
	}

	if( !open( EPFILE, $fpath ) ) 
	{
		return( 1, [ "Could not open $fpath: $!." ] );
	}
	my $data = join( "",<EPFILE> );
	close EPFILE;

	return( 0, $data );
}


sub tool_addFile
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session', 'document', 'filename' );
	return( 1, \@problems ) if( @problems );

	my $fpath = $opts{document}->local_path."/".$opts{filename};

	my $filename = $opts{filename};
	if( $filename =~ m#[\?\*\ \t\/]# )
	{
		return( 1, [ "'$filename' has some iffy characters." ] );
	}
 
	my $fullpath = $opts{document}->local_path."/".$filename;
	unless( open( FH, ">$fullpath" ) )
	{
		return( 1, [ "Could not write to $fullpath" ] );
	}
	print FH get_data( %opts );
	close FH;

	$opts{document}->files_modified;
	$opts{document}->get_eprint->generate_static;

	return( 0, "OK\n" );
}

sub tool_removeFile
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session', 'document', 'filename' );
	return( 1, \@problems ) if( @problems );

	my $fpath = $opts{document}->local_path."/".$opts{filename};

	if( !-e $fpath )
	{
		return( 1, [ "File $fpath not found." ] );
	}

	if( !$opts{document}->remove_file( $opts{filename} ) )
	{
		return( 1, [ "Could not remove $fpath." ] );
	}

	return( 0, "OK" );
}

sub tool_addDocument
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session', 'eprint' );
	return( 1, \@problems ) if( @problems );

	my $data = get_data( %opts );
	my $xml = EPrints::XML::parse_xml_string( $data );
	if( !defined $xml ) { return( 1, [ "Failed to parse XML" ] ); }

	my $plugin = $opts{handle}->plugin( "Import::XML" );
	my $ds = $opts{handle}->get_repository->get_dataset( "document" );
	my $epdata = $plugin->xml_to_epdata( $ds, $xml->getDocumentElement );

	$epdata->{eprintid} = $opts{eprint}->get_id;
	my $document = EPrints::DataObj::Document->create_from_data( $opts{handle}, $epdata, $ds );

	if( !defined $document )
	{
		return( 1, [ "Could not add document." ] );
	}

	$opts{eprint}->generate_static;
		
	return( 0, $document->get_id."\n" );
}


sub _aux_tool_searchEprint
{
	my( %opts ) = @_;

	my @problems = ensure( \%opts, 'session' );
	return( 1, \@problems ) if( @problems );

	my $data = get_data( %opts );
	my $xml = EPrints::XML::parse_xml_string( $data );
	if( !defined $xml ) { return( 1, [ "Failed to parse XML" ] ); }

	my @kids = $xml->documentElement->getChildNodes;

	my $order = $xml->documentElement->getAttribute( "order" );
	$order = undef if $order eq "";

	my $condition_top = undef;
	foreach my $kid ( @kids )
	{
		next unless( EPrints::XML::is_dom( $kid, "Element" ) );
		my $nodename = $kid->nodeName();
		if( defined $condition_top )
		{
			return( 1, [ "Second search element: $nodename in <search> (there can be only one)" ] );
		}
		$condition_top = $kid;
	}

	if( !defined $condition_top )
	{
		return( 1, [ "No nodes found inside <search> (there must be only one)" ] );	
	}
	my $dataset = $opts{handle}->get_repository->get_dataset( 'eprint' ); 
	my( $conditions, $error ) = xml_to_conditions( $opts{handle}, $dataset, $condition_top );
	if( defined $error )
	{
		return( 1, [ $error ] );
	}

	return( 0, $conditions->process( $opts{handle} ), $order );
}
	

sub tool_idSearchEprints
{
	my( %opts ) = @_;

	my( $rc, $value, $order ) = _aux_tool_searchEprint( %opts );

	if( $rc ) { return( $rc, $value ); }

	return( 0, join( "\n", @{$value} )."\n" );
}


sub tool_xmlSearchEprints
{
	my( %opts ) = @_;

	my( $rc, $value, $order ) = _aux_tool_searchEprint( %opts );

	if( $rc ) { return( $rc, $value ); }

	my $dataset = $opts{handle}->get_repository->get_dataset( 'eprint' ); 
	my $list = EPrints::List->new( 
		handle => $opts{handle},
		dataset => $dataset,
		ids => $value,
		keep_cache=>1,
		order => $order );

	my $plugin = $opts{handle}->plugin( "Export::XML" );

	return( 0, $plugin->output_list( list=>$list ) );
}


sub xml_to_conditions
{
	my( $handle, $dataset, $xml ) = @_;

	unless( EPrints::XML::is_dom( $xml, "Element" ) )
	{
		return( undef, "Non element passed to xml_to_conditions" );
	}

	my $tagname = $xml->nodeName();

	if( $tagname eq "and" || $tagname eq "or" )
	{
		my @r = ();
		foreach my $kid ( $xml->getChildNodes )
		{
			next unless( EPrints::XML::is_dom( $kid, "Element" ) );
			my( $result, $error ) = xml_to_conditions( $handle, $dataset, $kid );
			if( !defined $result ) { return( undef, $error ); }
			push @r, $result;
		}
	
		return EPrints::Search::Condition->new( "\U$tagname", @r );
	}


	if( $tagname eq "false" )
	{
		return EPrints::Search::Condition->new( 'FALSE' );
	}

	if( $tagname eq "true" )
	{
		return EPrints::Search::Condition->new( 'TRUE' );
	}

	if( $tagname eq "field" )
	{
		my $name = $xml->getAttribute( "name" );
		if( !defined $name )
		{
			return( undef, "missing a name attribute on a field tag" );
		}

		my $match = $xml->getAttribute( "match" );
		if( defined $match && $match !~ m/^IN|EQ|EX|$/ )
		{
			return( undef, "match set to $match. Can only be IN EQ or EX" );
		}

		my $merge = $xml->getAttribute( "merge" );
		if( defined $merge && $merge !~ m/^ANY|ALL|$/ )
		{
			return( undef, "merge set to $merge. Can only be ANY or ALL." );
		}

		my $field = EPrints::Utils::field_from_config_string( $dataset, $name );
		if( !defined $field )
		{
			return( undef, "can't find field '$name'" );
		}

		my $value = EPrints::XML::to_string( EPrints::XML::contents_of( $xml ) );

		my $con = $field->get_search_conditions(
				$handle,
				$dataset,
				$value,
				$match,
				$merge );
		return( $con );	
	}

	return( undef, "Unknown search condition tag: $tagname" );
}

1;
