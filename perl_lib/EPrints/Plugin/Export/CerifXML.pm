package EPrints::Plugin::Export::CerifXML;

=head1 NAME

EPrints::Plugin::Export::CerifXML - Cerif 2008 XML Export

=head1 DESCRIPTION

This plugin exports records in Cerif 2008 1.0 XML format. Cerif records are in multiple files each with its own schema. To accommodate this the plugin outputs a ZIP-format archive containing multiple files, one per Cerif schema.

The remainder of this section describes each of the output files.

=head2 cfPers-CORE.xml

	cfPersId - MD5 of 'eprint'+eprint.id+eprint.creators_name[i]

=head2 cfPers_ResPubl-LINK.xml

	cfPersId - (see cfPers-CORE)
	cfResPublId - (see cfResPubl-RES)
	cfStartDate - cfResPubl->cfResPublDate
	cfEndDate - undefined
	cfClassId - 
	cfClassSchemeId - 

=head2 cfPersName-ADD.xml

	cfPersId - (see cfPers-CORE)
	cfFamilyNames - eprint.creators_name.family
	cfFirstNames - eprint.creators_name.given

=head2 cfProj-CORE.xml

	cfProjId -
		project.projectid or
		MD5 of 'eprint'+eprint.id+eprint.projects[i]{title}
	cfAcro - project.acronym
	cfURI - project.uri

=head2 cfProj_ResPubl-LINK.xml

	cfProjId - (see cfProj-CORE)
	cfPublId - (see cfResPubl-RES)
	cfClassId - 'is originator of'
	cfClassSchemeId - 'cfProject-ResultPublicationRoles'

=head2 cfProjAbstr-LANG.xml

	cfProjId - (see cfProj-CORE)
	cfAbstr - project.description
	cfLangCode - 'en'
	cfTrans - '0'

=head2 cfProjKeyw-LANG.xml

	cfProjId - (see cfProj-CORE)
	cfKeyw - project.keywords
	cfLangCode - 'en'
	cfTrans - '0'

=head2 cfProjTitle-LANG.xml

	cfProjId - (see cfProj-CORE)
	cfTitle - project.title or eprint.projects[i]{title}
	cfLangCode - 'en'
	cfTrans - '0'

=head2 cfResPubl-RES.xml

	cfResPublId - eprint.eprintid
	cfResPublDate - eprint.date (padded with -01-01)
	cfNum - eprint.number
	cfVol - eprint.volume
	cfStartPage - eprint.pagerange (everything before '-')
	cfEndPage - eprint.pagerange (everything after '-')
	cfURI - eprint.get_uri()
	cfEdition - eprint.edition (not in default configuration)
	cfSeries - eprint.series
	cfTotalPages - eprint.pages

If eprint.type is 'book' or ResPubl is a journal/publication link:

	cfISBN - eprint.isbn
	cfISSN - eprint.issn

=head2 cfResPubl_Class-LINK.xml

	cfResPublId - (see cfResPubl-RES)
	cfClassId - 
	cfClassSchemeId -

=head2 cfResPubl_ResPubl-LINK.xml

	cfResPublId1 - (see cfResPubl-RES)
	cfResPublId2 - (see cfResPubl-RES)
	cfClassId - 'is part of'
	cfClassSchemeId - 'RESPUBL-RESPUBL'

=head2 cfResPublTitle-LANG.xml

	cfResPublId - eprint.eprintid
	cfTitle - eprint.title or eprint.publication
	cfLangCode - 'en'
	cfTrans - '0'

=head2 cfResPublAbstr-LANG.xml

	cfResPublId - eprint.eprintid
	cfAbstr - eprint.abstract
	cfLangCode - 'en'
	cfTrans - '0'

=head1 METHODS

=over 4

=cut

use Digest::MD5;
use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

our %GRAMMAR;

