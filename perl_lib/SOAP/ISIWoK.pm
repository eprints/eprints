package SOAP::ISIWoK;

use SOAP::Lite on_action => sub {};
use HTTP::Cookies;
use MIME::Base64;
#use SOAP::Lite +'trace';

use 5.008000;
use strict;
use warnings;

our @ISA = qw();

our $VERSION = '3.00';

use constant {
	AUTHENTICATE_ENDPOINT => 'http://search.webofknowledge.com/esti/wokmws/ws/WOKMWSAuthenticate',
	AUTHENTICATE_NS => 'http://auth.cxf.wokmws.thomsonreuters.com',

	WOKSEARCH_ENDPOINT => 'http://search.webofknowledge.com/esti/wokmws/ws/WokSearch',
	WOKSEARCH_LITE_ENDPOINT => 'http://search.webofknowledge.com/esti/wokmws/ws/WokSearchLite',

	WOKSEARCH_NS => 'http://woksearch.cxf.wokmws.thomsonreuters.com',

	WOKSEARCH_SERVICE_TYPE => 'woksearch',
	WOKSEARCH_LITE_SERVICE_TYPE => 'woksearchlite',
};

use constant {
	QUERY_LANGUAGE => 'en',
};

=head1 NAME

SOAP::ISIWoK - interogate the ISI WoS database

=head1 SYNOPSIS

  use SOAP::ISIWoK;

  $wos = SOAP::ISIWoK->new;
  
  $som = $wos->authenticate;
  die $som->faultstring if $som->fault;

  $som = $wos->search('AU = (Brody)');

=head1 DESCRIPTION

Search and retrieve records from the Thomson Reuters ISI Web of Knowledge
database.

This module is NOT backwards compatible with SOAP::ISIWoK 1.xx (deprecated WoK
API). Significant changes:

  - you must now authenticate with WoK to get a session id
  - methods now return SOAP::Lite objects, use your favourite XML parser to
	parse $som->result->{records} or
  - throw an error on $som->fault

=head2 Editions

Select which editions to query. Some editions may not be available, depending on your WoS subscription.

=over 4

=item SCI

Science Citation Index Expanded

=item SSCI

Social Sciences Citation Index

=item AHCI

Arts & Humanities Citation Index

=item ISTP

Conference Proceedings Citation Index - Science

=item ISSHP

Conference Proceedings Citation Index - Social Sciences

=item IC

Index Chemicus

=item CCR

Current Chemical Reactions

=item BSCI

Book Citation Index - Science

=item BHCI

Book Citation Index - Social Sciences and Humanities

=back

=head2 Sort Fields

Sort results by the given field. Only relevance and times-cited may be reverse sorted, by specifying '-' in front of the sort name.

=over 4

=item AU

Author

=item CF

Conference Title

=item CG

Page

=item CW

Source

=item CV

Volume

=item CY

Publication Year

=item LC

Local Times Cited

=item LD

Load Date

=item PG

Page

=item PY

Publication Year

=item RS / -RS

Relevance

=item SO

Source

=item TC / -TC

Times Cited

=item VL

Volume

=back


=head2 Required Fields

Only return records that contain the given field(s). For example:

	fields => [qw(
		address_spec
		category_info
	)],

is logically equivalent to only showing records that contain:

	(Publisher City OR Publisher Address)
		AND
	(Web of Science Category OR Subject Category)

=over 4

=item pub_info

Publication Type (J=Journal; B=Book; S=Series)

=item names

Authors, Book Authors, Group Authors, Book Group Authors, ResearcherID Number, Editors, Publisher

=item full_name

Author Full Name

=item titles

Publication Name, Book Series Title, Book Series Subtitle, 29-Character Source Abbreviation, ISO Source Abbreviation

=item language

Language

=item doctypes

Document Type

=item conf_title

Conference Title

=item conf_date

Conference Date

=item conf_host

Conference Host

=item conf_locations

Conference Location

=item sponsors

Conference Sponsors

=item keywords

Author Keywords

=item keywords_plus

Keywords Plus

=item abstract

Abstract

=item addresses

Author Address

=item reprint_contact

Reprint Address

=item email_addr

E-mail Address

=item grant

Funding Agency and Grant Number

