package EPrints::Plugin::Sword::Import::EPrintsXML;

use strict;

our @ISA = qw/ EPrints::Plugin::Sword::Import /;

our %SUPPORTED_MIME_TYPES = 
(
	"text/xml" => 1,
	"application/zip" => 1,
);

our %UNPACK_MIME_TYPES = 
(
	"application/zip" => "Sword::Unpack::Zip",
);


sub new
{
	my( $class, %params ) = @_;
	my $self = $class->SUPER::new(%params);
	$self->{name} = "SWORD Importer - EPrints XML";
	$self->{visible} = "";
	return $self;
}


##        $opts{file} = $file;
##        $opts{mime_type} = $headers->{content_type};
##        $opts{dataset_id} = $target_collection;
##        $opts{owner_id} = $owner->get_id;
##        $opts{depositor_id} = $depositor->get_id if(defined $depositor);
##        $opts{no_op}   = is this a No-op?
##        $opts{verbose} = is this verbosed?
sub input_file
{
        my ( $plugin, %opts) = @_;

        my $session = $plugin->{session};
	my $file = $opts{file};
	my $mime = $opts{mime_type};

        my $NO_OP = $opts{no_op};
        my $VERBOSE = $opts{verbose};

	unless( defined $SUPPORTED_MIME_TYPES{$mime} )
	{
		$plugin->add_verbose("[ERROR] unknown MIME TYPE '$mime'.");
		$plugin->set_status_code( 415 );
		return undef;
	}	

	my $unpacker = $UNPACK_MIME_TYPES{$mime};

	my $tmp_dir;

	if( defined $unpacker )
	{
	        $tmp_dir = EPrints::TempDir->new( "swordXXX", UNLINK => 0 );

        	if( !defined $tmp_dir )
	        {
        	        print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to create the temp directory!";
	                $plugin->add_verbose("[INTERNAL ERROR] failed to create the temp directory.");
        	        $plugin->set_status_code( 500 );
                	return undef;
	        }

		my $files = $plugin->unpack_files( $unpacker, $file, $tmp_dir );
		unless(defined $files)
		{
	                $plugin->add_verbose("[ERROR] failed to unpack the files.");
			$plugin->set_status_code( 400 );
			return undef;
		}
	
		my $candidates = $plugin->get_files_to_import( $files, "text/xml" );

		if(scalar(@$candidates) == 0)
		{
	                $plugin->add_verbose("[ERROR] could not find the XML file.");
        	        $plugin->set_status_code( 400 );
			return undef;
		}
		elsif(scalar(@$candidates) > 1)
		{
	                $plugin->add_verbose("[WARNING] there were more than one XML files in this archive. I am using the first one.");
		}	
		
		$file = $$candidates[0];
	}

        my $dataset_id = $opts{dataset_id};
        my $owner_id = $opts{owner_id};
        my $depositor_id = $opts{depositor_id};

        my $ds = $session->get_archive()->get_dataset( $dataset_id );

        my $fh;

        if(!open( $fh, $file ) )
        {
                print STDERR "\n[SWORD-EPRINTSXML] [ERROR] Cannot open file xml file ".$file." because $!";
	        $plugin->add_verbose("[ERROR] cannot open XML file ($!).");
        	$plugin->set_status_code( 500 );
                return;
        }

        if(defined $owner_id)
        {
                $plugin->{owner_userid} = $owner_id;
        }

        if(defined $depositor_id)
        {
                $plugin->{depositor_userid} = $depositor_id;
        }

	$plugin->{parse_only} = $NO_OP;
	
        my $handler = {
                dataset => $ds,
                state => 'toplevel',
                plugin => $plugin,
                depth => 0,
                tmpfiles => [],
                imported => [], 
	};

	eval {
	        bless $handler, "EPrints::Plugin::Sword::Import::EPrintsXML::Handler";
        	EPrints::XML::event_parse( $fh, $handler );
	};

	if($@)
	{
		# Assuming that the XML couldn't be parsed
		close $fh;
	        $plugin->add_verbose("[ERROR] failed to parse the XML file ($@).");
        	$plugin->set_status_code( 400 );
		return undef;
	}

	close $fh;

	if( $NO_OP )
	{
                $plugin->add_verbose( "[OK] Plugin - import successful (but in No-Op mode)." );
                $plugin->set_status_code( 200 );
                return;
        }

        my $ids = $handler->{imported};

        unless( scalar @$ids > 0 )
	{
		$plugin->add_verbose("[ERROR] failed to parse the XML file (invalid format).");
		$plugin->set_status_code( 400 );
		return undef;
	}

	my $eprint = EPrints::DataObj::EPrint->new( $session, $$ids[0] );

	unless( defined $eprint )
	{
		$plugin->add_verbose("[INTERNAL ERROR] failed to open the newly created EPrint object.");
		$plugin->set_status_code( 500 );
		return undef;
	}

        if( $plugin->keep_deposited_file() )
        {
                if( $plugin->attach_deposited_file( $eprint, $opts{file}, $opts{mime_type} ) )
                {
                        $plugin->add_verbose( "[OK] attached deposited file." );
                }
                else
                {
                        $plugin->add_verbose( "[WARNING] failed to attach the deposited file." );
                }
        }

        $plugin->add_verbose( "[OK] EPrint object created." );

        return $eprint;

}