$GRAMMAR{eprint} = [
	cfResPublId => { value => sub { $_[0]->id } },
	cfResPublDate => { depends => [qw( date )], value => sub { expand_date($_[0]->value( 'date' )) } },
	cfNum => { depends => [qw( number )], value => sub { $_[0]->value( 'number' ) } },
	cfVol => { depends => [qw( volume )], value => sub { $_[0]->value( 'volume' ) } },
	cfEdition => { depends => [qw( edition )], value => sub { $_[0]->value( 'edition' ) } },
	cfSeries => { depends => [qw( series )], value => sub { $_[0]->value( 'series' ) } },
	cfIssue => { depends => [qw( issue )], value => sub { $_[0]->value( 'issue' ) } },
	cfStartPage => { depends => [qw( pagerange )], value => sub { (split(/\-/,$_[0]->value( 'pagerange' )))[0] } },
	cfEndPage => { depends => [qw( pagerange )], value => sub { (split(/\-/,$_[0]->value( 'pagerange' )))[1] } },
	cfTotalPages => { depends => [qw( pages )], value => sub { $_[0]->value( 'pages' ) } },
	cfISBN => { depends => [qw( isbn )], value => sub { return $_[0]->value( 'type' ) eq 'book' ? $_[0]->value( 'isbn' ) : undef } },
	cfISSN => { depends => [qw( issn )], value => sub { return $_[0]->value( 'type' ) eq 'book' ? $_[0]->value( 'issn' ) : undef } },
	cfURI => { value => sub { $_[0]->uri } },
];
$GRAMMAR{project} = [
];

our %cfPublicationTypes = (
	article => "Journal Article",
	book => "Book",
);

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Cerif XML 2008";
	$self->{accept} = [ 'list/eprint' ];
	$self->{visible} = "staff";
	$self->{advertise} = 1;
	$self->{suffix} = ".zip";
	$self->{mimetype} = "application/zip";

	return $self;
}

sub init
{
	my( $self ) = @_;

	my $tmpdir = EPrints::TempDir->new( CLEANUP => 1 );
	$self->{dir} = $tmpdir;

	$self->{sourceDatabase} = $self->{session}->phrase( "archive_name" );
	my @date = gmtime();
	$self->{date} = sprintf("%04d-%02d-%02d",
		$date[5]+1900,
		$date[4]+1,
		$date[3] );
}

sub finish
{
	my( $self ) = @_;

	my @files;
	foreach my $name (keys %{$self->{files}})
	{
		$self->close_cerif_file( $name );
		push @files, "$self->{dir}/$name.xml";
	}

	my $readme_txt = "$self->{dir}/README.TXT";
	my $cmd = "perldoc -l ".__PACKAGE__;
	my $source = `$cmd`;
	system("pod2text", $source, $readme_txt);

	push @files, $readme_txt;

	my $tmpfile = File::Temp->new( SUFFIX => ".zip" );

	unlink($tmpfile);
	system("zip", "-q", "-FF", "-j", $tmpfile, @files);
	open($tmpfile, "<", $tmpfile);

	$self->{files} = {};
	undef $self->{dir};

	return $tmpfile;
}

sub open_cerif_file
{
	my( $self, $name ) = @_;

	if( !defined $self->{files}->{$name} )
	{
		my $path = "$self->{dir}/$name.xml";
		my $fh;
		open($fh, ">", $path)
			or EPrints->abort( "Can't write to $self->{tmpdir}: $!" );
		binmode($fh, ":utf8");
		print $fh <<EOX;
<?xml version="1.0" encoding="UTF-8"?>
<CERIF
	xsi:schemaLocation="http://www.eurocris.org/fileadmin/cerif-2008/XML-SCHEMAS/$name http://www.eurocris.org/fileadmin/cerif-2008/XML-SCHEMAS/$name.xsd"
	xmlns="http://www.eurocris.org/fileadmin/cerif-2008/XML-SCHEMAS/$name"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	release="2008-1.0"
	date="$self->{date}"
	sourceDatabase="$self->{sourceDatabase}"
>
EOX
		$self->{files}->{$name} = $fh;
	}

	print {$self->{files}->{$name}} "\n";

	return $self->{files}->{$name};
}

sub close_cerif_file
{
	my( $self, $name ) = @_;

	my $fh = $self->{files}->{$name};

	print $fh "\n</CERIF>\n";

	close($fh);
}

sub output_list
{
	my( $self, %opts ) = @_;

	my $rc = "";
	my $f = sub { $rc .= $_[0] };
	if( $opts{fh} )
	{
		$f = sub { print {$opts{fh}} $_[0] };
	}

	$self->init();

	my $cache = {};
	$opts{list}->map( sub {
		my( $session, $dataset, $dataobj ) = @_;

		$self->output_dataobj( $dataobj, %opts );
	} );

	my $zipfile = $self->finish;

	if( !-s $zipfile )
	{
		EPrints::abort( "Error: zip file is empty" );
	}

	seek($zipfile, 0, 0);
	my $buffer;
	while(sysread($zipfile,$buffer,1048576))
	{
		&$f( $buffer );
	}

	return $rc;
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	my $f = "output_".$dataobj->{dataset}->base_id;
	if( defined &$f )
	{
		$self->$f( $dataobj );
	}
}