=item fund_text

Funding Text

=item refs

Cited Reference Count

=item address_spec

Publisher City, Publisher Address

=item category_info

Web of Science Category, Subject Category

=item identifiers

International Standard Serial Number (ISSN), International Standard Book Number (ISBN), Book Digital Object Identifier (DOI), Article Number, Digital Object Identifier (DOI)

=item pub_info

Publication Date, Year Published, Volume, Issue, Part Number, Supplement, Special Issue

=item page

Beginning Page, Ending Page, Page Count

=item book_chapters

Chapter Count in a Book

=item ids

Document Delivery Number

=item UID

Accession Number

=back


=head2 Options

	options => {
		RecordIDs => 'On',
	},

=over 4

=item RecordIDs

	On
	Off

Return the UIDs of records as SOAP data.

=back

=head1 METHODS

=over 4

=cut

# Preloaded methods go here.

=item $wos = SOAP::ISIWoK->new( [ OPTIONS ] )

Options:

=over 4

=item database = WOK

Database to search (WOK = all database).

=item collections = { WOS => [] }

	BIOABS, BCI, BIOSIS, CABI, CSCD, CCC, DIIDW, FSTA, INSPEC, MEDLINE, WOS,
	ZOOREC

The key is the Collection to search (WOS = Web of Science) and the value is a list of editions within that collection.

See Web Service documentation for the available editions, otherwise an empty array will search all editions that you are subscribed to.

=back

=cut

sub new
{
	my ($class, %self) = @_;

	$self{cookie_jar} ||= HTTP::Cookies->new(ignore_discard => 1);
	$self{endpoint} ||= WOKSEARCH_ENDPOINT;
	$self{service_type} ||= WOKSEARCH_SERVICE_TYPE;
	$self{database} ||= 'WOK';
	$self{collections} ||= { WOS => [] };

	my $self = bless \%self, $class;

	return $self;
}

sub DESTROY
{
	shift->closeSession;
}

# this suppreses the usual xsi:nil="true" attribute, which WoS rejects
sub SOAP::Serializer::as_nonil
{
	my ($self, $value, $name, $type, $attr) = @_;
	delete $attr->{'xsi:nil'};
	return [ $name, $attr, $value ];
}

=item $som = $wos->authenticate([$username, $password])

	die $som->faultstring if $som->fault;
	print "Session ID: ".$som->result;

Get a WoS session ID.

=cut

sub authenticate
{
	my ($self, $username, $password) = @_;

	my $soap = SOAP::Lite->new(
		proxy => AUTHENTICATE_ENDPOINT,
	);

	$soap->transport->cookie_jar($self->{cookie_jar});

	if (defined $username) {
		$password = '' if !defined $password;
		$soap->transport->http_request->header(
			Authorization => "Basic ".MIME::Base64::encode_base64("$username:$password")
		);
	}

	my $som = $soap->call( SOAP::Data->new(
			type => 'nonil', # custom type
			name => 'authenticate',
			prefix => '',
			uri => AUTHENTICATE_NS,
		));

	$self->{sid} = $som->result if !$som->fault;

	return $som;
}

=item $som = $wos->closeSession()

Explicitly close the session with WoS. Otherwise is called when this object goes out of scope.

=cut

sub closeSession
{
	my ($self) = @_;

	return if !$self->{sid};

	my $soap = SOAP::Lite->new(
		proxy => AUTHENTICATE_ENDPOINT,
	);

	$soap->transport->cookie_jar($self->{cookie_jar});

	my $som = $soap->call( SOAP::Data->new(
			type => 'nonil', # custom type
			name => 'closeSession',
			prefix => '',
			uri => AUTHENTICATE_NS,
		));

	undef $self->{sid};

	return $som;
}

