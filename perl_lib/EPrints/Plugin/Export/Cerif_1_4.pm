package EPrints::Plugin::Export::Cerif_1_4;

=head1 NAME

EPrints::Plugin::Export::Cerif_1_4 - Cerif 1.4 XML Export

=head1 DESCRIPTION

=head1 METHODS

=over 4

=cut

use EPrints::Plugin::Export::XMLFile;
use EPrints::XML::SAX::SimpleDriver;

@ISA = ( "EPrints::Plugin::Export::XMLFile" );

use constant {
	CERIF_NS => 'urn:xmlns:org:eurocris:cerif-1.4-0',
	CERIF_DATE_START => "1900-01-01T00:00:00Z",
	CERIF_DATE_END => "2099-12-31T00:00:00Z",
};

use strict;

my %GRAMMAR;

$GRAMMAR{eprint} = [
	cfResPublId => { value => sub { $_[0]->uuid } },
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
	cfTitle => { depends => [qw( title )], value => sub { $_[0]->value( 'title' ), cfLangCode => "en_GB", cfTrans => "o" } },
	cfAbstr => { depends => [qw( abstract )], value => sub { $_[0]->value( 'abstract' ), cfLangCode => "en_GB", cfTrans => "o" } },
];

our %CLASS_SCHEME_PUBLICATION_TYPES = (
	annotation => "Annotation",
	anthology => "Anthology",
	book => "Book",
	book_review => "Book Review",
	book_chapter_abstract => "Book Chapter Abstract",
	commentary => "Commentary",
	conference_proceedings => "Conference Proceedings",
	conference_proceedings_article => "Conference Proceedings Article",
	consultancy_report => "Consultancy Report",
	critical_edition => "Critical Edition",
	encyclopedia => "Encyclopedia",
	inbook => "Inbook",
	journal => "Journal",
	journal_article => "Journal Article",
	journal_article_abstract => "Journal Article Abstract",
	journal_article_review => "Journal Article Review",
	letter => "Letter",
	letter_to_editor => "Letter to Editor",
	manual => "Manual",
	monograph => "Monograph",
	news_clipping => "Newsclipping",
	other_book => "Other Book",
	phd_thesis => "PhD Thesis",
	presentation => "Presentation",
	reference_book => "Reference Book",
	short_communication => "Short Communication",
	technical_report => "Technical Report",
	technical_standard => "Technical Standard",
	textbook => "Textbook",
	working_paper => "Working Paper",
);
our %CLASS_SCHEME_PUBLICATION_STATE = (
	in_preparation => "In Preparation",
	in_press => "In Press",
	published => "Published",
	unpublished => "Unpublished",
);

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "CERIF 1.4";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint', 'list/user', 'dataobj/user' ];
	$self->{visible} = "staff";
	$self->{advertise} = 1;
	$self->{arguments} = {
			hide_related => 0,
		};

	# mappings
	$self->{map_eprint_type} = {
		article => "journal_article",
		book_section => "book_chapter_abstract",
		monograph => "monograph",
		conference_item => "conference_proceedings_article",
		book => "book",
		thesis => "phd_thesis",  # FIXME
		patent => "",
		artefact => "",
		exhibition => "",
		composition => "",
		performance => "",
		image => "",
		video => "",
		audio => "",
		dataset => "",
		experiment => "",
		teaching_resource => "",
		other => "",
	};
	$self->{map_eprint_ispublished} = {
		pub => "published",
		inpress => "in_press",
		submitted => "",
		unpub => "unpublished",
	};

	# allow calling code to override the owned_eprints_list
	$self->{owned_eprints_list} ||= sub {
		my( $user, %opts ) = @_;

		return $user->owned_eprints_list;
	};

	return $self;
}

sub writer
{
	my( $self, %opts ) = @_;

	return $self->{_writer};
}

sub _start
{
	my( $self, %opts ) = @_;

	$self->{_output} = "";
	$self->{_seen} = {};
	$self->{_sameas} = {};
	$self->{_writer} = EPrints::XML::SAX::SimpleDriver->new(
		Handler => EPrints::XML::SAX::PrettyPrint->new(
		Handler => EPrints::XML::SAX::Writer->new(
			Output => $opts{fh} ? $opts{fh} : \$self->{_output}
		) ) );

	my $writer = $self->{_writer};

	$writer->xml_decl( '1.0', 'UTF-8' );

	$writer->start_document;

	$writer->start_element( CERIF_NS, 'CERIF',
			release => '1.4',
			date => substr(EPrints::Time::get_iso_timestamp, 0, 10), # 3.2 compat
			sourceDatabase => $self->{session}->config( "base_url" ),
			'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
			'xsi:schemaLocation' => 'urn:xmlns:org:eurocris:cerif-1.4-0 http://www.eurocris.org/Uploads/Web%20pages/CERIF-1.4/CERIF_1.4_0.xsd',
		);
}

