package URI::OpenURL;

=pod

=head1 NAME

URI::OpenURL - Parse and construct OpenURL's (NISO Z39.88-2004)

=head1 DESCRIPTION

This module provides an implementation of OpenURLs encoded as URIs (Key/Encoded-Value (KEV) Format), this forms only a part of the OpenURL spec. It does not check that OpenURLs constructed are sane according to the OpenURL specification (to a large extent sanity will depend on the community of use).

From the implementation guidelines:

The description of a referenced resource, and the descriptions of the associated resources that comprise the context of the reference, bundled together are called a ContextObject. It is a ContextObject that is transported when a user makes a request by clicking a link. A KEV OpenURL may contain only one ContextObject.

The ContextObject may contain up to six Entities. One of these, the Referent, conveys information about the referenced item. It must always be included in a ContextObject. The other five entities - ReferringEntity, Requester, Resolver, ServiceType and Referrer - hold information about the context of the reference and are optional.

=head1 OpenURL

http://library.caltech.edu/openurl/

From the implementation guidelines:

The OpenURL Framework for Context-Sensitive Services Standard provides a means of describing a referenced resource along with a description of the context of the reference.  Additionally it defines methods of transporting these descriptions between networked systems. It is anticipated that it will be used to request services pertaining to the referenced resource and appropriate for the requester.

The OpenURL Framework is very general and has the potential to be used in many application domains and by many communities. Concrete instantiations of the various core components within the framework are defined within the OpenURL Registry. The OpenURL Framework is currently a .draft standard for ballot.. During the ballot and public review period, the content of the Registry will be static and has been pre-defined by the NISO AX Committee. There is also an experimental registry where components under development are held. In the future it will be possible to register further items.

There are currently two formats for ContextObjects defined in the OpenURL Framework, Key/Encoded-Value and XML. This document provides implementation guidelines for the Key/Encoded-Value Format, concentrating mainly, but not exclusively, on components from the San Antonio Level 1 Community Profile (SAP1).

=head1 SYNOPSIS

	use URI::OpenURL;

	# Construct an OpenURL
	# This is the first example from the implementation specs,
	# with additional resolver and serviceType entities.
	print URI::OpenURL->new('http://other.service/cgi/openURL'
		)->referrer(
			id => 'info:sid/my.service',
		)->requester(
			id => 'mailto:john@invalid.domain',
		)->resolver(
			id => 'info:sid/other.service',
		)->serviceType()->scholarlyService(
			fulltext => 'yes',
		)->referringEntity(id => 'info:doi/10.1045/march2001-vandesompel')->journal(
			genre => 'article',
			aulast => 'Van de Sompel',
			aufirst => 'Herbert',
			issn => '1082-9873',
			volume => '7',
			issue => '3',
			date => '2001',
			atitle => 'Open Linking in the Scholarly Information Environment using the OpenURL Framework',
		)->referent(id => 'info:doi/10.1045/july99-caplan')->journal(
			genre => 'article',
			aulast => 'Caplan',
			aufirst => 'Priscilla',
			issn => '1082-9873',
			volume => '5',
			issue => '7/8',
			date => '1999',
			atitle => 'Reference Linking for Journal Articles',
		)->as_string();

	# Parsing (wrappers for $uri->query_form())
	my $uri = URI::OpenURL->new('http://a.OpenURL/?url_ver=Z39.88-2004&...');
	my @referent = $uri->referent->metadata();
	print join(',',@referent), "\n";
	# This could lose data if there is more than one id
	my %ds = $uri->referent->descriptors();
	if( !exists($ds{val_fmt}) ) {
		warn "No by-value metadata for referent in OpenURL";
	} elsif($ds{val_fmt} eq 'info:ofi/fmt:kev:mtx:journal') {
		my %md = $uri->referent->metadata();
		print ($md{genre} || 'Unknown journal article genre'), "\n";
	}
	
	if( $uri->referent->val_fmt() eq 'info:ofi/fmt:kev:mtx:journal' ) {
		print "The referent is a journal article.\n";
	}

=head1 METHODS

=over 4

=cut

use vars qw( $VERSION );

$VERSION = '0.4.6';

use strict;
use URI::Escape;
use Carp;
use POSIX qw/ strftime /;