sub _retrieveParameters
{
	my ($self, %opts) = @_;

	$opts{offset} = 0 if !defined $opts{offset};
	$opts{max} = 10 if !defined $opts{max};
	$opts{fields} = [] if !exists $opts{fields};
	$opts{options} = {} if !exists $opts{options};

	my @rparams = (
		SOAP::Data->name( firstRecord => $opts{offset}+1 ),
		SOAP::Data->name( count => $opts{max} ),
	);

	if ($opts{sort}) {
		my $sort = $opts{sort};
		my $order = $sort =~ s/^-// ? 'D' : 'A';
		push @rparams, SOAP::Data->name( sortField => \SOAP::Data->value(
				SOAP::Data->name( name => $sort ),
				SOAP::Data->name( sort => $order ),
			) );
	}

	if ($opts{fields} && @{$opts{fields}}) {
		push @rparams, SOAP::Data->name( viewField => \SOAP::Data->value(
			SOAP::Data->name( collectionName => 'WOS' ), # WOS only valid collectionName ???
			map {
				SOAP::Data->name( fieldName => $_ )
			} @{$opts{fields}}
		) );
	}

	foreach my $key (sort keys %{$opts{options}})
	{
		push @rparams, SOAP::Data->name( option => [
				SOAP::Data->name(key => $key),
				SOAP::Data->name(value => $opts{options}{$key}),
			]);
	}

	return @rparams;
}

sub soap
{
	my ($self) = @_;

	my $soap = SOAP::Lite->new(
		proxy => $self->{endpoint},
		autotype => 0,
	);

	$soap->transport->cookie_jar($self->{cookie_jar});

	return $soap;
}

=item $som = $wos->citedReferences($uid [, OPTIONS ])

=cut

sub citedReferences
{
	my ($self, $q, %opts) = @_;

	my $service = $self->{service_type};

	my $som = $self->soap->call(
		SOAP::Data->new(
			name => "$service:citedReferences",
			attr => {
				"xmlns:$service" => "http://$service.v3.wokmws.thomsonreuters.com",
			},
		),
		SOAP::Data->name(databaseId => $self->{database}),
		SOAP::Data->name(uid => $q),
		SOAP::Data->name(queryLanguage => QUERY_LANGUAGE),
		SOAP::Data->name(retrieveParameters => \SOAP::Data->value($self->_retrieveParameters(%opts))),
	);

	return _fix_records($som);
}

=item $som = $wos->citedReferencesRetrieve($queryId [, OPTIONS ])

=cut

sub citedReferencesRetrieve
{
	my ($self, $q, %opts) = @_;

	my $service = $self->{service_type};

	my $som = $self->soap->call(
		SOAP::Data->new(
			name => "$service:citedReferencesRetrieve",
			attr => {
				"xmlns:$service" => "http://$service.v3.wokmws.thomsonreuters.com",
			},
		),
		SOAP::Data->name(queryId => $q),
		SOAP::Data->name(retrieveParameters => \SOAP::Data->value($self->_retrieveParameters(%opts))),
	);

	return _fix_records($som);
}

sub _related
{
	my ($self, $method, $q, %opts) = @_;

	my $service = $self->{service_type};

	my @qparams;

	push @qparams, SOAP::Data->name(databaseId => $self->{database});

	push @qparams, SOAP::Data->name(uid => $q);

	foreach my $collection (sort keys %{$self->{collections}}) {
		foreach my $edition (sort @{$self->{collections}{$collection}}) {
			push @qparams, SOAP::Data->name(editions => \SOAP::Data->value(
				SOAP::Data->name(collection => $collection),
				SOAP::Data->name(edition => $edition),
			) );
		}
	}

	if ($opts{begin} || $opts{end}) {
		push @qparams, SOAP::Data->name( timeSpan => \SOAP::Data->value(
			SOAP::Data->name(begin => $opts{begin}),
			SOAP::Data->name(end => $opts{end}),
		) );
	}

	push @qparams, SOAP::Data->name(queryLanguage => QUERY_LANGUAGE);

	my $som = $self->soap->call(
		SOAP::Data->new(
			name => "$service:$method",
			attr => {
				"xmlns:$service" => "http://$service.v3.wokmws.thomsonreuters.com",
			},
		),
		@qparams,
		SOAP::Data->name(retrieveParameters => \SOAP::Data->value($self->_retrieveParameters(%opts))),
	);

	return _fix_records($som);
}

=item $som = $wos->citingArticles($uid [, OPTIONS ])

=cut

sub citingArticles
{
	my ($self, $q, %opts) = @_;

	return $self->_related('citingArticles', $q, %opts);
}

=item $som = $wos->relatedRecords($uid [, OPTIONS ])

