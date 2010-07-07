package EPrints::Plugin::Sword::Import::EPrintsXML;

use strict;

use Data::Dumper;

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
	        $tmp_dir = File::Temp->newdir( "swordXXX" );

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
                plugin => $plugin,
                depth => 0,
                imported => [], 
	};

	bless $handler, "EPrints::Plugin::Import::DefaultXML::Handler";

	eval {
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

sub epdata_to_dataobj
{
	my( $plugin, $dataset, $epdata ) = @_;

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

	# SWORD - import only the first document:

	my $docs = $epdata->{documents};
	if( EPrints::Utils::is_set( $docs ) && scalar(@$docs) > 1 )
	{
		my @slice = @$docs[0];
		$epdata->{documents} = \@slice;
	}

	return $plugin->SUPER::epdata_to_dataobj( $dataset, $epdata );
}

1;
