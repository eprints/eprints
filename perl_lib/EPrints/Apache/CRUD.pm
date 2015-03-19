=for Pod2Wiki {{Version|since=3.3.0}}

=head1 NAME

EPrints::Apache::CRUD - Create, read, update and delete via HTTP

=head1 SYNOPSIS

	$crud = EPrints::Apache::CRUD->new(
			repository => $repo,
			request => $r,
			datasetid => "eprint",
			dataobjid => "23",
		);

=head1 DESCRIPTION

The CRUD (Create/Read/Update/Delete) module provides the Web API for manipulating content on the server. The API is an AtomPub implementation that exposes Import and Export plugins via simple URLs and HTTP content type negotiation.

You should use the <link> entries in the repository's home page to locate the CRUD endpoint, as they may change in the future:

	<link rel="Sword" href="https://myrepo/sword-app/servicedocument" />
	<link rel="SwordDeposit" href="https://myrepo/id/contents" />

=head2 Examples

Create a new eprint based on a single file:

	curl -x POST \
		-i \
		-u user:password \
		-d 'Hello, World!' \
		-H 'Content-Type: text/plain' \
		https://myrepo/id/contents
	
	HTTP/1.1 201 Created
	Content-Type: application/atom+xml;charset=utf-8
	...

Add a file to an existing eprint:

	curl -X POST \
		-i \
		-u user:password \
		-d 'Hello, World!' \
		-H 'Content-Disposition: attachment; filename=hello.txt' \
		-H 'Content-Type: text/plain' \
		https://myrepo/id/eprint/23/contents
	
	HTTP/1.1 201 Created
	Content-Type: application/atom+xml;charset=utf-8
	...

Get an eprint's metadata in Atom XML:

	curl -X GET \
		-i \
		-u user:password \
		-H 'Accept: application/atom+xml' \
		https://myrepo/id/eprint/23

	HTTP/1.1 200 OK
	Content-Type: application/atom+xml;charset=utf-8
	...

Get the list of contents (documents) of an eprint in Atom XML:

	curl -X GET \
		-i \
		-u user:password \
		-H 'Accept: application/atom+xml' \
		https://myrepo/id/eprint/23/contents

	HTTP/1.1 200 OK
	Content-Type: application/atom+xml;charset=utf-8
	...

You can find more examples in the F<tests/84_sword.t> unit test.

=head2 URI layout

These URIs are relative to your EPrints HTTP/HTTPs root.

=over 4

=item /id/contents GET,HEAD,OPTIONS,POST

Requires authentication.

GET a list of the eprints owned by the user. POST to create a new EPrint object.

=item /id/[datasetid]/[dataobjid] DELETE,GET,HEAD,OPTIONS,PUT

Requires authentication depending on user's privileges and object visibility.

GET an object's metadata or, for L<File|EPrints::DataObj::File> objects, the file content. PUT to replace the metadata and/or contents (see L</Updating complex objects using PUT>). If the object does not exist will attempt to create it with the given dataobjid (requires 'upsert' privilege).

=item /id/[datasetid]/[dataobjid]/contents DELETE,GET,HEAD,OPTIONS,POST,PUT

Requires authentication depending on user's privileges and object visibility.

GET the logical contents of the object: documents for eprints or files for documents. PUT to replace the existing contents or POST to add to the existing contents.

=back

=head2 HTTP Content Negotiation

GET/HEAD requests are processed using L<Export|EPrints::Plugin::Export> plugins. POST/PUT requests are processed using L<Import|EPrints::Plugin::Import> plugins.

The plugin used depends on the request's I<Accept> (GET/HEAD) or I<Content-Type> (POST/PUT) header and the type of object being acted on. For example, the following request:

	GET /id/eprint/23 HTTP/1.1
	Accept: application/vnd.eprints.data+xml

Will search for an Export plugin that accepts objects of type B<dataobj/eprint> and can produce output in the MIME type B<application/vnd.eprints.data+xml>. This will most likely be the L<EP3 XML|EPrints::Plugin::Export::XML> plugin.

In addition to the general plugin negotiation behaviour some special cases are supported to improve compatibility with Atom Pub/Web Browser clients:

=over 4

=item /id/eprint/...

Requesting L<EPrint|EPrints::DataObj::EPrint> objects as text/html will result in a 303 Redirect to the eprint object's abstract page or, if the eprint is not public, its L<View|EPrints::Plugin::Screen::EPrint::View> page.

=item /id/document/.../contents

Requesting the I</contents> of a L<Document|EPrints::DataObj::Document> object will return the content of the document's main file.

=item /id/file/...