require URI;
require URI::_server;
use vars qw( @ISA );
@ISA = qw( URI::_server );

=pod

=item $uri = URI::OpenURL->new([$url])

Create a new URI::OpenURL object and optionally initialize with $url. If $url does not contain a query component (...?key=value) the object will be initialized to a valid contextobject, but without any entities.

If you don't want the context object version and encoding specify url_ver e.g.

	use URI::OpenURL;
	my $uri = URI::OpenURL->new(
		'http://myresolver.com/openURL?url_ver=Z39.88-2004'
	);

=cut

sub new {
	_init(@_);
}

sub _init {
	my $self = shift->SUPER::_init(@_);
	$self->query_form(
		url_ver => 'Z39.88-2004',
	) unless $self->query();
	$self;
}

=pod

=item $uri = URI::OpenURL->new_from_hybrid($uri)

Create a new URI::OpenURL object from a hybrid OpenURL (version 0.1 and/or 1.0 KEVS). Use this to parse a version 0.1 (SFX) style OpenURL.

=cut

sub new_from_hybrid
{
	my ($class,$uri) = @_;
	$class = ref($class) || $class;
	my $self = $class->new($uri);
	# If we already have a 1.0 OpenURL just return a canonical 1.0
	my @KEVS = $self->query_form;
	my %kevs = @KEVS;
	my $genre = $kevs{'genre'} || 'article';
	if( $kevs{url_ver} && $kevs{url_ver} eq 'Z39.88-2004' ) {
		return $self->canonical();
	}
	# Initialize the OpenURL (url_ver etc.)
	$self->query('');
	$self = $class->new($self);
	# Tidy up the 0.1 keys
	for(my $i = 0; $i < @KEVS;) {
		if( $KEVS[$i] eq 'sid' ) {
			$self->referrer->id('info:sid/'.$KEVS[$i+1]);
			splice(@KEVS,$i,2);
		} elsif( $KEVS[$i] eq 'id' ) {
			if( $KEVS[$i+1] =~ s/(^doi|pmid|bibcode):// ) {
				$self->referent->id("info:$1/".$KEVS[$i+1]);
			} else {
				$self->referent->id($KEVS[$i+1]);
			}
			splice(@KEVS,$i,2);
		} elsif( $KEVS[$i] eq 'pid' ) {
			$self->referent->dat($KEVS[$i+1]);
			splice(@KEVS,$i,2);
		} else {
			$KEVS[$i] = 'jtitle' if $KEVS[$i] eq 'title';
			$i += 2;
		}
	}
	# Map genre onto a ctx format and add the metadata
	if( $genre =~ '^article|preprint|proceeding$' ) {
		$self->referent->journal(@KEVS);
	} elsif( $genre eq 'bookitem' ) {
		$self->referent->book(@KEVS);
	} else {
		die "Unable to handle version 0.1 genre: $genre";
	}
	$self;
}

=pod

=item @qry = $uri->query_form([key, value, [key, value]])

Equivalent to URI::query_form, but with support for UTF-8 encoding.

=cut

sub query_form
{
	my $self = shift;
	my @new = @_;
	if( 1 == @new ) {
		my $n = $new[0];
		if( ref($n) eq "ARRAY" ) {
			@new = @$n;
		} elsif( ref($n) eq "HASH" ) {
			@new = %$n;
		}
	}
	for (@new) {
		utf8::encode($_);
	}
	map { utf8::decode($_); $_ } $self->SUPER::query_form(@new);
}

=pod

=item $uri->init_ctxobj_version()

Add ContextObject versioning.

=cut

sub init_ctxobj_version
{
	my $self = shift;
	my %query = $self->query_form;
	return if
		defined($query{'ctx_ver'}) &&
		$query{'ctx_ver'} eq 'Z39.88-2004';
	$self->query_form(
		$self->query_form,
		ctx_ver => 'Z39.88-2004',
		ctx_enc => 'info:ofi/enc:UTF-8',
		url_ctx_fmt => 'info:ofi/fmt:kev:mtx:ctx',
	);
}

=pod

=item $ts = $uri->init_timestamps([ctx_timestamp, [url_timestamp]])

Add ContextObject and URL timestamps, returns the old timestamp(s) or undef on none.

=cut