sub _end
{
	my( $self, %opts ) = @_;

	my $writer = $self->{_writer};

	$writer->end_element( CERIF_NS, 'CERIF' );

	$writer->end_document;
}

sub output_list
{
	my( $self, %opts ) = @_;

	$self->_start( %opts );

	$opts{list}->map( sub {
			$self->output_dataobj( $_[2], %opts );
		});

	$self->_end( %opts );

	return $self->{_output};
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	return if $self->{_seen}{$dataobj->internal_uri}++;

	$self->_start( %opts ) if !defined $opts{list};

	if( $dataobj->isa( "EPrints::DataObj::EPrint" ) )
	{
		$self->output_eprint( $dataobj, %opts );
	}
	elsif( $dataobj->isa( "EPrints::DataObj::User" ) )
	{
		$self->output_user( $dataobj, %opts );
	}
	else
	{
		warn "Unsupported object type ".ref($dataobj);
	}

	$self->_end( %opts ) if !defined $opts{list};

	return $self->{_output};
}

sub output_user
{
	my( $self, $user, %opts ) = @_;

	my $writer = $self->writer;

	my $name = $user->value( "name" );

	$writer->start_element( CERIF_NS, "cfPers" );
	$writer->data_element( CERIF_NS, "cfPersId", $user->uuid );
	$writer->start_element( CERIF_NS, "cfPersName" );
		$writer->data_element( CERIF_NS, "cfFamilyNames", $name->{family} );
		$writer->data_element( CERIF_NS, "cfFirstNames", $name->{given} );
	$writer->end_element( CERIF_NS, "cfPersName" );
	if( $user->is_set( "email" ) )
	{
		$writer->start_element( CERIF_NS, "cfPers_EAddr" );
		$writer->data_element( CERIF_NS, "cfClassId", "email" );
		$writer->data_element( CERIF_NS, "cfClassSchemeId", "class_scheme_eaddress_types" );
		$writer->data_element( CERIF_NS, "cfEAddrId", $user->value( "email" ) );
		$writer->end_element( CERIF_NS, "cfPers_EAddr" );
		$self->{_sameas}{user}{$user->value( "email" )} = $user->uuid;
	}
	$writer->end_element( CERIF_NS, "cfPers" );

	if( !$opts{hide_related} )
	{
		my $list = $self->param( "owned_eprints_list" )->( $user, %opts );
		$list->map(sub {
			(undef, undef, my $eprint) = @_;

			$self->output_dataobj( $eprint, %opts );
		});
	}
}

