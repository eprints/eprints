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

our %cfPublicationTypes = (
	article => "Journal Article",
	book => "Book",
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

	return $self;
}

sub writer
{
	my( $self, %opts ) = @_;

	return $self->{_writer} ||= EPrints::XML::SAX::SimpleDriver->new(
		Handler => EPrints::XML::SAX::PrettyPrint->new(
		Handler => EPrints::XML::SAX::Writer->new(
			Output => $opts{fh} ? $opts{fh} : $self->{_output}
		) ) );
}

sub output_list
{
	my( $self, %opts ) = @_;

	my $r = "";

	local $self->{_writer};
	local $self->{_output} = \$r;
	local $self->{_seen} = {};
	local $self->{_sameas} = {};
	my $writer = $self->writer( %opts );

	$writer->xml_decl( '1.0', 'UTF-8' );

	$writer->start_document;

	$writer->start_element( CERIF_NS, 'CERIF',
			release => '1.4',
			date => EPrints::Time::iso_date,
			sourceDatabase => $self->{session}->config( "base_url" ),
			'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
			'xsi:schemaLocation' => 'urn:xmlns:org:eurocris:cerif-1.4-0 http://www.eurocris.org/Uploads/Web%20pages/CERIF-1.4/CERIF_1.4_0.xsd',
		);

	$opts{list}->map( sub {
			$self->output_dataobj( $_[2], %opts );
		});

	$writer->end_element( CERIF_NS, 'CERIF' );

	$writer->end_document;

	return $r;
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	return if $self->{_seen}{$dataobj->internal_uri}++;

	if( $dataobj->isa( "EPrints::DataObj::EPrint" ) )
	{
		return $self->output_eprint( $dataobj, %opts );
	}
	elsif( $dataobj->isa( "EPrints::DataObj::User" ) )
	{
		return $self->output_user( $dataobj, %opts );
	}
	else
	{
		warn "Unsupported object type ".ref($dataobj);
		return;
	}
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
		$writer->data_element( CERIF_NS, "cfEAddrId", $user->value( "email" ) );
		$writer->end_element( CERIF_NS, "cfPers_EAddr" );
		$self->{_sameas}{user}{$user->value( "email" )} = $user->uuid;
	}
	$writer->end_element( CERIF_NS, "cfPers" );

	if( !$opts{hide_related} )
	{
		$user->owned_eprints_list->map(sub {
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

	$self->cf_class( $writer, 'cfResPubl_Class',
			classId => $cfPublicationTypes{$type} || "?$type?",
			classSchemeId => 'class_scheme_cerif_publication_types',
		);

	my @publications;

	if( $type eq "article" )
	{
		if( $dataobj->exists_and_set( "publication" ) || $dataobj->exists_and_set( "issn" ) )
		{
			my $id = $dataobj->uuid(
				$dataobj->exists_and_set( "issn" ) ?
					$dataobj->value( "issn" ) :
					$dataobj->value( "publication" )
				);
			$writer->start_element( CERIF_NS, "cfResPubl_ResPubl" );
			$writer->data_element( CERIF_NS, "cfResPublId2", $id );
			$self->cf_class_fraction( $writer,
					classId => "?part-of?",
					classSchemeId => "?cfrespubl_respubl?",
				);
			$writer->end_element( CERIF_NS, "cfResPubl_ResPubl" );
			push @publications, {
					_id => $id,
					title => $dataobj->exists_and_set( "publication" ) ? $dataobj->value( "publication" ) : undef,
					issn => $dataobj->exists_and_set( "issn" ) ? $dataobj->value( "issn" ) : undef,
				};
		}
	}

	if( $dataobj->exists_and_set( "project" ) )
	{
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
		$self->cf_class( $writer, "cfClass",
				classId => $dataobj->value( "id_number" ),
				classSchemeId => "class_scheme_publication_alternateids_doi",
			);
	}

	$writer->end_element( CERIF_NS, 'cfResPubl' );

	foreach my $pers (@people)
	{
		$self->cf_pers( $writer, $pers );
	}

	foreach my $publ (@publications)
	{
		$writer->start_element( CERIF_NS, "cfResPubl" );
		$writer->data_element( CERIF_NS, "cfResPublId", $publ->{_id} );
		$writer->data_element( CERIF_NS, "cfISSN", $publ->{issn} );
		$writer->data_element( CERIF_NS, "cfTitle", $publ->{title},
				cfLangCode => "en_GB",
				cfTrans => "o",
			);
		$writer->end_element( CERIF_NS, "cfResPubl" );
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

	$parts{startDate} ||= CERIF_DATE_START;
	$parts{endDate} ||= CERIF_DATE_END;
	$parts{fraction} = '1.00' if !defined $parts{fraction};

	$writer->data_element( CERIF_NS, "cfClassId", $parts{classId} );
	$writer->data_element( CERIF_NS, "cfClassSchemeId", $parts{classSchemeId} );
	$writer->data_element( CERIF_NS, "cfStartDate", $parts{startDate} );
	$writer->data_element( CERIF_NS, "cfEndDate", $parts{endDate} );
	$writer->data_element( CERIF_NS, "cfFraction", $parts{fraction} );
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