sub init_timestamps {
	my $self = shift;
	my $ctx_timestamp = shift ||
		strftime("%Y-%m-%dT%H:%M:%STZD",gmtime(time));
	my $url_timestamp = shift || $ctx_timestamp;
	my @query = $self->query_form;
	my @old;
	for(my $i = 0; $i < @query;) {
		if( $query[$i] eq 'ctx_tim' ) {
			($_,$old[0]) = splice(@query,$i,2);
		} elsif( $query[$i] eq 'url_tim' ) {
			($_,$old[1]) = splice(@query,$i,2);
		} else {
			$i+=2;
		}
	}
	$self->query_form(
		@query,
		'ctx_tim', $ctx_timestamp,
		'url_tim', $url_timestamp,
	);
	wantarray ? @old : ($old[0]||$old[1]);
}

=pod

=item $uri = $uri->as_hybrid()

Return the OpenURL as a hybrid 0.1/1.0 OpenURL (contains KEVs for both versions). Returns a new URI::OpenURL object.

=cut

sub as_hybrid
{
	my $self = shift;
	my @KEVS = $self->query_form;
	# Add the referent
	my @md = $self->referent->metadata();
	# 'title' has been changed to 'jtitle' in 1.0
	for(my $i = 0; $i < @md; $i+=2) {
		$md[$i] = 'title' if($md[$i] eq 'jtitle');
	}
	push @KEVS, @md;
	# Add the referrer's id
	my $rfr_id = $self->referrer->id;
	if( defined($rfr_id) && $rfr_id =~ s/^info:sid\/// ) {
		push @KEVS,	sid => $rfr_id;
	}
	# Add the referent's id (if its compatible with 0.1)
	my $rft_id = $self->referent->id;
	if( defined($rft_id) &&
		($rft_id =~ s/^info:(doi|pmid|bibcode)\//$1:/ ||
		 $rft_id =~ /^oai:/)
	) {
		push @KEVS,	id => $rft_id;
	}
	# Return a new URI (otherwise we pollute ourselves)
	my $hybrid = new URI::OpenURL($self);
	$hybrid->query_form(@KEVS);
	$hybrid;
}

=item $uri = $uri->canonical()

Return a canonical OpenURL by removing anything that isn't part of the version 1.0 specification.

=cut

sub canonical
{
	my $uri = shift->SUPER::canonical();
	$uri = bless $uri, "URI::OpenURL";
	my @KEVS = $uri->query_form();
	for(my $i = 0; $i < @KEVS; ) {
		if( $KEVS[$i] !~ /^ctx_ver|ctx_enc|ctx_id|ctx_tim|url_ver|url_tim|url_ctx_fmt|(?:(?:rft|rfe|svc|req|res|rfr)[_\.].+)$/ ) {
			splice(@KEVS,$i,2);
		} else {
			$i += 2;
		}
	}
	$uri->query_form(@KEVS);
	$uri;
}

=pod

=item $str = $uri->dump()

Return the OpenURL as a human-readable string (useful for debugging).

=cut

sub dump
{
	my $self = shift;
	my $str = URI->new($self);
	$str->query('');
	$str .= "\n";
	my @kevs = $self->query_form;
	for(my $i = 0; $i < @kevs; $i+=2) {
		$str .= $kevs[$i] . "=" . $kevs[$i+1] . "\n";
	}
	$str;
}

=pod

=item $uri = $uri->referent()

Every ContextObject must have a Referent, the referenced resource for which the ContextObject is created. Within the scholarly information community the Referent will probably be a document-like object, for instance: a book or part of a book; a journal publication or part of a journal; a report; etc.

=cut

sub referent {
	my $self = bless shift, 'URI::OpenURL::referent';
	return $self->descriptors() if wantarray;
	$self->_addattr(@_);
}

=pod

=item $uri->referringEntity()

The ReferringEntity is the Entity that references the Referent. It is optional in the ContextObject. Within the scholarly information community the ReferringEntity could be a journal article that cites the Referent. Or it could be a record within an abstracting and indexing database.

=cut

sub referringEntity {
	my $self = bless shift, 'URI::OpenURL::referringEntity';
	return $self->descriptors() if wantarray;
	$self->_addattr(@_);
}

=pod

=item $uri = $uri->requester()