sub output_eprint
{
	my( $self, $dataobj, %opts ) = @_;

	my $writer = $self->writer;

	$writer->start_element( CERIF_NS, 'cfResPubl' );

	ENTRY: for(my $i = 0; $i < @{$GRAMMAR{eprint}}; $i += 2)
	{
		my( $name, $spec ) = @{$GRAMMAR{eprint}}[$i,$i+1];
		for(@{$spec->{depends}||[]})
		{
			next ENTRY if !$dataobj->exists_and_set( $_ );
		}
		$writer->data_element( CERIF_NS, $name, $spec->{value}( $dataobj ) );
	}

	my $type = $dataobj->value( "type" );

	if( my $classId = $self->param( "map_eprint_type" )->{$type} )
	{
		$self->cf_class( $writer, 'cfResPubl_Class',
				classId => $classId,
				classSchemeId => 'class_scheme_publication_types',
			);
	}

	my $ispublished = $dataobj->exists_and_set( "ispublished" ) ? $dataobj->value( "ispublished" ) : "";
	if( my $classId = $self->param( "map_eprint_ispublished" )->{$ispublished} )
	{
		$self->cf_class( $writer, 'cfResPubl_Class',
				classId => $classId,
				classSchemeId => 'class_scheme_publication_state',
			);
	}

	my @publications;
	my @organisations;

	if( $dataobj->exists_and_set( "publication" ) || $dataobj->exists_and_set( "issn" ) )
	{
		my $id = $dataobj->uuid(
			$dataobj->exists_and_set( "issn" ) ?
				"issn:".$dataobj->value( "issn" ) :
				"publication:".$dataobj->value( "publication" )
			);
		$writer->start_element( CERIF_NS, "cfResPubl_ResPubl" );
		$writer->data_element( CERIF_NS, "cfResPublId2", $id );
		$self->cf_class_fraction( $writer,
				classId => "part",
				classSchemeId => "class_scheme_publication_publication_roles",
			);
		$writer->end_element( CERIF_NS, "cfResPubl_ResPubl" );
		# work out the class of the related publication entry
		my $ptype = "journal";
		if( $type eq "book_section" )
		{
			$ptype = "book";
		}
		push @publications, {
				_id => $id,
				_class => [{
					classid => $ptype,
					classschemeid => "class_scheme_publication_types",
				}],
				title => $dataobj->exists_and_set( "publication" ) ? $dataobj->value( "publication" ) : undef,
				issn => $dataobj->exists_and_set( "issn" ) ? $dataobj->value( "issn" ) : undef,
			};
	}

	if( $dataobj->exists_and_set( "publisher" ) )
	{
		my $id = $dataobj->uuid( "publisher:".$dataobj->value( "publisher" ) );
		$writer->start_element( CERIF_NS, "cfOrgUnit_ResPubl" );
		$writer->data_element( CERIF_NS, "cfOrgUnitId", $id );
		$self->cf_class_fraction( $writer,
				classId => "publisher_institution",
				classSchemeId => "class_scheme_cerif_organisation_publication_roles",
			);
		$writer->end_element( CERIF_NS, "cfOrgUnit_ResPubl" );
		push @organisations, {
				_id => $id,
				name => $dataobj->value( "publisher" ),
			};
	}

	if( $dataobj->exists_and_set( "refereed" ) )
	{
		$self->cf_class( $writer, 'cfResPubl_Class',
				classId => {TRUE => "yes", FALSE => "no"}->{$dataobj->value( "refereed" )},
				classSchemeId => "class_scheme_publication_peer-reviewed",
			);
	}

	my $owner = $dataobj->get_user;
	if( defined $owner )
	{
		$writer->start_element( CERIF_NS, "cfPers_ResPubl" );
		$writer->data_element( CERIF_NS, "cfPersId", $owner->uuid );
		$self->cf_class_fraction( $writer,
				classId => "creator",
				classSchemeId => "class_scheme_person_publication_roles",
			);
		$writer->end_element( CERIF_NS, "cfPers_ResPubl" );
	}

	if( $dataobj->exists_and_set( "projects" ) )
	{
		foreach my $project (@{$dataobj->value( "projects" )})
		{
			my $id = $dataobj->uuid("project:".$project);
			$writer->start_element( CERIF_NS, "cfProj_ResPubl" );
			$writer->data_element( CERIF_NS, "cfProjId", $id );
#			$self->cf_class_fraction( $writer,
#					classId => "funder",
#					classSchemeId => "class_scheme_publication_funding_roles",
#				);
			$writer->end_element( CERIF_NS, "cfProj_ResPubl" );
		}
	}

	my @fundids;

	if( $dataobj->exists_and_set( "funding_funder_code" ) )
	{
		foreach my $code (@{$dataobj->value( "funding_funder_code" )})
		{
			my $id = $dataobj->uuid("funding_funder_code:".$code);
			$writer->start_element( CERIF_NS, "cfProj_ResPubl" );
			$writer->data_element( CERIF_NS, "cjProjId", $id );
			$writer->end_element( CERIF_NS,  "cfProj_ResPubl" );
			push @fundids, { projid => $id, code => $code };
		}
	}

	my @people;
	for(qw( creators editors ))
	{
		next if !$dataobj->exists_and_set( "creators" );
		my $i = 1;
		foreach my $creator (@{$dataobj->value( $_ )})
		{
			my $_value = $creator->{id} || EPrints::Utils::make_name_string( $creator->{name} );
			my $id = $self->{_sameas}{user}{$_value} || $dataobj->uuid( $_value );
			push @people, {
					%$creator,
					_id => $id,
				};
			$writer->start_element( CERIF_NS, "cfPers_ResPubl" );
			$writer->data_element( CERIF_NS, "cfPersId", $id );
			$self->cf_class_fraction( $writer,
					classId => {creators => "author_numbered", editors => "editor"}->{$_},
					classSchemeId => "class_scheme_person_publication_roles",
					fraction => $i,
				);
			$writer->end_element( CERIF_NS, "cfPers_ResPubl" );
			++$i;
		}
	}

	if( $dataobj->exists_and_set( "id_number" ) )
	{
		$self->cf_class( $writer, "cfResPubl_Class",
				classId => $dataobj->value( "id_number" ),
				classSchemeId => "class_scheme_publication_alternateids_doi",
			);
	}

	$writer->end_element( CERIF_NS, 'cfResPubl' );

	if( defined $owner && !$opts{hide_related} )
	{
		$self->output_dataobj( $owner, %opts, hide_related => 1 );
	}

	foreach my $pers (@people)
	{
		$self->cf_pers( $writer, $pers );
	}

	foreach my $publ (@publications)
	{
		$writer->start_element( CERIF_NS, "cfResPubl" );
		$writer->data_element( CERIF_NS, "cfResPublId", $publ->{_id} );
		$writer->data_element( CERIF_NS, "cfISSN", $publ->{issn} ) if $publ->{issn};
		$writer->data_element( CERIF_NS, "cfTitle", $publ->{title},
				cfLangCode => "en_GB",
				cfTrans => "o",
			) if $publ->{title};
		foreach my $class (@{$publ->{_class} || []})
		{
			$self->cf_class( $writer, 'cfResPubl_Class',
					classId => $class->{classid},
					classSchemeId => $class->{classschemeid},
				);
		}
		$writer->end_element( CERIF_NS, "cfResPubl" );
	}

	foreach my $org (@organisations)
	{
		$writer->start_element( CERIF_NS, "cfOrgUnit" );
		$writer->data_element( CERIF_NS, "cfOrgUnitId", $org->{_id} );
		$writer->data_element( CERIF_NS, "cfName", $org->{name},
				cfLangCode => "en_GB",
				cfTrans => "o",
			);
		$writer->end_element( CERIF_NS, "cfOrgUnit" );
	}

	if( $dataobj->exists_and_set( "projects" ) )
	{
		foreach my $project (@{$dataobj->value( "projects" )})
		{
			my $projid = $dataobj->uuid("project:".$project);

			$writer->start_element( CERIF_NS, "cfResProj" );
			$writer->data_element( CERIF_NS, "cfProjId", $projid );
			$writer->data_element( CERIF_NS, "cfTitle", $project,
					cfLangCode => "en_GB",
					cfTrans => "o",
				);
			$writer->end_element( CERIF_NS, "cfResProj" );
		}
	}

	for(@fundids)
	{
		$writer->start_element( CERIF_NS, "cfProj" );
		$writer->data_element( CERIF_NS, "cfProjId", $_->{projid} );
		$writer->start_element( CERIF_NS, "cfProj_Fund" );
		$writer->data_element( CERIF_NS, "cfFundId", $_->{projid} );
		$writer->end_element( CERIF_NS, "cfProj_Fund" );
		$writer->end_element( CERIF_NS, "cfProj" );

		$writer->start_element( CERIF_NS, "cfFund" );
		$writer->data_element( CERIF_NS, "cfFundId", $_->{projid} );
		$writer->data_element( CERIF_NS, "cfAcro", $_->{code} );
		$writer->end_element( CERIF_NS, "cfFund" );
	}
}