Requesting a L<File|EPrints::DataObj::File> object with no I<Accept> header (or B<*/*>) will return the file's content.

=item POST /id/.../contents

When creating new records via POST, content negotiation is performed against the Import plugins.

If no Import plugin supports the I<Content-Type> header the content will be treated as B<application/octet-stream> and stored in a new object. The resulting Atom entry will describe the new object (e.g. the I<eprint> object in which the new I<document> and I<file> objects were created).

Otherwise, the result will depend on the Import plugin's output. Import plugins may produce a single object, multiple objects or an object plus content file(s).

=item Content-Type header

If no I<Content-Type> header is given the MIME type defaults to B<application/octet-stream> for POSTs and PUTs.

=item Content-Disposition header

If the I<Content-Disposition> header is missing or does not contain a I<filename> parameter the filename defaults to F<main.bin> for POSTs and PUTs.

=back

=head2 Updating complex objects using PUT

Eprint objects contain zero or more documents, which each contain zero or more files. When you update (PUT) an eprint object the contained documents will only be replaced if the Import plugin defines new documents e.g. the Atom Import plugin will never define new documents so PUTing Atom content will only update the eprint's metadata. PUTing L<EP3 XML|EPrints::Plugin::Export::XML> will replace the documents if you include a <documents> XML element.

PUTing to I</contents> will always replace all contents - PUTing to I</eprint/23/contents> is equivalent to I<DELETE /eprint/23/contents> then I<POST /eprint/23/contents>.

=head2 PUT/DELETE from Javascript

=for MediaWiki {{Available|since=3.3.9}}

Web browsers only allow GET and POST requests. To perform other requests use the 'X-Method' header with POST to specify the actual method you want:

	POST /id/eprint/23 HTTP/1.1
	X-Method: PUT
	...

=head2 Upserting objects with PUT

=for MediaWiki {{Available|since=3.3.9}}

If you have the I<upsert> privilege objects will be created on demand, otherwise attempting to PUT to a non-existant object will result in an error.

=head1 METHODS

=over 4

=cut

package EPrints::Apache::CRUD;

use EPrints::Const qw( :http );
use MIME::Base64;
use HTTP::Headers::Util;
use Digest::MD5;
use EPrints::Apache::Auth;
use Apache2::Access;

our $PACKAGING_PREFIX = "sword:";

use constant {
	CRUD_SCOPE_USER_CONTENTS => 1,
	CRUD_SCOPE_DATASET => 2,
	CRUD_SCOPE_DATAOBJ => 3,
	CRUD_SCOPE_FIELD => 4,
	CRUD_SCOPE_CONTENTS => 5,
	CRUD_SCOPE_SERVICEDOCUMENT => 6,
};

use strict;

my %CONTENTSMAP = (
	"EPrints::DataObj::EPrint" => "documents",
	"EPrints::DataObj::Document" => "files",
	);

sub new
{
	my( $class, %self ) = @_;

	my $self = bless \%self, $class;

	my $rc = $self->process_headers;
	$self->request->status( $rc ), return if $rc != OK;

	$self{options} = [qw( GET HEAD OPTIONS )];

	# servicedocument FIXME
	return $self if !exists $self{datasetid};

	my $repo = $self{repository};

	# /id/FOO...
	if( defined $self{datasetid} )
	{
		$self{dataset} = $repo->dataset( $self{datasetid} );
		if( !defined $self{dataset} )
		{
			$self{request}->status( HTTP_NOT_FOUND );
			return;
		}
		$self{options} = [qw( GET HEAD POST OPTIONS )];
		$self{scope} = CRUD_SCOPE_DATASET;
	}
	# /id/contents
	else
	{
		$self{dataset} = $repo->dataset( "eprint" );
		$self{options} = [qw( GET HEAD POST OPTIONS )];
		$self{scope} = CRUD_SCOPE_USER_CONTENTS;
	}

	# /id/FOO/BAR
	if( defined $self{dataobjid} )
	{
		my @relations;
		if( $self{dataset}->base_id eq "document" )
		{
			($self{dataobjid}, @relations) = split /\./, $self{dataobjid};
			@relations = grep { length($_) } @relations;
		}

		$self{dataobj} = $self{dataset}->dataobj( $self{dataobjid} );

		# resolve 11.hassmallThumbnailVersion
		$self{dataobj} = $self->resolve_relations( $self{dataobj}, @relations );

		# adjust /id/eprint/23 to /id/archive/23
		$self{dataset} = $self{dataobj}->get_dataset if defined $self{dataobj};

		$self{options} = [qw( GET HEAD PUT OPTIONS )];
		$self{scope} = CRUD_SCOPE_DATAOBJ;
	}

	# /id/FOO/BAR/xxx
	if( defined $self{fieldid} )
	{
		if( $self{fieldid} eq "contents" )
		{
			$self{options} = [qw( GET HEAD POST PUT OPTIONS )];
			$self{scope} = CRUD_SCOPE_CONTENTS;
			my $fieldid = $CONTENTSMAP{ref($self->dataobj)};
			if( !defined $fieldid )
			{
				$self{request}->status( HTTP_NOT_FOUND );
				return;
			}
			$self{field} = $self{dataset}->field( $fieldid );
			$self{dataset} = $repo->dataset(
					$self{field}->property( "datasetid" )
				);
		}
		elsif( !$self{dataset}->has_field( $self{fieldid} ) )
		{
			$self{request}->status( HTTP_NOT_FOUND );
			return;
		}
		else
		{
			$self{field} = $self{dataset}->field( $self{fieldid} );
			$self{options} = [qw( GET HEAD PUT OPTIONS )];
			$self{scope} = CRUD_SCOPE_FIELD;
		}
	}

	if( !defined $self{plugin} )
	{
		$self{plugin} = $self->content_negotiate_best_plugin;
	}

	return $self;
}

=item $repo = $crud->repository()

Returns the current repository.

=cut

sub repository { $_[0]->{repository} }

=item $r = $crud->request()

Returns the current L<Apache2::RequestUtil>.

=cut

sub request { $_[0]->{request} }

=item $method = $crud->method()

Returns the HTTP method.

=cut

sub method { $_[0]->{method} }

=item $scope = $crud->scope()

Returns the scope of the action being performed.

=cut

sub scope { $_[0]->{scope} }

=item $dataset = $crud->dataset()

Returns the current dataset (if any).

=cut

sub dataset { $_[0]->{dataset} }

=item $dataobj = $crud->dataobj()

Returns the current dataobj (if any).

=cut

sub dataobj { $_[0]->{dataobj} }

=item $field = $crud->field()

Returns the current field (if available);

=cut

sub field { $_[0]->{field} } 

=item $headers = $crud->headers()

Get the processed headers.

=cut

sub headers { $_[0]->{headers} }

=item @verbs = $crud->options()

Returns the available HTTP verbs for the current request.

=cut

sub options { @{$_[0]->{options}} }

=item $plugin = $crud->plugin()

Returns the current plugin (if available).

=cut

sub plugin { $_[0]->{plugin} }

=item $bool = $crud->is_write()

Returns true if the request is not a read-only method.

=cut

sub is_write { $_[0]->method !~ /^GET|HEAD|OPTIONS$/ }

=item $accept_type = $crud->accept_type()

Returns the EPrints type for the current request.

=cut

sub accept_type
{
	my( $self ) = @_;

	my $accept_type = $self->dataset->base_id;
	if(
		$self->is_write ||
		$self->scope == CRUD_SCOPE_DATAOBJ ||
		$self->scope == CRUD_SCOPE_SERVICEDOCUMENT
	  )
	{
		$accept_type = "dataobj/".$accept_type;
	}
	else
	{
		$accept_type = "list/".$accept_type;
	}

	return $accept_type;
}

=item $rc = $crud->check_packaging()

Check the Packaging header is ok, if given.

=cut

sub check_packaging
{
	my( $self ) = @_;

	my $headers = $self->headers;

	if( $headers->{packaging} && !defined $self->plugin )
	{
		return $self->sword_error(
			status => HTTP_BAD_REQUEST,
			href => "http://purl.org/net/sword/error/ErrorContent",
			summary => "No support for packaging '$headers->{packaging}'",
		);
	}

	return OK;
}

=item $dataobj = $crud->resolve_relations( $dataobj [, @relations ] )

Resolve the relation path from $dataobj and return the resulting dataobj.

Returns undef if there is no such related object.

=cut

sub resolve_relations
{
	my( $self, $dataobj, @relations ) = @_;

	foreach my $r (@relations)
	{
		last if !defined $dataobj;

		$r =~ s/^has(.+)$/is$1Of/;
		$dataobj = $dataobj->search_related( $r )->item( 0 );
	}

	return $dataobj;
}

sub _priv
{
	my( $self ) = @_;

	my $r = $self->request;
	my $dataset = $self->dataset;
	my $dataobj = $self->dataobj;
	my $plugin = $self->plugin;
	my $field = $self->field;

	my $priv;
	# /id/xx/yy/contents
	if( $self->scope eq CRUD_SCOPE_CONTENTS )
	{
		$priv = $self->is_write ? "edit" : "view";
		$dataobj = $dataobj->parent
			if $dataobj->isa( "EPrints::DataObj::File" );
		$dataobj = $dataobj->parent
			if $dataobj->isa( "EPrints::DataObj::Document" );
		$dataset = $dataobj->get_dataset;
	}
	elsif( $self->method eq "POST" )
	{
		$priv = "create";
	}
	elsif( $self->method eq "PUT" )
	{
		if( $self->scope == CRUD_SCOPE_DATAOBJ && !defined $dataobj )
		{
			$priv = "upsert";
		}
		else
		{
			$priv = "edit";
		}
	}
	elsif( $self->method eq "DELETE" )
	{
		$priv = "destroy";
	}
	elsif( defined($plugin) && $plugin->get_subtype ne "SummaryPage" )
	{
		$priv = "export";
	}
	else
	{
		$priv = "view";
	}

	if( $dataset->base_id eq "eprint" && $priv eq "create" )
	{
		$priv = "create_eprint";
	}
	elsif( $self->scope eq CRUD_SCOPE_USER_CONTENTS && $dataset->base_id eq "eprint" && $priv eq "view" )
	{
		$priv = "items";
	}
	elsif( $dataset->id ne $dataset->base_id )
	{
		return(
				join('/', $dataset->base_id, $dataset->id, $priv ),
				join('/', $dataset->base_id, $priv ),
			);
	}
	else
	{
		$priv = join('/', $dataset->base_id, $priv );
	}

	return $priv;
}

# authentication
sub authen
{
	my( $self ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;
	my $dataset = $self->dataset;
	my $dataobj = $self->dataobj;
	my $plugin = $self->plugin;

	# POST, PUT, DELETE must authenticate
	if( $self->is_write )
	{
		return EPrints::Apache::Auth::authen( $r );
	}

	# a staff-plugin implicitly requires a user
	if( defined($plugin) && $plugin->param( "visible" ) eq "staff" )
	{
		return EPrints::Apache::Auth::authen( $r );
	}

	# /id/contents implicitly requires a user
	if( $self->scope eq CRUD_SCOPE_USER_CONTENTS )
	{
		return EPrints::Apache::Auth::authen( $r );
	}

	my @privs = $self->_priv;

	if( defined $dataobj )
	{
		foreach my $priv (@privs)
		{
			return OK if $dataobj->permit( $priv );
		}
	}
	else
	{
		foreach my $priv (@privs)
		{
			return OK if $repo->allow_anybody( $priv );
		}
	}


	return EPrints::Apache::Auth::authen( $r );
}

# authorisation
sub authz
{
	my( $self ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;
	my $dataset = $self->dataset;
	my $dataobj = $self->dataobj;
	my $plugin = $self->plugin;

	my $user = $repo->current_user;

	if( defined($plugin) && $plugin->param( "visible" ) eq "staff" )
	{
		return HTTP_FORBIDDEN if !defined $user || !$user->is_staff;
	}

	my @privs = $self->_priv;

	if( defined $dataobj )
	{
		foreach my $priv (@privs)
		{
			return OK if $dataobj->permit( $priv, $user );
		}
	}
	elsif( defined $user )
	{
		foreach my $priv (@privs)
		{
			return OK if $user->allow( $priv );
		}
	}
	else
	{
		foreach my $priv (@privs)
		{
			return OK if $repo->allow_anybody( $priv );
		}
	}

	return HTTP_FORBIDDEN;
}

=item $list = $crud->parse_input( $plugin, $f [, %params ] )

Parse the content submitted by the user using the given $plugin.  $f is called by epdata_to_dataobj to convert epdata to a dataobj.  %params are passed to the plugin's input_fh method.

Returns undef on error.

=cut

sub _read_content
{
	my( $self ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;
	my $headers = $self->headers;

	my $ctx = $headers->{content_md5} ? Digest::MD5->new : undef;

	my $tmpfile = File::Temp->new( SUFFIX => $headers->{extension} );
	binmode($tmpfile);
	my $len = 0;
	while($r->read(my $buffer, 4096)) {
		$len += length($buffer);
		$ctx->add( $buffer ) if defined $ctx;
		print $tmpfile $buffer;
	}
	seek($tmpfile,0,0);

	if( defined $ctx && $ctx->hexdigest ne $headers->{content_md5} )
	{
		$self->sword_error(
			status => HTTP_PRECONDITION_FAILED,
			href => "http://purl.org/net/sword/error/ErrorChecksumMismatch",
			summary => "MD5 digest mismatch between headers and content",
		);
		return undef;
	}

	return $tmpfile;
}

sub parse_input
{
	my( $self, $plugin, $f, %params ) = @_;

	my $repo = $self->repository;
	my $headers = $self->headers;

	my @messages;
	my $count = 0;

	$plugin->set_handler( EPrints::CLIProcessor->new(
		message => sub { push @messages, $_[1] },
		epdata_to_dataobj => sub { ++$count; &$f },
		) );

	my $tmpfile = $self->_read_content();
	return undef if !defined $tmpfile;

	my %content_type_params;
	for(keys %{$headers->{content_type_params}})
	{
		next if !$plugin->has_argument( $_ );
		$content_type_params{$_} = $headers->{content_type_params}->{$_};
	}

	my $list = eval { $plugin->input_fh(
		%content_type_params,
		dataset => $self->dataset,
		fh => $tmpfile,
		filename => $headers->{filename},
		mime_type => $headers->{mime_type},
		content_type => $headers->{content_type},
		actions => $headers->{actions},
		%params,
	) };

	if( !defined $list )
	{
		$self->plugin_error( $plugin, \@messages );
		return undef;
	}
	elsif( $count == 0 )
	{
		$plugin->handler->message( "error", "Import plugin didn't create anything" );
		$self->plugin_error( $plugin, \@messages );
		return undef;
	}

	return $list;
}

sub create_dataobj
{
	my( $self, $owner, $epdata ) = @_;

	$epdata = {} if !defined $epdata;

	my $repo = $self->repository;
	my $dataset = $self->dataset;

	local $repo->{config}->{enable_import_fields} = 1;

	$epdata->{$dataset->key_field->name} = $self->{dataobjid};

	if( $dataset->base_id eq "eprint" )
	{
		$epdata->{userid} = $owner->id;
		$epdata->{eprint_status} = "inbox";
	}

	return $dataset->create_dataobj( $epdata );
}

=item @plugins = $crud->import_plugins( [ %params ] )

Returns all matching import plugins against %params ordered by descending 'q' score.

=cut

sub import_plugins
{
	my( $self, %params ) = @_;

	my $user = $self->repository->current_user;
	if( defined $user && !$user->is_staff )
	{
		$params{is_visible} = "all";
	}

	my @plugins = $self->repository->get_plugins(
		type => "Import",
		can_produce => $self->accept_type,
		%params,
	);

	my %qs = map { $_ => ($_->param( "qs" ) || 0) } @plugins;
	my %ids = map { $_ => $_->get_id } @plugins;

	return sort {
			$qs{$b} <=> $qs{$a} || $ids{$a} cmp $ids{$b}
		} @plugins;
}

=item @plugins = $crud->export_plugins( [ %params ] )

Returns all matching export plugins against %params ordered by descending 'q' score.

=cut

sub export_plugins
{
	my( $self, %params ) = @_;

	my $user = $self->repository->current_user;
	if( defined $user && !$user->is_staff )
	{
		$params{is_visible} = "all";
	}

	my @plugins = $self->repository->get_plugins(
		type => "Export",
		can_accept => $self->accept_type,
		%params,
	);

	my %qs = map { $_ => ($_->param( "qs" ) || 0) } @plugins;
	my %ids = map { $_ => $_->get_id } @plugins;

	return sort {
			$qs{$b} <=> $qs{$a} || $ids{$a} cmp $ids{$b}
		} @plugins;
}

=item $plugin = $crud->content_negotiate_best_plugin()

Work out the best plugin to export/update an object based on the client-headers.

=cut

sub content_negotiate_best_plugin
{
	my( $self ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;
	my $dataset = $self->dataset;
	my $field = $self->field;

	my $headers = $self->headers;

	return undef if $self->method eq "DELETE";

	my $accept_type = $self->accept_type;

	if( defined(my $package = $headers->{packaging}) )
	{
		my $plugin;
		if( $self->is_write )
		{
			($plugin) = $self->import_plugins(
					can_accept => $PACKAGING_PREFIX.$package,
					can_action => $headers->{actions},
				);
		}
		else
		{
			($plugin) = $self->export_plugins(
					can_produce => $PACKAGING_PREFIX.$package,
				);
		}
		return $plugin;
	}

	my @plugins;
	if( $self->is_write )
	{
		@plugins = $self->import_plugins(
				can_action => $headers->{actions},
			);
	}
	else
	{
		@plugins = $self->export_plugins();
	}

	my %pset;

	foreach my $plugin ( @plugins )
	{
		my $mimetype = $plugin->get_type eq "Export" ?
			$plugin->param( "produce" ) :
			$plugin->param( "accept" );
		$mimetype = join ',', @$mimetype;
		for( HTTP::Headers::Util::split_header_words( $mimetype ) )
		{
			my( $type, undef, %params ) = @$_;

			push @{$pset{$type}}, {
				%params,
				plugin => $plugin,
				q => $plugin->param( "qs" ),
				id => $plugin->get_id,
			};
		}
	}
	# sort plugins internally by q then id
	for(values(%pset))
	{
		@$_ = sort { $b->{q} <=> $a->{q} || $a->{id} cmp $b->{id} } @$_;
	}
	# sort supported types by the highest plugin score
	my @pset_order = sort {
		$pset{$b}->[0]->{q} <=> $pset{$a}->[0]->{q}
	} keys %pset;

	my $accept;
	if( $self->is_write )
	{
		$accept = $r->headers_in->{'Content-Type'};
	}
	else
	{
		# summary page is higher priority than anything else for /id/eprint/23
		# and /id/contents
		if( ( $self->scope == CRUD_SCOPE_DATAOBJ && $self->{dataset}->base_id ne "subject" ) || $self->scope == CRUD_SCOPE_USER_CONTENTS )
		{
			my $plugin = $repo->plugin( "Export::SummaryPage" );
			my $mimetype = $plugin->param( "produce" );
			$mimetype = join ',', @$mimetype;
			for( HTTP::Headers::Util::split_header_words( $mimetype ) )
			{
				my( $type, undef, %params ) = @$_;
				unshift @pset_order, $type;
				unshift @{$pset{$type}}, {
					charset => 'utf-8',
					q => $plugin->param( "qs" ),
					plugin => $plugin,
				};
			}
		}

		$accept = $r->headers_in->{Accept} || "*/*";
	}

	my @accept = parse_media_range( $accept || "" );

	my $match;
	CHOICE: foreach my $choice ( @accept )
	{
		my( $mime_type, undef, %params ) = @$choice;
		my( $type, $subtype ) = split '/', $mime_type;

		# find matching entries by mime-type
		if( exists $pset{$mime_type} )
		{
			# pick the best plugin based on parameters and then plugin qs
			my $plugins = $pset{$mime_type};
			for(keys %params) {
				next if $_ eq "q";
				foreach my $match (@$plugins) {
					$match->{q}++
						if exists($match->{$_}) && $match->{$_} eq $params{$_};
				}
			}
			$match = (sort { $b->{q} <=> $a->{q} || $a->{id} cmp $b->{id} } @$plugins)[0]->{plugin};
			$r->pnotes->{mime_type} = $mime_type;
			last CHOICE;
		}
		# */*
		elsif( $type eq '*' && $subtype eq '*' )
		{
			$match = $pset{$pset_order[0]}->[0]->{plugin};
			$r->pnotes->{mime_type} = $mime_type;
			last CHOICE;
		}
		# text/*
		elsif( $subtype eq '*' )
		{
			for(@pset_order)
			{
				if( m#^$type/# )
				{
					$match = $pset{$_}->[0]->{plugin};
					$r->pnotes->{mime_type} = $mime_type;
					last CHOICE;
				}
			}
		}
	}

	return $match;
}

