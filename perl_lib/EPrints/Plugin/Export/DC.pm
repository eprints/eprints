package EPrints::Plugin::Export::DC;

# eprint needs magic documents field

# documents needs magic files field

use EPrints::Plugin::Export::TextFile;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Dublin Core";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";

	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $r = "";
	foreach( @{$data} )
	{
		next unless defined( $_->[1] );
		my $v = $_->[1];
		$v=~s/[\r\n]/ /g;
		$r.=$_->[0].": $v\n";
	}
	$r.="\n";
	return $r;
}

sub dataobj_to_html_header
{
	my( $plugin, $dataobj ) = @_;

	my $links = $plugin->{handle}->make_doc_fragment;

	$links->appendChild( $plugin->{handle}->make_element(
		"link",
		rel => "schema.DC",
		href => "http://purl.org/DC/elements/1.0/" ) );
	$links->appendChild( $plugin->{handle}->make_text( "\n" ));
	my $dc = $plugin->convert_dataobj( $dataobj );
	foreach( @{$dc} )
	{
		$links->appendChild( $plugin->{handle}->make_element(
			"meta",
			name => "DC.".$_->[0],
			content => $_->[1] ) );
		$links->appendChild( $plugin->{handle}->make_text( "\n" ));
	}
	return $links;
}

	

sub convert_dataobj
{
	my( $plugin, $eprint ) = @_;

	my @dcdata = ();
	push @dcdata, [ "title", $eprint->get_value( "title" ) ] if( $eprint->exists_and_set( "title" ) ); 

	# grab the creators without the ID parts so if the site admin
	# sets or unsets creators to having and ID part it will make
	# no difference to this bit.

	if( $eprint->exists_and_set( "creators_name" ) )
	{
		my $creators = $eprint->get_value( "creators_name" );
		if( defined $creators )
		{
			foreach my $creator ( @{$creators} )
			{	
				next if !defined $creator;
				push @dcdata, [ "creator", EPrints::Utils::make_name_string( $creator ) ];
			}
		}
	}

	if( $eprint->exists_and_set( "subjects" ) )
	{
		my $subjectid;
		foreach $subjectid ( @{$eprint->get_value( "subjects" )} )
		{
			my $subject = EPrints::DataObj::Subject->new( $plugin->{handle}, $subjectid );
			# avoid problems with bad subjects
				next unless( defined $subject ); 
			push @dcdata, [ "subject", EPrints::Utils::tree_to_utf8( $subject->render_description() ) ];
		}
	}

	push @dcdata, [ "description", $eprint->get_value( "abstract" ) ] if( $eprint->exists_and_set( "abstract" ) ); 
	push @dcdata, [ "publisher", $eprint->get_value( "publisher" ) ] if( $eprint->exists_and_set( "publisher" ) ); 

	if( $eprint->exists_and_set( "editors_name" ) )
	{
		my $editors = $eprint->get_value( "editors_name" );
		if( defined $editors )
		{
			foreach my $editor ( @{$editors} )
			{
				push @dcdata, [ "contributor", EPrints::Utils::make_name_string( $editor ) ];
			}
		}
	}

	## Date for discovery. For a month/day we don't have, assume 01.
	if( $eprint->exists_and_set( "date" ) )
	{
		my $date = $eprint->get_value( "date" );
		if( defined $date )
		{
			$date =~ s/(-0+)+$//;
			push @dcdata, [ "date", $date ];
		}
	}
	
	if( $eprint->exists_and_set( "type" ) )
	{
		push @dcdata, [ "type", EPrints::Utils::tree_to_utf8( $eprint->render_value( "type" ) ) ];
	}

	my $ref = "NonPeerReviewed";
	if( $eprint->exists_and_set( "refereed" ) && $eprint->get_value( "refereed" ) eq "TRUE" )
	{
		$ref = "PeerReviewed";
	}
	push @dcdata, [ "type", $ref ];


	my @documents = $eprint->get_all_documents();
	my $mimetypes = $plugin->{handle}->get_repository->get_conf( "oai", "mime_types" );
	foreach( @documents )
	{
		my $format = $mimetypes->{$_->get_value("format")};
		$format = $_->get_value("format") unless defined $format;
		#$format = "application/octet-stream" unless defined $format;
		push @dcdata, [ "format", $format ];
		push @dcdata, [ "identifier", $_->get_url() ];
	}

	# Most commonly a DOI or journal link
	if( $eprint->exists_and_set( "official_url" ) )
	{
		push @dcdata, [ "relation", $eprint->get_value( "official_url" ) ];
	}
	
	# The citation for this eprint
	push @dcdata, [ "identifier",
		EPrints::Utils::tree_to_utf8( $eprint->render_citation() ) ];

	# The URL of the abstract page
	push @dcdata, [ "relation", $eprint->get_url() ];

	# dc.language not handled yet.
	# dc.source not handled yet.
	# dc.coverage not handled yet.
	# dc.rights not handled yet.

	return \@dcdata;
}


1;