sub output_eprint
{
	my( $self, $dataobj, %opts ) = @_;

	my $type = $dataobj->value( "type" );
	$type = "" if !defined $type;
	if( $type eq "patent" )
	{
		$self->output_patent( $dataobj, %opts );
	}

	my $xml = $self->{session}->xml;

	my $entity = $xml->create_element( "cfResPubl" );

	my $id_attr = $xml->create_element( "cfResPublId" );
	$id_attr->appendChild( $xml->create_text_node( $dataobj->id ) );

	my $grammar = $GRAMMAR{$dataobj->{dataset}->base_id};
	$grammar = [] if !defined $grammar;
	ATTR: for(my $i = 0; $i < @$grammar; $i+=2)
	{
		my( $key, $action ) = @$grammar[$i,$i+1];
		foreach( @{$action->{depends}||[]} )
		{
			next ATTR if !$dataobj->exists_and_set( $_ );
		}
		my $f = $action->{value};
		my $value = &$f( $dataobj );
		next if !EPrints::Utils::is_set( $value );
		my $attr = $xml->create_element( $key );
		$entity->appendChild( $attr );
		$attr->appendChild( $xml->create_text_node( $value ) );
	}

	my $fh = $self->open_cerif_file( "cfResPubl-RES" );
	print $fh $xml->to_string( $entity, indent => 1 );
	$xml->dispose( $entity );

	if( exists $cfPublicationTypes{$type} )
	{
		$self->output_relation( "cfResPubl_Class",
			from => $id_attr,
			class => $cfPublicationTypes{$type},
			scheme => "cfPublicationTypes",
		);
	}
	elsif( $type eq "thesis" && $dataobj->exists_and_set( "thesis_type" ) && $dataobj->value( "thesis_type" ) eq "phd" )
	{
		$self->output_relation( "cfResPubl_Class",
			from => $id_attr,
			class => "Doctoral Thesis",
			scheme => "cfPublicationTypes",
		);
	}

	if( $dataobj->exists_and_set( "title" ) )
	{
		$self->output_lang_attr( "cfResPublTitle",
			from => $id_attr,
			name => "cfTitle",
			value => $dataobj->value( "title" ) );
	}

	if( $dataobj->exists_and_set( "abstract" ) )
	{
		$self->output_lang_attr( "cfResPublAbstr",
			from => $id_attr,
			name => "cfAbstr",
			value => $dataobj->value( "abstract" ) );
	}

	if( $dataobj->exists_and_set( "keywords" ) )
	{
		$self->output_lang_attr( "cfResPublKeyw",
			from => $id_attr,
			name => "cfKeyw",
			value => $dataobj->value( "keywords" ) );
	}

	foreach my $creator (@{$dataobj->value( "creators" )})
	{
		my $fid_attr = $self->output_name( $dataobj, $creator->{name}, %opts );
		$self->output_relation( "cfPers_ResPubl",
			from => $fid_attr,
			to => $id_attr,
			start => expand_time( $dataobj->value( "date" ) ),
			class => "is author of",
			scheme => "csPerson-ResultPublicationRoles" );
	}

	foreach my $editor (@{$dataobj->value( "editors" )})
	{
		my $fid_attr = $self->output_name( $dataobj, $editor->{name}, %opts );
		$self->output_relation( "cfPers_ResPubl",
			from => $fid_attr,
			to => $id_attr,
			start => expand_time( $dataobj->value( "date" ) ),
			class => "is editor of",
			scheme => "csPerson-ResultPublicationRoles" );
	}

	if( $dataobj->exists_and_set( "publication" ) )
	{
		my $fid_attr = $self->output_publication( $dataobj, %opts );
		my $from = $id_attr->cloneNode( 1 );
		$from->setName( "cfResPublId1" );
		my $to = $fid_attr->cloneNode( 1 );
		$to->setName( "cfResPublId2" );
		$self->output_relation( "cfResPubl_ResPubl",
			from => $from,
			to => $to,
			class => "is part of",
			scheme => "RESPUBL-RESPUBL" );
	}

	if( $dataobj->exists_and_set( "projects" ) )
	{
		foreach my $project (@{$dataobj->value( "projects" )})
		{
			my $fid_attr = $self->output_project( $dataobj, $project, %opts,
					field => $dataobj->dataset->field( "projects" ),
				);
			$self->output_relation( "cfProj_ResPubl",
				from => $fid_attr,
				to => $id_attr,
				class => "is originator of",
				scheme => "cfProject-ResultPublicationRoles" );
		}
	}
}