# http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.1
sub parse_media_range
{
	my( $media_range ) = @_;

	my @accept = HTTP::Headers::Util::split_header_words( $media_range );
	for(@accept)
	{
		my( $mime_type, undef, %params ) = @$_;
		$params{'mime_type'} = $mime_type;
		$params{q} = 1 if !defined $params{q};
		$_ = \%params;
	}

	@accept = sort {
# q-scores
		$b->{q} <=> $a->{q} ||
# text/html is higher than text/*
		$a->{mime_type} cmp $b->{mime_type} ||
# text/html;level=1 is higher than text/html
		scalar(keys %$b) <=> scalar(keys %$a)
	} @accept;

	return map { [ delete $_->{mime_type}, undef, %$_ ] } @accept;
}

sub handler
{
	my( $self ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;
	my $dataset = $self->dataset;
	my $dataobj = $self->dataobj;
	my $plugin = $self->plugin;

	my $user = $repo->current_user;

	my( $rc, $owner ) = on_behalf_of( $repo, $r, $user );
	return $rc if $rc != OK;

	# Subject URI's redirect to the top of that particular subject tree
	# rather than the node in the tree.
	if( UNIVERSAL::isa( $dataobj, "EPrints::DataObj::Subject" ) )
	{
		$dataobj = $dataobj->top || $dataobj;
		$self->{dataobj} = $dataobj;
	}

	if( $self->method eq "DELETE" )
	{
		return $self->DELETE( $owner );
	}
	elsif( $self->method eq "POST" )
	{
		return $self->POST( $owner );
	}
	elsif( $self->method eq "PUT" )
	{
		if( $self->scope == CRUD_SCOPE_CONTENTS )
		{
			return $self->PUT_contents( $owner );
		}
		else
		{
			return $self->PUT( $owner );
		}
	}
	elsif( $self->method eq "GET" || $self->method eq "HEAD" || $self->method eq "OPTIONS" )
	{
		$r->err_headers_out->{Allow} = join ',', $self->options;

		return $self->GET( $owner );
	}

	return HTTP_METHOD_NOT_ALLOWED;
}

=item $rc = $crud->DELETE()

Handle DELETE requests.

=over 4

=item HTTP_METHOD_NOT_ALLOWED

Can't perform DELETE on F</id/contents>.

=item HTTP_NOT_FOUND

No such object.

=item HTTP_CONFLICT

Lock conflict with another user.

=item HTTP_NO_CONTENT

Successfully removed the object.

=back

=cut

sub DELETE
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $dataobj = $self->dataobj;

	my $user = $repo->current_user;

	# /id/contents
	return HTTP_METHOD_NOT_ALLOWED if $self->scope == CRUD_SCOPE_USER_CONTENTS;

	# already deleted?
	return NOT_FOUND if !defined $dataobj;

	# obtain parent lock, if available
	my $lock_obj = $dataobj;
	while( defined($lock_obj) && !$lock_obj->can( "obtain_lock" ) )
	{
		$lock_obj = $lock_obj->can( "parent" ) ? $lock_obj->parent : undef;
	}
	if( defined $lock_obj )
	{
		$lock_obj->obtain_lock( $user )
			or return HTTP_CONFLICT;
	}

	# allow DELETE /id/foo/bar/contents because /contents is the edit-media URI
	if( $self->scope == CRUD_SCOPE_CONTENTS )
	{
		$_->remove for @{$self->field->get_value( $dataobj )};
	}
	else
	{
		$dataobj->remove;
	}

	if( defined $lock_obj && $lock_obj ne $dataobj )
	{
		$lock_obj->remove_lock( $user );
	}

	return HTTP_NO_CONTENT;
}