sub keep_deposited_file
{
        return 1;
}



# if this is defined then it is used to check that the top
# level XML element is correct.

sub top_level_tag
{
	my( $plugin, $dataset ) = @_;

	return $dataset->confid."s";

}

sub xml_to_dataobj
{
	my( $plugin, $dataset, $xml ) = @_;

	my $epdata = $plugin->xml_to_epdata( $dataset, $xml );

	if( $plugin->{parse_only} )
	{
		$plugin->{parse_ok} = 1;
		return;
	}

# SWORD
	if(defined $plugin->{depositor_userid})
	{
		$$epdata{sword_depositor} = $plugin->{depositor_userid};
	}

# SWORD
	if(defined $plugin->{owner_userid})
        {
                $$epdata{userid} = $plugin->{owner_userid};
        }

# SWORD
	if(!defined $plugin->{count})
	{
		$plugin->{count} = 1;
	}
	else
	{
		return;
	}
	
	return $plugin->epdata_to_dataobj( $dataset, $epdata );
}

sub xml_to_epdata
{
	my( $plugin, $dataset, $xml ) = @_;

        my @fields = $dataset->get_fields;
        my @fieldnames = ();
        foreach( @fields ) { push @fieldnames, $_->get_name; }

        my %toprocess = $plugin->get_known_nodes( $xml, @fieldnames );

        my $epdata = {};
        foreach my $fn ( keys %toprocess )
        {
		next if $fn eq 'eprintid';

                my $field = $dataset->get_field( $fn );

                $epdata->{$fn} = $plugin->xml_field_to_epdatafield( $dataset, $field, $toprocess{$fn} );
        }
        return $epdata;
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
		$plugin->warning( $plugin->phrase( "unexpected_xml", xml => $xml->toString ) );
	}
	my $r = join( "", @v );

	return $r;
}

sub xml_to_file
{
        my( $plugin, $dataset, $xml ) = @_;

        my %toprocess = $plugin->get_known_nodes( $xml, qw/ filename filesize url data / );

        my $data = {};
        foreach my $part ( keys %toprocess )
        {
                $data->{$part} = $plugin->xml_to_text( $toprocess{$part} );
        }

        return $data;
}

sub xml_field_to_epdatafield
{
        my( $plugin,$dataset,$field,$xml ) = @_;

        unless( $field->get_property( "multiple" ) )
        {
                return $plugin->xml_field_to_data_single( $dataset,$field,$xml );
        }

        my $epdatafield = [];
        my @list = $xml->getChildNodes;
        foreach my $el ( @list )
        {
                next unless EPrints::XML::is_dom( $el, "Element" );
                my $type = $el->nodeName;
                if( $field->is_type( "subobject" ) )
                {
                        my $expect = $field->get_property( "datasetid" );
                        if( $type ne $expect )
                        {
                                $plugin->warning( $plugin->phrase( "unexpected_type",
                                        type => $type,
                                        expected => $expect,
                                        fieldname => $field->get_name ) );
                                next;
                        }
                        my $sub_dataset = $plugin->{session}->get_repository->get_dataset( $expect );
                        push @{$epdatafield}, $plugin->xml_to_epdata( $sub_dataset,$el );
                        next;
                }

                if( $field->is_type( "file" ) )
                {
                        if( $type ne "file" )
                        {
                                $plugin->warning( $plugin->phrase( "expected_file", type => $type, fieldname => $field->get_name ) );
                                next;
                        }
                        push @{$epdatafield}, $plugin->xml_to_file( $dataset,$el );
                        next;
                }

                if( $field->is_virtual && !$field->is_type( "compound","multilang") )
                {
                        $plugin->warning( $plugin->phrase( "unknown_virtual", type => $type, fieldname => $field->get_name ) );
                        next;
                }

                if( $type ne "item" )
                {
                        $plugin->warning( $plugin->phrase( "expected_item", type => $type, fieldname => $field->get_name ) );
                        next;
                }
                push @{$epdatafield}, $plugin->xml_field_to_data_single( $dataset,$field,$el );
        }

        return $epdatafield;
}