sub output_project
{
	my( $self, $dataobj, $value, %opts ) = @_;

	my $xml = $self->{session}->xml;
	my $field = $opts{field};

	my $id;
	my $title;
	my $project;
	if( $field->isa( "EPrints::MetaField::Dataobjref" ) )
	{
		$id = $value->{id};
		$title = $value->{title};
		$project = $field->dataobj( $value );
	}
	else
	{
		$title = $value;
	}

	my $projectid;
	if( defined $project )
	{
		$projectid = $project->uri;
		if( $project->exists_and_set( "title" ) )
		{
			$title = $project->value( "title" );
		}
	}
	else
	{
		$projectid = join('_', $dataobj->dataset->base_id, $dataobj->id, $title);
		utf8::encode($projectid);
		$projectid = Digest::MD5::md5_hex( $projectid );
	}

	my $id_attr = $xml->create_element( "cfProjId" );
	$id_attr->appendChild( $xml->create_text_node( $projectid ) );

	return $id_attr if $self->{projects}->{$projectid};
	$self->{projects}->{$projectid} = 1;

	my $entity = $xml->create_element( "cfProj" );
	$entity->appendChild( $id_attr );

	if( defined $project )
	{
		if( $project->exists_and_set( "start" ) )
		{
			$entity->appendChild( $xml->create_element( "cfStartDate" ) )
				->appendChild( $xml->create_text_node( expand_date( $project->value( "start" ) ) ) );
		}
		if( $project->exists_and_set( "end" ) )
		{
			$entity->appendChild( $xml->create_element( "cfEndDate" ) )
				->appendChild( $xml->create_text_node( expand_date( $project->value( "end" ) ) ) );
		}
		if( $project->exists_and_set( "acronym" ) )
		{
			$entity->appendChild( $xml->create_element( "cfAcro" ) )
				->appendChild( $xml->create_text_node( $project->value( "acronym" ) ) );
		}
		if( $project->exists_and_set( "uri" ) )
		{
			$entity->appendChild( $xml->create_element( "cfURI" ) )
				->appendChild( $xml->create_text_node( $project->value( "uri" ) ) );
		}
		if( $project->exists_and_set( "description" ) )
		{
			$self->output_lang_attr( "cfProjAbstr",
				from => $id_attr,
				name => "cfAbstr",
				value => $project->value( "description" ) );
		}
		if( $project->exists_and_set( "keywords" ) )
		{
			$self->output_lang_attr( "cfProjKeyw",
				from => $id_attr,
				name => "cfKeyw",
				value => $project->value( "keywords" ) );
		}
	}

	my $fh = $self->open_cerif_file( "cfProj-CORE" );
	print $fh $xml->to_string( $entity, indent => 1 );
	$xml->dispose( $entity );

	$title = EPrints::Utils::is_set( $title ) ? $title : $project->value( "title" );
	$self->output_lang_attr( "cfProjTitle",
		from => $id_attr,
		name => "cfTitle",
		value => $title );

	return $id_attr;
}

sub output_lang_attr
{
	my( $self, $type, %args ) = @_;

	my $xml = $self->{session}->xml;

	my $entity = $xml->create_element( $type );
	$entity->appendChild( $args{from}->cloneNode( 1 ) );
	my $langid = $self->{session}->config( "defaultlanguage" );
	my $attr = $xml->create_element( $args{name}, cfLangCode => $langid, cfTrans => 0 );
	$attr->appendChild( $xml->create_text_node( $args{value} ) );
	$entity->appendChild( $attr );

	my $fh = $self->open_cerif_file( "$type-LANG" );
	print $fh $xml->to_string( $entity, indent => 1 );
	$xml->dispose( $entity );
}

sub output_relation
{
	my( $self, $type, %args ) = @_;

	my $xml = $self->{session}->xml;

	my $start = $args{start} || "1900-01-01T00:00:00Z";
	my $end = $args{end} || "2099-12-31T00:00:00Z";

	my $entity = $xml->create_element( $type );
	$entity->appendChild( $args{from}->cloneNode( 1 ) );
	if( defined $args{to} )
	{
		$entity->appendChild( $args{to}->cloneNode( 1 ) );
	}
	$entity->appendChild( $xml->create_element( "cfStartDate" ) )
		->appendChild( $xml->create_text_node( $start ) );
	$entity->appendChild( $xml->create_element( "cfEndDate" ) )
		->appendChild( $xml->create_text_node( $end ) );
	$entity->appendChild( $xml->create_element( "cfClassId" ) )
		->appendChild( $xml->create_text_node( $args{class} ) );
	$entity->appendChild( $xml->create_element( "cfClassSchemeId" ) )
		->appendChild( $xml->create_text_node( $args{scheme} ) );

	my $fh = $self->open_cerif_file( "$type-LINK" );
	print $fh $xml->to_string( $entity, indent => 1 );
	$xml->dispose( $entity );
}