The Requester is the Entity that requests services pertaining to the Referent. It is optional in the ContextObject. Within the scholarly information community the Requester is generally a human end-user who clicks a link within a digital library application.

=cut

sub requester {
	my $self = bless shift, 'URI::OpenURL::requester';
	return $self->descriptors() if wantarray;
	$self->_addattr(@_);
}

=item $uri = $uri->serviceType()

The ServiceType is the Entity that defines the type of service requested. It is optional in the ContextObject. Within the scholarly information community the ServiceType could be a request for; the full text of an article; the abstract of an article; an inter-library loan request, etc.

=cut

sub serviceType {
	my $self = bless shift, 'URI::OpenURL::serviceType';
	return $self->descriptors() if wantarray;
	$self->_addattr(@_);
}

=pod

=item $uri = $uri->resolver()

The Resolver is the Entity at which a request for services is targeted. It is optional in the ContextObject. This need not be the same Resolver as that specified as the base URL for an OpenURL Transport and does not replace that base URL.

=cut

sub resolver {
	my $self = bless shift, 'URI::OpenURL::resolver';
	return $self->descriptors() if wantarray;
	$self->_addattr(@_);
}

=pod

=item $uri = $uri->referrer()

The Referrer is the Entity that generated the ContextObject. It is optional in the ContextObject, but its inclusion is strongly encouraged. Within the scholarly information community the Referrer will be an information provider such as an electronic journal application or an 'abstracting and indexing' service.

=cut

sub referrer {
	my $self = bless shift, 'URI::OpenURL::referrer';
	return $self->descriptors() if wantarray;
	$self->_addattr(@_);
}

=pod

=item $uri = $uri->referent->dublinCore(key => value)

=item $uri = $uri->referent->book(key => value)

=item $uri = $uri->referent->dissertation(key => value)

=item $uri = $uri->referent->journal(key => value)

=item $uri = $uri->referent->patent(key => value)

=item $uri = $uri->serviceType->scholarlyService(key => value)

Add metadata to the current entity (referent is given only as an example). Dublin Core is an experimental format.

=item @descs = $uri->referent->descriptors([$key=>$value[, $key=>$value]])

Return the descriptors as a list of key-value pairs for the current entity (referent is given as an example).

Optionally add descriptors (functionally equivalent to $uri->referent($key=>$value)).

=item @metadata = $uri->referent->metadata([$schema_url, $key=>$value[, $key=>$value]])

Returns by-value metadata as a list of key-value pairs for the current entity (referent is given as an example).

Optionally, if you wish to add metadata that does not use one of the standard schemas (journal, book etc.) then you can add them using metadata.

=item @vals = $uri->referent->descriptor('id')

Return a list of values given for an entity descriptor (id, ref, dat, val_fmt, ref_fmt).

=item $dat = $uri->referent->dat()

=item @ids = $uri->referent->id()

=item $ref = $uri->referent->ref()

=item $val_fmt = $uri->referent->val_fmt()

=item $ref_fmt = $uri->referent->ref_fmt()

Return the respective descriptor using a method interface. An entity may contain 0 or more ids, and optionally a by-reference URI, private data, by-value format and by-reference format.

=head1 CHANGES

	0.4.6
		- Removed ContextObject versioning from default
		  constructor
	0.4.5
		- Support for URL utf-8 encoding
	0.4.2
		- Added methods for parsing/writing hybrid OpenURLs
	0.4.1
		- Timestamps no longer included in default initialization
		- Added method "init_timestamps" to add timestamps
	0.4
		- Initial release

=head1 COPYRIGHT

Quotes from the OpenURL implementation guidelines are from: http://library.caltech.edu/openurl/

Copyright 2004 Tim Brody.

This module is released under the same terms as the main Perl distribution.

=head1 AUTHOR

Tim Brody <tdb01r@ecs.soton.ac.uk>
Intelligence, Agents, Multimedia Group
University of Southampton, UK

=back

=cut

package URI::OpenURL::entity;

use vars qw(@ISA);
@ISA = qw(URI::OpenURL);

use vars qw( %ENTITIES );

%ENTITIES = (
	referent 	=> 	'rft',
	referringEntity => 	'rfe',
	serviceType	=>	'svc',
	requester	=>	'req',
	resolver	=>	'res',
	referrer 	=> 	'rfr',
);

