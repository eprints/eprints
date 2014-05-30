######################################################################
#
# EPrints::Apache::LogHandler
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

EPrints::Apache::LogHandler - Main handler for Apache log events

=head1 CONFIGURATION

To enable the Apache::LogHandler add to your ArchiveConfig:

   $c->{loghandler}->{enable} = 1;

=head1 DATA FORMAT

=over 4

=item requester

The requester is stored using their IP in URN format: C<urn:ip:x.x.x.x>.

=item serviceType

ServiceType is in format L<info:ofi/fmt:kev:mtx:sch_svc|http://alcme.oclc.org/openurl/servlet/OAIHandler?verb=GetRecord&metadataPrefix=oai_dc&identifier=info:ofi/fmt:kev:mtx:sch_svc>.

The value is encoded as C<?name=yes> (where C<name> is one of the services defined).

=item referent, referringEntity

These are stored in URN format: C<info:oai:repositoryid:eprintid>.

=item referent_docid

The document id as a fragment of the referent: C<#docid>.

=back

=head1 METHODS

=over 4

=cut

package EPrints::Apache::LogHandler;

use EPrints;

use strict;

use EPrints::Apache::AnApache;
use Apache2::Connection;

our @USERAGENT_ROBOTS = map { s/\s+//g; qr/$_/i } <DATA>;
our %ROBOTS_CACHE; # key=IP, value=time (or -time if not a robot)
our $TIMEOUT = 3600; # 1 hour

sub handler {} # deprecated

sub is_robot
{
	my( $r, $ip ) = @_;

	my $time_t = time();

	# cleanup then check the cache
	for(keys %ROBOTS_CACHE)
	{
		delete $ROBOTS_CACHE{$_} if abs($ROBOTS_CACHE{$_}) < $time_t;
	}

	return $ROBOTS_CACHE{$ip} > 0 if exists $ROBOTS_CACHE{$ip};
	$ROBOTS_CACHE{$ip} = $time_t + $TIMEOUT;

	my $is_robot = 0;

	my $ua = $r->headers_in->{ "User-Agent" };
	if( $ua )
	{
		for(@USERAGENT_ROBOTS)
		{
			$is_robot = 1, last if $ua =~ $_;
		}
	}

	$ROBOTS_CACHE{$ip} *= -1 if !$is_robot;

	return $is_robot;
}

=item $handler->document( $r )

A request on a document.

=cut

sub document
{
	my( $r ) = @_;

	# COUNTER compliance specifies 200 and 304
	if( $r->status != 200 && $r->status != 304 )
	{
		return DECLINED;
	}

	my $doc = $r->pnotes( "document" );

	my $ip = $doc->repository->remote_ip;
	return if is_robot( $r, $ip );

	my $filename = $r->pnotes->{ "filename" };

	# only count hits to the main file
	if( $filename ne $doc->get_main )
	{
		return DECLINED;
	}

	# ignore volatile version downloads (e.g. thumbnails)
        my $relations = $doc->get_value( "relation" );
        $relations = [] unless( defined $relations );
        foreach my $r (@$relations)
        {
                return DECLINED if( $r->{type} =~ /is\w+ThumbnailVersionOf$/ || $r->{type} eq 'http://eprints.org/relation/isVolatileVersionOf' );
        }

	my $epdata = _generic( $r, { _parent => $doc } );

	$epdata->{requester_id} = $ip;
	$epdata->{service_type_id} = "?fulltext=yes";
	$epdata->{referent_id} = $doc->value( "eprintid" );
	$epdata->{referent_docid} = $doc->id;

	return _create_access( $r, $epdata );
}

=item $handler->eprint( $r )

A request on an eprint abstract page.

=cut

sub eprint
{
	my( $r ) = @_;

	# e.g. ignore 304 NOT MODIFIED
	if( $r->status != 200 )
	{
		return DECLINED;
	}

	# only track hits on the full abstract page
	if( $r->filename !~ /\bindex\.html$/ )
	{
		return DECLINED;
	}
	
	my $eprint = $r->pnotes( "eprint" );

	my $ip = $eprint->repository->remote_ip;
	return if is_robot( $r, $ip );

	my $epdata = _generic( $r, { _parent => $eprint } );

	$epdata->{requester_id} = $ip;
	$epdata->{service_type_id} = "?abstract=yes";
	$epdata->{referent_id} = $eprint->id;

	return _create_access( $r, $epdata );
}

sub _generic
{
	my( $r, $epdata ) = @_;

	$epdata->{datestamp} = EPrints::Time::get_iso_timestamp( $r->request_time );
	$epdata->{referring_entity_id} = $r->headers_in->{ "Referer" };
	$epdata->{requester_user_agent} = $r->headers_in->{ "User-Agent" };

	# Sanity check referring URL (don't store non-HTTP referrals)
	if( !$epdata->{referring_entity_id} || $epdata->{referring_entity_id} !~ /^https?:/ )
	{
		$epdata->{referring_entity_id} = '';
	}

	return $epdata;
}

sub _create_access
{
	my( $r, $epdata ) = @_;

	my $repository = $EPrints::HANDLE->current_repository;
	if( !defined $repository )
	{
		return DECLINED;
	}

	$repository->dataset( "access" )->create_dataobj( $epdata );

	return OK;
}

1;

=back

=head1 SEE ALSO

L<EPrints::DataObj::Access>


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

=cut

# http://www.projectcounter.org/documents/COUNTER_robot_txt_list_Jan_2011.txt
__DATA__
	Alexandria(\s|\+)prototype(\s|\+)project
	AllenTrack
	Arachmo
	Brutus\/AET
	China\sLocal\sBrowse\s2\.6
	Code\sSample\sWeb\sClient
	ContentSmartz
	DSurf
	DataCha0s\/2\.0
	Demo\sBot
	EmailSiphon
	EmailWolf
	FDM(\s|\+)1
	Fetch(\s|\+)API(\s|\+)Request
	GetRight
	Goldfire(\s|\+)Server
	Googlebot
	HTTrack
	LOCKSS
	LWP\:\:Simple
	MSNBot
	Microsoft(\s|\+)URL(\s|\+)Control
	Milbot
	MuscatFerre
	NABOT
	NaverBot
	Offline(\s|\+)Navigator
	OurBrowser
	Python\-urllib
	Readpaper
	Strider
	T\-H\-U\-N\-D\-E\-R\-S\-T\-O\-N\-E
	Teleport(\s|\+)Pro
	Teoma
	Wanadoo
	Web(\s|\+)Downloader
	WebCloner
	WebCopier
	WebReaper
	WebStripper
	WebZIP
	Webinator
	Webmetrics
	Wget
	Xenu(\s|\+)Link(\s|\+)Sleuth
	[+:,\.\;\/\\-]bot
	[^a]fish
	^voyager\/
	acme\.spider
	alexa
	almaden
	appie
	architext
	archive\.org_bot
	arks
	asterias
	atomz
	autoemailspider
	awbot
	baiduspider
	bbot
	biadu
	biglotron
	bjaaland
	blaiz\-bee
	bloglines
	blogpulse
	boitho\.com\-dc
	bookmark\-manager
	bot
	bot[+:,\.\;\/\\-]
	bspider
	bwh3_user_agent
	celestial
	cfnetwork|checkbot
	combine
	commons\-httpclient
	contentmatch
	core
	crawl
	crawler
	cursor
	custo
	daumoa
	docomo
	dtSearchSpider
	dumbot
	easydl
	exabot
	fast-webcrawler
	favorg
	feedburner
	feedfetcher\-google
	ferret
	findlinks
	gaisbot
	geturl
	gigabot
	girafabot
	gnodspider
	google
	grub
	gulliver
	harvest
	heritrix
	hl_ftien_spider
	holmes
	htdig
	htmlparser
	httpget\-5\.2\.2
	httpget\?5\.2\.2
	httrack
	iSiloX
	ia_archiver
	ichiro
	iktomi
	ilse
	internetseer
	intute
	java
	java\/
	jeeves
	jobo
	kyluka
	larbin
	libwww
	libwww\-perl
	lilina
	linkbot
	linkcheck
	linkchecker
	linkscan
	linkwalker
	livejournal\.com
	lmspider
	lwp
	lwp\-request
	lwp\-tivial
	lwp\-trivial
	lycos[_+]
	mail.ru
	mediapartners\-google
	megite
	milbot
	mimas
	mj12bot
	mnogosearch
	moget
	mojeekbot
	momspider
	motor
	msiecrawler
	msnbot
	myweb
	nagios
	netcraft
	netluchs
	ng\/2\.
	no_user_agent
	nomad
	nutch
	ocelli
	onetszukaj
	perman
	pioneer
	playmusic\.com
	playstarmusic\.com
	powermarks
	psbot
	python
	qihoobot
	rambler
	redalert|robozilla
	robot
	robots
	rss
	scan4mail
	scientificcommons
	scirus
	scooter
	seekbot
	seznambot
	shoutcast
	slurp
	sogou
	speedy
	spider
	spiderman
	spiderview
	sunrise
	superbot
	surveybot
	tailrank
	technoratibot
	titan
	turnitinbot
	twiceler
	ucsd
	ultraseek
	urlaliasbuilder
	urllib
	virus[_+]detector
	voila
	w3c\-checklink
	webcollage
	weblayers
	webmirror
	webreaper
	wordpress
	worm
	xenu
	y!j
	yacy
	yahoo
	yahoo\-mmcrawler
	yahoofeedseeker
	yahooseeker
	yandex
	yodaobot
	zealbot
	zeus
	zyborg