=item $rc = $crud->GET( [ $owner ] )

Handle GET requests.

=over 4

=item HTTP_NO_CONTENT

No sub-objects in I</id/.../contents>.

=item HTTP_NOT_ACCEPTABLE

More than one sub-object in I</id/.../contents>.

=item HTTP_UNSUPPORTED_MEDIA_TYPE

No L<Export|EPrints::Plugin::Export> plugin matches the I<Accept> header/object type.

=item HTTP_SEE_OTHER

Redirect to a non-CRUD EPrints page.

=item HTTP_NOT_FOUND

Object not found.

=item HTTP_OK

Object outputted successfully.

=back

=cut

sub GET
{
	my( $self, $owner ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;
	my $dataset = $self->dataset;
	my $dataobj = $self->dataobj;
	my $field = $self->field;
	my $plugin = $self->plugin;

	# what to do when the user doesn't ask for a specific content type
	if( $r->pnotes->{mime_type} eq "*/*" )
	{
		# GET/HEAD XX/contents without mime type, default to content
		if( $self->scope == CRUD_SCOPE_CONTENTS )
		{
			if( $dataobj->isa( "EPrints::DataObj::EPrint" ) )
			{
				my @docs = $dataobj->get_all_documents;
				if( @docs == 0 )
				{
					return HTTP_NO_CONTENT;
				}
				elsif( @docs == 1 )
				{
					$dataobj = $docs[0];
				}
				else
				{
					return $self->sword_error(
						status => HTTP_NOT_ACCEPTABLE,
						summary => "More than one resource at this location",
					);
				}
			}
			return EPrints::Apache::Rewrite::redir_see_other( $r, $dataobj->get_url );
		}

		# GET/HEAD /id/contents without mime type, default to Atom
		elsif( $self->scope == CRUD_SCOPE_USER_CONTENTS )
		{
			$plugin = $repo->plugin( "Export::Atom" );
		}
	}

	return HTTP_UNSUPPORTED_MEDIA_TYPE if !defined $plugin;

	if( $dataset->base_id eq "subject" )
	{
		return EPrints::Apache::Rewrite::redir_see_other( $r, $plugin->dataobj_export_url( $dataobj ) );
	}

	my %args = %{$plugin->param( "arguments" )};
	# fetch the plugin arguments, if any
	foreach my $argname (keys %args)
	{
		if( defined $repo->param( $argname ) )
		{
			$args{$argname} = $repo->param( $argname );
		}
	}

	if( $self->scope == CRUD_SCOPE_USER_CONTENTS )
	{
		my $indexOffset = $repo->param( "indexOffset" ) || 0;
		my $page_size = 20;

		my $base = $repo->current_url( host => 1 );
		my $next = $base->clone;
		$next->query_form( indexOffset => $indexOffset + $page_size );
		my $previous = $base->clone;
		$previous->query_form( indexOffset => $indexOffset - $page_size );

		my $list = $owner->owned_eprints_list(
			limit => $indexOffset + $page_size,
			custom_order => "-lastmod",
		);
		$list->{ids} = $list->ids( $indexOffset, $page_size );

		$r->content_type( $plugin->param( "mimetype" ) );
		$plugin->initialise_fh( \*STDOUT );
		$plugin->output_list(
			startIndex => $indexOffset,
			list => $list,
			fh => \*STDOUT,
			offsets => {
				self => $repo->current_url( host => 1, query => 1 ),
				first => $base,
				next => $next,
				($indexOffset >= $page_size ? (previous => $previous) : ()),
			},
		);
	}
	elsif( $self->scope == CRUD_SCOPE_CONTENTS )
	{
		my $datasetid = $field->property( "datasetid" );
		my @ids;
		if( $dataobj->isa( "EPrints::DataObj::EPrint" ) )
		{
			@ids = map { $_->id } $dataobj->get_all_documents;
		}
		else
		{
			@ids = map { $_->id } @{$field->get_value( $dataobj )};
		}
		$r->content_type( $plugin->param( "mimetype" ) );
		$plugin->initialise_fh( \*STDOUT );
		$plugin->output_list(
			%args,
			list => EPrints::List->new(
				session => $repo,
				dataset => $repo->dataset( $datasetid ),
				ids => \@ids
			),
			fh => \*STDOUT,
		);
	}
	elsif( $self->scope == CRUD_SCOPE_DATAOBJ )
	{
		return HTTP_NOT_FOUND if !defined $dataobj;

		# user wants HTML and there is a static page available
		my $url = ($dataset->base_id eq "eprint" && $dataset->id ne "archive") ?
				$dataobj->get_control_url :
				$dataobj->get_url;
		if( $plugin->get_subtype eq "SummaryPage" )
		{
			if( defined( $url ) && $url ne $dataobj->uri )
			{
				return EPrints::Apache::Rewrite::redir_see_other( $r, $url );
			}
		}

		# set Last-Modified header for individual objects
		if( my $field = $dataset->get_datestamp_field() )
		{
			my $datestamp = $field->get_value( $dataobj );
			$r->headers_out->{'Last-Modified'} = Apache2::Util::ht_time(
				$r->pool,
				EPrints::Time::datestring_to_timet( undef, $datestamp )
			);
		}
		$r->content_type( $plugin->param( "mimetype" ) );
		$plugin->initialise_fh( \*STDOUT );
		my $output = $plugin->output_dataobj( $dataobj,
			%args,
			fh => \*STDOUT,
		);
		# optional for output_dataobj to support 'fh'
		print $output if defined $output;
	}
	# /id/eprint, not supported yet (what would it do?)
	else
	{
		return HTTP_NOT_FOUND;
	}

	return OK;
}

=item $rc = $crud->POST( [ $owner ] )

Handle POST requests.

=over 4

=item HTTP_METHOD_NOT_ALLOWED

Can only POST to I</id/.../contents>.

=item HTTP_BAD_REQUEST

No plugin for the SWORD I<Packaging> header.

=item HTTP_CREATED

Object(s) successfully created.

=back

=cut

sub POST 
{
	my( $self, $owner ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;
	my $dataset = $self->dataset;
	my $dataobj = $self->dataobj;
	my $field = $self->field;
	my $plugin = $self->plugin;

	my $user = $repo->current_user;

	# can only post to XX/contents and /id/contents
	if(
		$self->scope != CRUD_SCOPE_CONTENTS &&
		$self->scope != CRUD_SCOPE_USER_CONTENTS
	  )
	{
		return HTTP_METHOD_NOT_ALLOWED;
	}

	my $headers = $self->headers;

	my $rc = $self->check_packaging;
	return $rc if $rc != OK;

	# we can import any file type into /contents
	if( !defined $plugin )
	{
		$plugin = $repo->plugin( "Import::Binary" );
	}

	my @items;

	my $status;
	my $rev_number;
	if( $self->scope == CRUD_SCOPE_USER_CONTENTS )
	{
		$status = $headers->{in_progress} ? "inbox" : "buffer";
		$status = "archive" if ($repo->config("skip_buffer") and $status eq "buffer");
	}

	my $list = $self->parse_input( $plugin, sub {
			my( $epdata ) = @_;

			if( $self->scope == CRUD_SCOPE_USER_CONTENTS )
			{
				$epdata->{userid} = $owner->id;
				$epdata->{sword_depositor} = $user->id;
				$epdata->{eprint_status} = $status;
				$epdata->{rev_number} = $rev_number;

				push @items, $dataset->create_dataobj( $epdata );
			}
			else
			{
				push @items, $dataobj->create_subdataobj( $field->name, $epdata );
			}

			return $items[-1];
		}
	);
	return undef if !defined $list;

	if( $self->scope == CRUD_SCOPE_CONTENTS && $headers->{metadata_relevant} )
	{
		$self->metadata_relevant( $items[0] );
	}

	my $atom = $repo->plugin( "Export::Atom" );

	# producing more than one item (potentially)
	if( $self->scope == CRUD_SCOPE_CONTENTS && $headers->{flags}->{unpack} )
	{
		return $self->send_response(
			HTTP_CREATED,
			$atom->param( "mimetype" ),
			$atom->output_list( list => $list ),
		);
	}
	else
	{
		$r->err_headers_out->{Location} = $items[0]->uri;
# DEBUG CODE
if( defined $field && $headers->{mime_type} ne "application/atom+xml" )
{
$r->err_headers_out->{Location} = $items[0]->uri . '/contents';
}
# DEBUG CODE

		return $self->send_response(
			HTTP_CREATED,
			$atom->param( "mimetype" ),
			$atom->output_dataobj( $items[0] ),
		);
	}
}

=item $rc = $crud->PUT( [ $owner ] )

Handle PUT requests.

=over 4

=item HTTP_UNSUPPORTED_MEDIA_TYPE

No L<Import|EPrints::Plugin::Import> plugin matched the I<Content-Type> header/object type.

=item HTTP_RANGE_NOT_SATISFIABLE

I<Range> header is invalid or unsupported for the I<object type>.

=item HTTP_FORBIDDEN

User does not have permission to create/update the I<object>.

=item HTTP_CREATED

Object was successfully created.

=item HTTP_NO_CONTENT

Object was successfully updated.

=back

=cut

# PUT /id/eprint/23
sub PUT
{
	my( $self, $owner ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;
	my $dataset = $self->dataset;
	my $dataobj = $self->dataobj;
	my $plugin = $self->plugin;

	my $user = $repo->current_user;

	my $headers = $self->headers;

	my $rc = $self->check_packaging;
	return $rc if $rc != OK;

	if( !defined $plugin && $dataset->base_id eq "file" )
	{
		$plugin = $repo->plugin( "Import::Binary" );
	}

	return HTTP_UNSUPPORTED_MEDIA_TYPE if !defined $plugin;

	# We support Content-Ranges for writing to files
	if( defined(my $offset = $headers->{offset}) )
	{
		my $total = $headers->{total};
		if( $dataset->base_id ne "file" || !defined $dataobj )
		{
			return $self->sword_error(
					status => HTTP_RANGE_NOT_SATISFIABLE,
					summary => "Content-Range unsupported for ".$dataset->base_id,
				);
		}
		my $tmpfile = $self->_read_content;
		return $r->status if !defined $tmpfile;

		if( $total eq '*' || ($offset + -s $tmpfile) > $total )
		{
			return $self->sword_error(
					status => HTTP_RANGE_NOT_SATISFIABLE,
					summary => "Won't write beyond total file size (or total size not given)",
				);
		}

		my $rlen = $dataobj->set_file_chunk( $tmpfile, -s $tmpfile, $offset, $total );
		return $self->sword_error(
				status => HTTP_INTERNAL_SERVER_ERROR,
				summary => "Error occurred during writing - check server logs",
			) if !defined $rlen;

		$dataobj->commit;

		return HTTP_NO_CONTENT;
	}

	my $epdata;

	my $list = $self->parse_input( $plugin, sub {
			( $epdata ) = @_; return undef
		} );
	return if !defined $list;

	# implicit create on unknown URI
	if( !defined $dataobj )
	{
		$dataobj = $self->create_dataobj( $owner );
		return $self->sword_error(
				status => HTTP_FORBIDDEN,
				summary => "An item already exists at this location or you do not have sufficient privileges to create an item with a predefined identifier",
			) if !defined $dataobj;
	}

	my( $old_status, $new_status );

	if( $dataset->base_id eq "eprint" )
	{
		$old_status = $dataobj->value( "eprint_status" );
		$new_status = delete $epdata->{eprint_status};

		$epdata->{userid} = $owner->id;
		$epdata->{sword_depositor} = $user->id;
		$epdata->{eprint_status} = $old_status;
		$epdata->{rev_number} = $dataobj->value( "rev_number" );

		# check the user has permission to move this eprint, before we perform
		# any other changes.
		my $priv = "eprint/$old_status/move_$new_status";
		if(
			EPrints::Utils::is_set( $new_status ) &&
			$new_status ne $old_status &&
			!$user->allow( $priv, $dataobj )
		  )
		{
			return $self->sword_error(
					status => HTTP_FORBIDDEN,
					summary => "Insufficient privileges to transfer item from $old_status to $new_status",
				);
		}
	}

	$dataobj->empty();
	$dataobj->update( $epdata, include_subobjects => 1 );
	$dataobj->commit;

	# transfer the eprint, if needed
	if(
		EPrints::Utils::is_set( $new_status ) &&
		$new_status ne $old_status
	  )
	{
		$dataobj->_transfer( $new_status );
	}

	if( !defined $self->dataobj )
	{
		my $atom = $repo->plugin( "Export::Atom" );

		$self->request->err_headers_out->{Location} = $dataobj->uri;
		return $self->send_response(
			HTTP_CREATED,
			$atom->param( "mimetype" ),
			$atom->output_dataobj( $dataobj ),
		);
	}

	return HTTP_NO_CONTENT;
}

=item $rc = $crud->PUT_contents( [ $owner ] )

Equivalent to C<DELETE /id/.../contents> then C<POST /id/.../contents>.

See L</DELETE> and L</POST>.

=cut

sub PUT_contents
{
	my( $self, $owner ) = @_;

	my $repo = $self->repository;
	my $dataobj = $self->dataobj;
	my $plugin = $self->plugin;
	my $field = $self->field;

	my $headers = $self->headers;

	my $rc = $self->check_packaging;
	return $rc if $rc != OK;

	# we can import any file type into XX/contents
	if( !defined $plugin )
	{
		$plugin = $repo->plugin( "Import::Binary" );
	}

	return HTTP_UNSUPPORTED_MEDIA_TYPE if !defined $plugin;

	# PUT /XX/contents implies DELETE existing contents
	$_->remove for @{$field->get_value( $dataobj )};

	my @items;

	my $list = $self->parse_input( $plugin, sub {
			my( $epdata ) = @_;

			push @items, $dataobj->create_subdataobj( $field->name, $epdata );

			return $items[-1];
		}
	);
	return if !defined $list;

	if( $headers->{metadata_relevant} )
	{
		$self->metadata_relevant( $items[0] );
	}

	return HTTP_NO_CONTENT;
}

sub metadata_relevant
{
	my( $self, $file ) = @_;

	my $repo = $self->repository;

	if( $file->isa( "EPrints::DataObj::EPrint" ) )
	{
		$file = ($file->get_all_documents())[0];
	}
	if( defined $file && $file->isa( "EPrints::DataObj::Document" ) )
	{
		$file = $file->stored_file( $file->value( "main" ) );
	}
	return if !defined $file;

	my $eprint = eval { $file->parent->parent };
	return if !defined $eprint;

	my $fh = $file->get_local_copy;
	return if !defined $fh;

	my $dataset = $repo->dataset( "eprint" );

	my $epdata = {};

	my @plugins = $repo->get_plugins(
		type => "Import",
		can_accept => $file->value( "mime_type" ),
		can_produce => "dataobj/".$dataset->base_id,
		can_action => "metadata",
	);
	@plugins = sort { $a->{qs} <=> $b->{qs} } @plugins;

	my @messages;

	my $handler = EPrints::CLIProcessor->new(
		message => sub { push @messages, $_[1] },
		epdata_to_dataobj => sub {
			my( $data ) = @_;

			foreach my $fieldname (keys %$data)
			{
				next if !$dataset->has_field( $fieldname );
				my $f = $dataset->field( $fieldname );
				delete $epdata->{$fieldname} if exists $epdata->{$fieldname};
				$epdata->{$fieldname} = $data->{$fieldname};
			}
			return undef;
		}
	);

	foreach my $plugin ( @plugins )
	{
		$plugin->set_handler( $handler );

		seek($fh,0,0);
		$plugin->input_fh(
			fh => $fh,
			dataset => $dataset,
			filename => $file->value( "filename" ),
			actions => ["metadata"],
		);
	}

	for(qw( eprint_status userid sword_depositor rev_number ))
	{
		$epdata->{$_} = $eprint->value( $_ );
	}

	$eprint->empty();
	$eprint->update( $epdata );
	$eprint->commit;
}

sub servicedocument
{
	my( $self ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;
	my $dataset = $repo->dataset( "eprint" );

	my $xml = $repo->xml;

	my $user = $repo->current_user;
	EPrints->abort( "unprotected" ) if !defined $user; # Rewrite foobar
	my $on_behalf_of = on_behalf_of( $repo, $r, $user );
	if( $on_behalf_of->{status} != OK )
	{
		return sword_error( $repo, $r, %$on_behalf_of );
	}
	$on_behalf_of = $on_behalf_of->{on_behalf_of};

# SERVICE and WORKSPACE DEFINITION

	my $service = $xml->create_element( "service", 
			xmlns => "http://www.w3.org/2007/app",
			"xmlns:atom" => "http://www.w3.org/2005/Atom",
			"xmlns:sword" => "http://purl.org/net/sword/",
			"xmlns:dcterms" => "http://purl.org/dc/terms/" );

	my $title = $repo->phrase( "archive_name" ) . ": " . $repo->phrase( "Plugin/Screen/Items:title" );

	my $workspace = $xml->create_data_element( "workspace", [
		[ "atom:title", $title ],
# SWORD LEVEL
		[ "sword:version", "2.0" ],
# SWORD VERBOSE	(Unsupported)
#		[ "sword:verbose", "true" ],
# SWORD NOOP (Unsupported)
#		[ "sword:noOp", "true" ],
	]);
	$service->appendChild( $workspace );

	my $collection = $xml->create_data_element( "collection", [
# COLLECTION TITLE
		[ "atom:title", $repo->dataset( "eprint" )->render_name ],
# COLLECTION POLICY
#		[ "sword:collectionPolicy", $service_conf->{sword_policy} ],
# COLLECTION MEDIATED
		[ "sword:mediation", "true" ],
# DCTERMS ABSTRACT
#		[ "dcterms:abstract", $service_conf->{dcterms_abstract} ],
# COLLECTION TREATMENT
#		[ "sword:treatment", $treatment ],
	], "href" => $repo->current_url( host => 1, path => "static", "id/contents" ),
	);
	$workspace->appendChild( $collection );

	if( $user->allow( "create_eprint" ) )
	{
		foreach my $plugin ($self->import_plugins( is_advertised => 1 ))
		{
			foreach my $mime_type (@{$plugin->param( "accept" )})
			{
				if( $mime_type =~ /^$PACKAGING_PREFIX(.+)$/ )
				{
					$collection->appendChild( $xml->create_data_element( "sword:acceptPackaging", $1 ) );
				}
				else
				{
					$collection->appendChild( $xml->create_data_element( "accept", $mime_type, alternate => "multipart-related" ) );
				}
			}
		}

		# we always accept simple files
		$collection->appendChild( $xml->create_data_element( "acceptPackaging", "http://purl.org/net/sword/package/Binary" ) );
		$collection->appendChild( $xml->create_data_element( "accept", "application/octet-stream", alternate => "multipart-related" ) );
	}
	else
	{
		$collection->appendChild( $xml->create_data_element( "accept" ) );
	}

	my $categories = $collection->appendChild( $xml->create_element( "categories", fixed => "yes" ) );
	foreach my $type ($dataset->field( "type" )->tags)
	{
		$categories->appendChild( $xml->create_element( "atom:category",
			scheme => $repo->config( "base_url" )."/data/eprint/type",
			term => $type,
		) );
	}
	foreach my $type ($dataset->field( "eprint_status" )->tags)
	{
		$categories->appendChild( $xml->create_element( "atom:category",
			scheme => EPrints::Const::EP_NS_DATA . "/eprint/eprint_status",
			term => $type,
		) );
	}

	my $content = "<?xml version='1.0' encoding='UTF-8'?>\n" .
		$xml->to_string( $service, indent => 1 );

	return $self->send_response(
		OK,
		'application/xtomsvc+xml; charset=utf-8',
		$content
	);
}

### Utility methods below

sub on_behalf_of
{
	my( $repo, $r, $user ) = @_;

	my $err = {
		status => HTTP_FORBIDDEN,
		href => "http://purl.org/net/sword/error/TargetOwnerUnknown",
		summary => "Target user unknown or no permission to act on-behalf-of",
	};

	my $on_behalf_of =
		$r->headers_in->{'On-Behalf-Of'} || # SWORD 2.0
		$r->headers_in->{'X-On-Behalf-Of'}; # SWORD 1.3

	return( OK, $user ) if !$on_behalf_of;

	my $owner = $repo->user_by_username( $on_behalf_of );

	return sword_error($repo, $r, %$err )
		if !defined $owner;
	return sword_error($repo, $r, %$err ) 
		if !$user->allow( "user/mediate", $owner );

	return( OK, $owner );
}

sub is_true
{
	return defined($_[0]) && lc($_[0]) eq "true";
}

sub is_false
{
	return defined($_[0]) && lc($_[0]) eq "false";
}

sub process_headers
{
	my( $self ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;

	my %response;
	$self->{headers} = \%response;

# X-Method (pseudo-PUTs etc. from POST)
	$self->{method} = uc($r->method);
	if( $self->method eq "POST" )
	{
		if( $r->headers_in->{'X-Method'} )
		{
			$self->{method} = uc($r->headers_in->{'X-Method'});
		}
		# or via Ruby-on-Rails "_method" query parameter
		my %q = URI::http->new( $r->unparsed_uri )->query_form;
		if( $q{_method} )
		{
			$self->{method} = uc($q{_method});
		}
	}

# In-Progress
	$response{in_progress} = is_true( $r->headers_in->{'In-Progress'} );

# X-Verbose
	$response{verbose} = is_true( $r->headers_in->{'X-Verbose'} );

# Content-Type	
	$response{content_type} = $r->headers_in->{'Content-Type'};
	$response{content_type} = "application/octet-stream"
		if !EPrints::Utils::is_set( $response{content_type} );
	( $response{mime_type}, my %params ) = @{(HTTP::Headers::Util::split_header_words($response{content_type}))[0]};
	$response{content_type_params} = \%params;

# Content-Length
	$response{content_length} = $r->headers_in->{'Content-Length'};

# Content-Range
	my $range = $r->headers_in->{'Content-Range'};
	if( defined $range )
	{
		if( $range =~ m{^(\d+)-(\d+)/(\d+|\*)$} && $1 <= $2 )
		{
			$response{content_range} = $range;
			$response{offset} = $1;
			$response{total} = $3;
			if( !defined $response{content_length} )
			{
				$response{content_length} = $2 - $1;
			}
		}
		else
		{
			return HTTP_RANGE_NOT_SATISFIABLE;
		}
	}

# Content-MD5	
	$response{content_md5} = $r->headers_in->{'Content-MD5'};

# Content-Disposition
	my @values = @{(HTTP::Headers::Util::split_header_words( $r->headers_in->{'Content-Disposition'} || '' ))[0] || []};
	for(my $i = 0; $i < @values; $i += 2)
	{
		if( $values[$i] eq "filename" )
		{
			$response{filename} = $values[$i+1];
		}
	}
	$response{filename} = "main.bin"
		if !EPrints::Utils::is_set( $response{filename} );
	($response{extension}) = $response{filename} =~ /((?:\.[^\.]+){1,2})$/;

# X-No-Op
	$response{no_op} = is_true( $r->headers_in->{'X-No-Op'} );

# X-Packaging
	$response{packaging} = 
		$r->headers_in->{'Packaging'} || # SWORD 2.0
		$r->headers_in->{'X-Packaging'} || # SWORD 1.3
		$r->headers_in->{'X-Format-Namespace'}; # SWORD 1.2

# Slug
	$response{slug} = $r->headers_in->{'Slug'};

# userAgent
	$response{user_agent} = $r->headers_in->{'User-Agent'};

# Metadata-relevant
	$response{metadata_relevant} =
		is_true($r->headers_in->{'Metadata-Relevant'}) || # SWORD 2.0
		is_true($r->headers_in->{'X-Override-Metadata'}); # SWORD 2.0a

# actions
	my $actions = $response{actions} = [];
#	push @$actions, "metadata" if $response{metadata_relevant};
	push @$actions, "unpack" if $response{packaging} && $response{packaging} eq "http://purl.org/net/sword/package/SimpleZip";
	$response{flags} = {map { $_ => 1 } @$actions};

	return OK;
}

sub sword_error
{
	my( $self, %opts ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;

	my $xml = generate_error_document( $repo, %opts );

	$opts{status} = HTTP_BAD_REQUEST if !defined $opts{status};

	$r->status( $opts{status} );

	return $self->send_response(
		$opts{status},
		'application/xml; charset=UTF-8',
		$xml
	);
}

# input_fh() failed
sub plugin_error
{
	my( $self, $plugin, $messages ) = @_;

	my $repo = $self->repository;

	$plugin->handler->message( "error", $@ ) if $@ ne "\n";

	my $ul = $repo->xml->create_element( "ul" );
	for(@{$messages}) {
		$ul->appendChild( $repo->xml->create_data_element( "li", $_ ) );
	}
	my $err = $repo->xhtml->to_xhtml( $ul );
	$repo->xml->dispose( $ul );

	return $self->sword_error(
		status => HTTP_INTERNAL_SERVER_ERROR,
		summary => $err
	);
}

# other helper functions:
sub generate_error_document
{
	my ( $repo, %opts ) = @_;

	my $xml = $repo->xml;

	$opts{href} = "http://eprints.org/sword/error/UnknownError"
		if !defined $opts{href};

	my $error = $xml->create_data_element( "sword:error", [
		[ "title", "ERROR" ],
		[ "updated", EPrints::Time::get_iso_timestamp() ],
		[ "generator", $repo->phrase( "archive_name" ),
			uri => "http://www.eprints.org/",
			version => EPrints->human_version,
		],
		[ "summary", $opts{summary} ],
		[ "sword:userAgent", $opts{user_agent} ],
	],
		"xmlns" => "http://www.w3.org/2005/Atom",
		"xmlns:sword" => "http://purl.org/net/sword/",
		href => $opts{href},
	);

	return "<?xml version='1.0' encoding='UTF-8'?>\n" .
		$xml->to_string( $error, indent => 1 );
}

sub send_response
{
	my( $self, $status, $content_type, $content ) = @_;

	my $r = $self->request;

	use bytes;

	$r->status( $status == OK ? HTTP_OK : $status );
	$r->content_type( $content_type );
	if( defined $content )
	{
		$r->err_headers_out->{'Content-Length'} = length $content;
		binmode(STDOUT, ":utf8");
		print $content;
	}

	return OK;
}

1;

=back

=head1 SEE ALSO

http://en.wikipedia.org/wiki/Create,_read,_update_and_delete

http://en.wikipedia.org/wiki/Content_negotiation

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

