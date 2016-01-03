=head1 NAME

EPrints::Plugin::Export::Atom

=cut

package EPrints::Plugin::Export::Atom;

use EPrints::Plugin::Export::Feed;
use EPrints::Const qw( :namespace );

@ISA = ( "EPrints::Plugin::Export::Feed" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Atom";
	$self->{accept} = [qw(
		list/eprint dataobj/eprint
		list/document dataobj/document
		list/file dataobj/file
	)];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "application/atom+xml;charset=utf-8";

	return $self;
}

sub output_list
{
	my( $self, %opts ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $r = '';
	my $f = defined($opts{fh}) ?
		sub { print {$opts{fh}} "$_[0]\n" } :
		sub { $r .= "$_[0]\n" };
	my $fx = sub { &$f( $xml->to_string( $_[0] ) ); $xml->dispose( $_[0] ); };

	my $list = $opts{list};
	my $dataset = $list->{dataset};
	my $dataset_id = $dataset->base_id;

	&$f( "<?xml version=\"1.0\" encoding=\"utf-8\" ?>" );
	&$f( '<feed
	xmlns="http://www.w3.org/2005/Atom"
	xmlns:opensearch="'.EP_NS_OPENSEARCH.'"
	xmlns:xhtml="http://www.w3.org/1999/xhtml"
	xmlns:sword="http://purl.org/net/sword/"
>' );
	
	# title
	my $title = $repo->phrase( "archive_name" );
	$title.= ": ".$xhtml->to_text_dump( $list->render_description );
	&$fx( $xml->create_data_element(
		"title",
		$title ) );

	# self link
	if( exists $opts{link_self} )
	{
		&$fx( $xml->create_data_element(
			"link",
			undef,
			rel => "self",
			href => $opts{link_self} ) );
	}

	# front-page link
	&$fx( $xml->create_data_element(
		"link",
		undef,
		rel => "alternate",
		href => $repo->config( "frontpage" ) ) );
	
	# feed last-update
	&$fx( $xml->create_data_element(
		"updated", 
		EPrints::Time::get_iso_timestamp() ) );

	# feed generator
	&$fx( $xml->create_data_element(
		"generator",
		"EPrints",
		uri => "http://www.eprints.org/",
		version => EPrints->human_version ) );

	# feed logo
	my $site_logo = $self->param( "logo" ) || $repo->config( "site_logo" );
	$site_logo = URI->new_abs( $site_logo, $repo->current_url( host => 1, path => 'static' ) );
	&$fx( $xml->create_data_element(
		"logo",
		$site_logo ) );

	# feed id
	&$fx( $xml->create_data_element(
		"id", 
		$repo->config( "frontpage" ) ) );

	if( exists $opts{links} )
	{
		&$fx( $opts{links} );
	}

	# opensearch
	local $_;
	for(qw( totalResults itemsPerPage startIndex ))
	{
		if( exists $opts{$_} )
		{
			&$fx( $xml->create_data_element(
				"opensearch:$_",
				$opts{$_}
				) );
		}
	}
	if( exists $opts{offsets} )
	{
		if( my $search = delete $opts{offsets}{search} )
		{
			&$fx( $xml->create_data_element(
				"link",
				undef,
				rel => "search",
				%$search,
			) );
		}
		foreach my $key (sort keys %{$opts{offsets}})
		{
			&$fx( $xml->create_data_element(
				"link",
				undef,
				rel => $key,
				type => $self->param( "mimetype" ),
				title => $repo->phrase( "lib/searchexpression:$key",
					n => "",
				),
				href => $opts{offsets}->{$key} ) );
		}
	}

	# entries
	my $fn = "output_$dataset_id";
	$list->map(sub {
		my( undef, undef, $dataobj ) = @_;

		&$f( $self->$fn( $dataobj, %opts ) );
	});

	&$f( '</feed>' );

	return $r;
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	my $dataset_id = $dataobj->get_dataset_id;
	my $fn = "output_$dataset_id";

	$opts{single} = 1;

	my $xml = '<?xml version="1.0" encoding="utf-8" ?>' . "\n" . $self->$fn( $dataobj, %opts );
	
	if( $self->{repository}->get_online )
	{
		my $r = $self->{repository}->get_request;
		use bytes;
		my $ctx = Digest::MD5->new;
		$ctx->add( Encode::encode_utf8( $xml ) );
		$r->headers_out->{'ETag'} = $ctx->hexdigest;
		$r->headers_out->{'Content-MD5'} = $ctx->b64digest;
		$r->headers_out->{'Content-Length'} = length($xml);
	}

	return $xml;
}

sub output_eprint
{
	my( $self, $dataobj, %opts ) = @_;

	my $dataset = $dataobj->get_dataset;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $entry;
	if ($opts{single}) {
		$entry = $xml->create_element( "entry", xmlns=> "http://www.w3.org/2005/Atom", "xmlns:sword"=> "http://purl.org/net/sword/" );
	} else {
		$entry = $xml->create_element( "entry" );
	}

	$entry->appendChild( $xml->create_data_element(
			"link",
			undef,
			rel => "self",
			href => $self->dataobj_export_url( $dataobj ) ) );
	$entry->appendChild( $xml->create_data_element( 
			"link",
			undef,
			rel => "edit",
			href => $dataobj->uri ) );
	$entry->appendChild( $xml->create_data_element( 
			"link",
			undef,
			rel => "edit-media",
			href => $dataobj->uri . "/contents" ) );
	$entry->appendChild( $xml->create_data_element( 
			"link",
			undef,
			rel => "contents",
			href => $dataobj->uri . "/contents" ) );
	$entry->appendChild( $xml->create_data_element(
			"link",
			undef,
			rel => "alternate",
			href => $dataobj->uri ) );
	foreach my $doc ($dataobj->get_all_documents)
	{
		if( $doc->exists_and_set( "content" ) && $doc->value( "content" ) eq "coverimage" && defined($doc->thumbnail_url) )
		{
			$entry->appendChild( $xml->create_data_element(
				"icon",
				$repo->current_url( host => 1, path => 0 ).$doc->thumbnail_url,
			) );
		}
	}

	my $lastmod = $dataset->field( "lastmod" )->iso_value( $dataobj->value( "lastmod" ) );
	my $datestamp = $dataset->field( "datestamp" )->iso_value( $dataobj->value( "datestamp" ) );

	$entry->appendChild( $xml->create_data_element(
			"published",
			$datestamp
			) );	
	$entry->appendChild( $xml->create_data_element(
			"updated",
			$lastmod
			) );	

	$entry->appendChild( $xml->create_data_element(
				"id", 
				$dataobj->uri ) );

	$entry->appendChild( $xml->create_data_element(
		"category",
		undef,
		term => $dataobj->value( "type" ),
		label => $xhtml->to_text_dump( $dataobj->render_value( "type" ) ),
		scheme => $repo->config( "base_url" )."/data/eprint/type"
	) );
	
	$entry->appendChild( $xml->create_data_element(
		"category",
		undef,
		term => $dataobj->value( "eprint_status" ),
		label => $xhtml->to_text_dump( $dataobj->render_value( "eprint_status" ) ),
		scheme => EPrints::Const::EP_NS_DATA . "/eprint/eprint_status"
	) );
	
	$entry->appendChild( $xml->create_data_element(
		"link",
		undef,
		rel => "http://purl.org/net/sword/terms/statement",
		href => $dataobj->uri
	) );
	
	$entry->appendChild( $xml->create_data_element(
		"sword:state",
		undef,
		href => EPrints::Const::EP_NS_DATA . "/eprint/eprint_status/" . $dataobj->value( "eprint_status" )
	) );

	$entry->appendChild( $xml->create_data_element(
		"sword:stateDescription",
		$repo->html_phrase("cgi/users/edit_eprint:staff_item_is_in_" . $dataobj->value( "eprint_status" ), link=> $repo->make_text($dataobj->uri), url=>$repo->make_text("") )
	) );
	
	my $original_deposit = $xml->create_data_element(
		"sword:originalDeposit",
		undef,
		href => $dataobj->uri
	);
	$entry->appendChild($original_deposit);
	
	$original_deposit->appendChild( $xml->create_data_element(
		"sword:depositedOn",
		$datestamp
	) );

	if ( $dataobj->exists_and_set( "sword_depositor" ) ) 
	{
		my $user = $repo->user($dataobj->value( "sword_depositor" ));
		if (defined $user) 
		{
			$original_deposit->appendChild( $xml->create_data_element(
				"sword:depositedBy",
				$user->value("username")
			) );
		
			my $owner = $repo->user($dataobj->value("userid"));
			
			if (!($user->id eq $owner->id))
			{
				$original_deposit->appendChild( $xml->create_data_element(
					"sword:depositedOnBehalfOf",
					$owner->value("username")
				) );
			}


		}
	}

	# metadata
	my $title = $dataobj->exists_and_set( "title" ) ?
			$dataobj->render_value( "title" ) :
			$dataobj->render_description;
	$entry->appendChild( $xml->create_data_element(
			"title",
			$title,
			type => "xhtml" ) );
	if( $dataobj->exists_and_set( "abstract" ) )
	{
		$entry->appendChild( $xml->create_data_element(
				"summary",
				$dataobj->render_value( "abstract" ),
				type => "xhtml" ) );
	}
	if( $dataobj->exists_and_set( "creators" ) )
	{
		my $names = $dataobj->get_value( "creators" );
		foreach my $name ( @$names )
		{
			my $author = $xml->create_element( "author" );

			my $name_str = EPrints::Utils::make_name_string( $name->{name}, 1 );
			$author->appendChild( $xml->create_data_element(
						"name",
						$name_str ) );
			
			$author->appendChild( $xml->create_data_element(
						"email",
						$name->{id} ) );

			$entry->appendChild( $author );
		}
	}

	my $r = $xml->to_string( $entry, indent => 1 );
	$xml->dispose( $entry );

	return $r;
}

sub output_document
{
	my( $self, $dataobj, %opts ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $main = $dataobj->stored_file( $dataobj->value( "main" ) );

	my $entry = $xml->create_element( "entry" );
	
	$entry->appendChild( $xml->create_data_element(
			"id",
			$dataobj->uri ) );
	$entry->appendChild( $xml->create_data_element(
			"title",
			$xhtml->to_text_dump( $dataobj->render_description ) ) );
	
	$entry->appendChild( $xml->create_data_element( 
		"link",
		undef,
		rel => "contents",
		href => $dataobj->uri . "/contents" ) );	
	$entry->appendChild( $xml->create_data_element( 
		"link",
		undef,
		rel => "edit-media",
		href => $dataobj->uri . "/contents" ) );	

	$entry->appendChild( $xml->create_data_element(
			"summary",
			$xhtml->to_text_dump( $dataobj->render_citation ) ) );

	$entry->appendChild( $xml->create_data_element(
		"content",
		undef,
		type => ($main ? $main->value( "mime_type" ) : undef),
		src => $dataobj->uri . "/contents" ) );

	my $r = $xml->to_string( $entry, indent => 1 );
	$xml->dispose( $entry );

	return $r;
}

sub output_file
{
	my( $self, $dataobj, %opts ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $doc = $dataobj->parent();

	my $entry = $xml->create_element( "entry" );
	
	$entry->appendChild( $xml->create_data_element(
			"id",
			$dataobj->uri ) );
	$entry->appendChild( $xml->create_data_element(
			"title",
			$dataobj->get_value("filename") ) );
	$entry->appendChild( $xml->create_data_element(
			"link",
			undef,
			rel => "alternate",
			href => $doc->get_url( $dataobj->value( "filename" ) ) ) );
	
	my $r = $xml->to_string( $entry, indent => 1 );
	$xml->dispose( $entry );

	return $r;
}

1;


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