sub _entity {
	my $entity = ref(shift());
	$entity =~ s/.*:://;
	$ENTITIES{$entity};
}

sub _addattr {
	my ($self,@pairs) = @_;
	my @KEVS = $self->query_form();
	my $entity = _entity($self);
	for( my $i = 0; $i < @pairs; $i+=2 ) {
		next unless defined($pairs[$i+1]) && length($pairs[$i+1]);
		push @KEVS, $entity.'_'.$pairs[$i], $pairs[$i+1];
	}
	$self->query_form(@KEVS);
	$self;
}

sub _addkevs {
	my ($self,$val_fmt,@pairs) = @_;
	my @KEVS = $self->query_form();
	my $entity = _entity($self);
	push @KEVS, $entity.'_val_fmt', $val_fmt if $val_fmt;
	for( my $i = 0; $i < @pairs; $i+=2 ) {
		next unless defined($pairs[$i+1]) && length($pairs[$i+1]);
		push @KEVS, $entity.'.'.$pairs[$i], $pairs[$i+1];
	}
	$self->query_form(@KEVS);
	bless $self, 'URI::OpenURL'; # Should catch some broken user code
}

sub dublinCore {
	shift->_addkevs('info:ofi/fmt:kev:mtx:dc',@_);
}

sub book {
	shift->_addkevs('info:ofi/fmt:kev:mtx:book',@_);
}

sub dissertation {
	shift->_addkevs('info:ofi/fmt:kev:mtx:dissertation',@_);
}

sub journal {
	shift->_addkevs('info:ofi/fmt:kev:mtx:journal',@_);
}

sub patent {
	shift->_addkevs('info:ofi/fmt:kev:mtx:patent',@_);
}

sub scholarlyService {
	shift->_addkevs('info:ofi/fmt:kev:mtx:sch_svc',@_);
}

# Descriptors (things with '_' in)
sub descriptors {
	my $self = shift;
	$self->_addattr(@_) if @_;
	return () unless wantarray;
	my $entity = $self->_entity();
	my @pairs = $self->query_form();
	my @md;
	for(my $i = 0; $i < @pairs; $i+=2) {
		if( $pairs[$i] =~ s/^$entity\_// ) {
			push @md, $pairs[$i], $pairs[$i+1];
		}
	}
	return @md;
}

sub descriptor {
	my ($self,$key) = splice(@_,0,2);
	$self->_addattr($key => $_) for @_;
	my @KEVS = $self->query_form();
	my @VALS;
	my $entity = $self->_entity();
	for(my $i = 0; $i < @KEVS; $i+=2) {
		push @VALS, $KEVS[$i+1] if( $KEVS[$i] eq "${entity}_${key}" );
	}
	wantarray ? @VALS : $VALS[0];
}

sub dat { shift->descriptor('dat',@_) }
sub id { shift->descriptor('id',@_) }
sub ref { shift->descriptor('ref',@_) }
sub ref_fmt { shift->descriptor('ref_fmt',@_) }
sub val_fmt { shift->descriptor('val_fmt',@_) }

# By-value metadata (things with '.' in)
sub metadata {
	my $self = shift;
	$self->_addkevs(@_) if @_;
	return () unless wantarray;
	my $entity = $self->_entity();
	my @pairs = $self->query_form();
	my @md;
	for(my $i = 0; $i < @pairs; $i+=2) {
		if( $pairs[$i] =~ s/^$entity\.// ) {
			push @md, $pairs[$i], $pairs[$i+1];
		}
	}
	return @md;
}

package URI::OpenURL::referent;

use vars qw(@ISA);
@ISA = qw(URI::OpenURL::entity);

package URI::OpenURL::referringEntity;

use vars qw(@ISA);
@ISA = qw(URI::OpenURL::entity);

package URI::OpenURL::requester;

use vars qw(@ISA);
@ISA = qw(URI::OpenURL::entity);

package URI::OpenURL::serviceType;

use vars qw(@ISA);
@ISA = qw(URI::OpenURL::entity);

package URI::OpenURL::resolver;

use vars qw(@ISA);
@ISA = qw(URI::OpenURL::entity);

package URI::OpenURL::referrer;

use vars qw(@ISA);
@ISA = qw(URI::OpenURL::entity);

1;