sub xml_field_to_data_single
{
        my( $plugin,$dataset,$field,$xml ) = @_;
       return $plugin->xml_field_to_data_basic( $dataset, $field, $xml );
}

sub xml_field_to_data_basic
{
        my( $plugin,$dataset,$field,$xml ) = @_;

        if( $field->is_type( "compound","multilang") )
        {
                my $data = {};
                my @list = $xml->getChildNodes;
                my %a_to_f = $field->get_alias_to_fieldname;
                foreach my $el ( @list )
                {
                        next unless EPrints::XML::is_dom( $el, "Element" );
                        my $nodename = $el->nodeName();
                        my $name = $a_to_f{$nodename};
                        if( !defined $name )
                        {
                                $plugin->warning( "Unknown element found inside compound field: $nodename. (skipping)" );
                                next;
                        }
                        my $f = $dataset->get_field( $name );
                        $data->{$nodename} = $plugin->xml_field_to_data_basic( $dataset, $f, $el );
                }
                return $data;
        }

        unless( $field->is_type( "name" ) )
        {
                return $plugin->xml_to_text( $xml );
        }

        my %toprocess = $plugin->get_known_nodes( $xml, qw/ given family lineage honourific / );


        my $epdatafield = {};
        foreach my $part ( keys %toprocess )
        {
                $epdatafield->{$part} = $plugin->xml_to_text( $toprocess{$part} );
        }
        return $epdatafield;
}

sub get_known_nodes
{
        my( $plugin, $xml, @whitelist ) = @_;

        my @list = $xml->getChildNodes;
        my %map = ();
        foreach my $el ( @list )
        {
                next unless EPrints::XML::is_dom( $el, "Element" );
                if( defined $map{$el->nodeName()} )
                {
                        $plugin->warning( $plugin->phrase( "dup_element", name => $el->nodeName ) );
                        next;
                }
                $map{$el->nodeName()} = $el;
        }

        my %toreturn = ();
        foreach my $oknode ( @whitelist )
        {
                next unless defined $map{$oknode};
                $toreturn{$oknode} = $map{$oknode};
                delete $map{$oknode};
        }

        foreach my $name ( keys %map )
        {
                $plugin->warning( $plugin->phrase( "unexpected_element", name => $name ) );
                $plugin->warning( $plugin->phrase( "expected", elements => "<".join("> <", @whitelist).">" ) );
        }
        return %toreturn;
}

package EPrints::Plugin::Sword::Import::EPrintsXML::Handler;

use strict;

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

sub end_element
{
        my( $self , $node_info ) = @_;

	$self->{depth}--;

	if( $self->{depth} == 1 )
	{
		my $item = $self->{plugin}->xml_to_dataobj( $self->{dataset}, $self->{xml} );

		unless( $self->{plugin}->{parse_only} )
		{
		
			if( defined $item )
			{
				# SWORD
				if(scalar @{$self->{imported}} < 1)
				{	
					push @{$self->{imported}}, $item->get_id;
				} 
			}	
		}

		# don't keep tmpfiles between items...
		foreach( @{$self->{tmpfiles}} )
		{
			unlink( $_ );
		}
	}

	if( $self->{depth} > 1 )
	{
		if( $self->{base64} )
		{
			$self->{base64} = 0;
			my $tf = $self->{tmpfilecount}++;
			my $tmpfile = "/tmp/epimport.$$.".time.".$tf.data";
			$self->{tmpfile} = $tmpfile;
			push @{$self->{tmpfiles}},$tmpfile;
			open( TMP, ">$tmpfile" );
			print TMP MIME::Base64::decode( join('',@{$self->{base64data}}) );
			close TMP;

			$self->{xmlcurrent}->appendChild( 
				$self->{plugin}->{session}->make_text( $tmpfile ) );
			delete $self->{basedata};
		}
		pop @{$self->{xmlstack}};
		
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
			return undef;
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
		if( $params{encoding} && $params{encoding} eq "base64" )
		{
			$self->{base64} = 1;
			$self->{base64data} = [];
		}
	}

	$self->{depth}++;
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