=cut

sub relatedRecords
{
	my ($self, $q, %opts) = @_;

	return $self->_related('relatedRecords', $q, %opts);
}

=item $som = $wos->retrieve($queryId [, OPTIONS ])

=cut

sub retrieve
{
	my ($self, $q, %opts) = @_;

	$opts{sort} = '-RS' if !exists $opts{sort};

	my $service = $self->{service_type};

	my $som = $self->soap->call(
		SOAP::Data->new(
			name => "$service:retrieve",
			attr => {
				"xmlns:$service" => "http://$service.v3.wokmws.thomsonreuters.com",
			},
		),
		SOAP::Data->name(queryId => $q),
		SOAP::Data->name(retrieveParameters => \SOAP::Data->value($self->_retrieveParameters(%opts))),
	);

	return _fix_records($som);
}

=item $som = $wos->retrieveById(UIDs [, OPTIONS])

UIDs is an array ref of uids.

=cut

sub retrieveById
{
	my ($self, $q, %opts) = @_;

	$q = [$q] if ref($q) ne "ARRAY";

	my $service = $self->{service_type};

	my @qparams;

	push @qparams, SOAP::Data->name(databaseId => $self->{database});

	push @qparams, map {
			SOAP::Data->name(uid => $_)
		} @$q;

	push @qparams, SOAP::Data->name(queryLanguage => QUERY_LANGUAGE);

	my $som = $self->soap->call(
		SOAP::Data->new(
			name => "$service:retrieveById",
			attr => {
				"xmlns:$service" => "http://$service.v3.wokmws.thomsonreuters.com",
			},
		),
		@qparams,
		SOAP::Data->name(retrieveParameters => \SOAP::Data->value($self->_retrieveParameters(%opts))),
	);

	return _fix_records($som);
}

=item $som = $wos->search($query [, OPTIONS])

Options:

=over 4

=item begin - YYYY-MM-DD

=item end - YYYY-MM-DD

=item offset = 0

=item max = 10

=item sort = -RS

See L</Sort Fields>.

=item fields = []

See L</Required Fields>.

=item options = {}

See L</Options>

=back

=cut

sub search
{
	my ($self, $q, %opts) = @_;

	$opts{sort} = '-RS' if !exists $opts{sort};

	my @qparams;

	push @qparams, SOAP::Data->name(databaseId => $self->{database});

	push @qparams, SOAP::Data->name(userQuery => $q);

	foreach my $collection (sort keys %{$self->{collections}}) {
		foreach my $edition (sort @{$self->{collections}{$collection}}) {
			push @qparams, SOAP::Data->name(editions => \SOAP::Data->value(
				SOAP::Data->name(collection => $collection),
				SOAP::Data->name(edition => $edition),
			) );
		}
	}

	if ($opts{begin} || $opts{end}) {
		push @qparams, SOAP::Data->name( timeSpan => \SOAP::Data->value(
			SOAP::Data->name(begin => $opts{begin}),
			SOAP::Data->name(end => $opts{end}),
		) );
	}

	push @qparams, SOAP::Data->name(queryLanguage => QUERY_LANGUAGE);

	my $service = $self->{service_type};

	my $som = $self->soap->call(
		SOAP::Data->new(
			name => "$service:search",
			attr => {
				"xmlns:$service" => "http://$service.v3.wokmws.thomsonreuters.com",
			},
		),
		SOAP::Data->name(queryParameters => \SOAP::Data->value(@qparams)),
		SOAP::Data->name(retrieveParameters => \SOAP::Data->value($self->_retrieveParameters(%opts))),
	);

	return _fix_records($som);
}

sub _fix_records
{
	my ($som) = @_;

	# <REC r_id_disclaimer=""> attribute is sometimes repeated, so lets fix
	# that for the consuming user
	if (defined $som->result && exists $som->result->{records}) {
		$som->result->{records} =~ s/r_id_disclaimer="[^"]+"//g;
	}

	return $som;
}

1;
__END__

=back

=head1 SEE ALSO

L<SOAP::Lite>

=head1 AUTHOR

Tim Brody, E<lt>tdb2@ecs.soton.ac.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Tim Brody, University of Southampton (UK)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