sub output_patent
{
	my( $self, $dataobj, %opts ) = @_;

}

sub output_publication
{
	my( $self, $dataobj, %opts ) = @_;

	my $xml = $self->{session}->xml;

	my $publication = $dataobj->value( "publication" );

	my $publicationid = $publication;
	utf8::encode($publicationid);
	$publicationid = Digest::MD5::md5_hex( $publicationid );

	my $id_attr = $xml->create_element( "cfResPublId" );
	$id_attr->appendChild( $xml->create_text_node( $publicationid ) );

	# don't output multiple entries for the same publication
	return $id_attr if $self->{publications}->{$publicationid};
	$self->{publications}->{$publicationid} = 1;

	my $entity = $xml->create_element( "cfResPubl" );
	$entity->appendChild( $id_attr );

	if( $dataobj->exists_and_set( "issn" ) )
	{
		$entity->appendChild( $xml->create_element( "cfISSN" ) )
			->appendChild( $xml->create_text_node( $dataobj->value( "issn" ) ) );
	}

	if( $dataobj->exists_and_set( "isbn" ) )
	{
		$entity->appendChild( $xml->create_element( "cfISBN" ) )
			->appendChild( $xml->create_text_node( $dataobj->value( "isbn" ) ) );
	}

	my $fh = $self->open_cerif_file( "cfResPubl-RES" );
	print $fh $xml->to_string( $entity, indent => 1 );
	$xml->dispose( $entity );

	$self->output_lang_attr( "cfResPublTitle",
		from => $id_attr,
		name => "cfTitle",
		value => $publication );

	return $id_attr;
}

sub output_name
{
	my( $self, $dataobj, $value, %opts ) = @_;

	my $xml = $self->{session}->xml;

	my $name = EPrints::Utils::make_name_string( $value );
	my $nameid = join('_', $dataobj->{dataset}->base_id, $dataobj->id, $name );
	utf8::encode($nameid);
	$nameid = Digest::MD5::md5_hex( $nameid );

	my $id_attr = $xml->create_element( "cfPersId" );
	$id_attr->appendChild( $xml->create_text_node( $nameid ) );

	# don't output multiple entries for the same "name" / person
	return $id_attr if $self->{names}->{$nameid};
	$self->{names}->{$nameid} = 1;

	my $entity = $xml->create_element( "cfPers" );
	$entity->appendChild( $id_attr );

	my $fh = $self->open_cerif_file( "cfPers-CORE" );
	print $fh $xml->to_string( $entity, indent => 1 );
	$xml->dispose( $entity );

	$entity = $xml->create_element( "cfPersName" );
	$entity->appendChild( $id_attr->cloneNode( 1 ) );
	if( EPrints::Utils::is_set( $value->{family} ) )
	{
		$entity->appendChild( $xml->create_element( "cfFamilyNames" ) )
			->appendChild( $xml->create_text_node( $value->{family} ) );
	}
	if( EPrints::Utils::is_set( $value->{family} ) )
	{
		$entity->appendChild( $xml->create_element( "cfFirstNames" ) )
			->appendChild( $xml->create_text_node( $value->{given} ) );
	}

	$fh = $self->open_cerif_file( "cfPersName-ADD" );
	print $fh $xml->to_string( $entity, indent => 1 );
	$xml->dispose( $entity );

	return $id_attr;
}

sub cerif_timestamp
{
	my( $time ) = @_;

	return EPrints::Time::get_iso_timestamp( $time );
}

sub expand_date
{
	my( $date ) = @_;

	my @parts = split /\D/, $date;
	push @parts, 1 while @parts < 3;

	return sprintf("%04d-%02d-%02d", @parts[0..2] );
}

sub expand_time
{
	my( $date ) = @_;

	my @parts = split /\D/, $date;
	push @parts, 1 while @parts < 3;
	push @parts, 0 while @parts < 6;

	return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", @parts[0..5] );
}

1;

=back

=head1 SEE ALSO

CERIF 2008 http://www.eurocris.org/cerif/cerif-releases/cerif-2008/

=head1 COPYRIGHT

Copyright 2010 Tim Brody <tdb2@ecs.soton.ac.uk>, University of Southampton, UK.