sub cf_pers
{
	my( $self, $writer, $pers ) = @_;

	$writer->start_element( CERIF_NS, "cfPers" );
	$writer->data_element( CERIF_NS, "cfPersId", $pers->{_id} );
	$writer->start_element( CERIF_NS, "cfPersName" );
		$writer->data_element( CERIF_NS, "cfFamilyNames", $pers->{name}->{family} );
		$writer->data_element( CERIF_NS, "cfFirstNames", $pers->{name}->{given} );
	$writer->end_element( CERIF_NS, "cfPersName" );
	if( $pers->{id} && $pers->{id} =~ /^(?:mailto:)?([^\@]+\@[^\@]+)$/ )
	{
		$writer->start_element( CERIF_NS, "cfPers_EAddr" );
		$writer->data_element( CERIF_NS, "cfEAddrId", $1 );
		$writer->end_element( CERIF_NS, "cfPers_EAddr" );
	}
	$writer->end_element( CERIF_NS, "cfPers" );
}

sub cf_class
{
	my( $self, $writer, $name, %parts ) = @_;

	$writer->start_element( CERIF_NS, $name );

	$self->cf_class_fraction( $writer, %parts );

	$writer->end_element( CERIF_NS, $name );
}

sub cf_class_fraction
{
	my( $self, $writer, %parts ) = @_;

#	$parts{startDate} ||= CERIF_DATE_START;
#	$parts{endDate} ||= CERIF_DATE_END;
#	$parts{fraction} = '1.00' if !defined $parts{fraction};

	$writer->data_element( CERIF_NS, "cfClassId", $parts{classId} );
	$writer->data_element( CERIF_NS, "cfClassSchemeId", $parts{classSchemeId} );
	$writer->data_element( CERIF_NS, "cfStartDate", $parts{startDate} ) if defined $parts{startDate};
	$writer->data_element( CERIF_NS, "cfEndDate", $parts{endDate} ) if defined $parts{endDate};
	$writer->data_element( CERIF_NS, "cfFraction", $parts{fraction} ) if defined $parts{fraction};
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
