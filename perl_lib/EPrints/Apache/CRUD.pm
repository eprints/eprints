=head1 NAME

EPrints::Apache::CRUD

=cut

package EPrints::Apache::CRUD;

use EPrints::Const qw( :http );
use MIME::Base64;
use HTTP::Headers::Util;
use Digest::MD5;
use EPrints::Apache::Auth;
use Apache2::Access;

our $PACKAGING_PREFIX = "sword:";

use strict;

sub _priv
{
	my( $r, $dataset ) = @_;

	my $dataobj = $r->pnotes->{dataobj};
	my $plugin = $r->pnotes->{plugin};
	my $field = $r->pnotes->{field};

	my $write = $r->method ne "GET" && $r->method ne "HEAD";

	my $priv;
	if( $r->method eq "POST" || $r->method eq "PUT" )
	{
		$priv = "edit";
	}
	elsif( $r->method eq "DELETE" )
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

	# for /XX/contents we always want dataobj/edit for POST/PUT/DELETE and not
	# POST/PUT/DELETE on the dataset we're working on
	if( defined $field )
	{
		if( $dataobj->isa( "EPrints::DataObj::Document" ) )
		{
			$dataobj = $dataobj->parent;
		}
		$dataset = $dataobj->get_dataset;
		if( $write )
		{
			$priv = "edit";
		}
	}

	if( $dataset->id ne $dataset->base_id )
	{
		$priv = join('/', $dataset->base_id, $dataset->id, $priv );
	}
	else
	{
		$priv = join('/', $dataset->base_id, $priv );
	}

	if( !defined $dataobj )
	{
		if( $write )
		{
			$priv = "create_eprint";
		}
		else
		{
			$priv = "items";
		}
	}

	return $priv;
}

# authentication
sub authen
{
	my( $r ) = @_;

	my $repo = $EPrints::HANDLE->current_repository;
	return HTTP_FORBIDDEN if !defined $repo;

	my $dataobj = $r->pnotes->{dataobj};
	my $dataset = $r->pnotes->{dataset};
	my $plugin = $r->pnotes->{plugin};

	my $write = $r->method ne "GET" && $r->method ne "HEAD";

	# POST, PUT, DELETE must authenticate
	if( $write )
	{
		return EPrints::Apache::Auth::authen( $r );
	}

	# a staff-plugin implicitly requires a user
	if( defined($plugin) && $plugin->param( "visible" ) eq "staff" )
	{
		return EPrints::Apache::Auth::authen( $r );
	}

	# /id/contents implicitly requires a user
	if( !defined $dataobj )
	{
		return EPrints::Apache::Auth::authen( $r );
	}

	# permission for GET/HEAD a document is via authen_doc/authz_doc
	if( !$write )
	{
		if( $dataobj->isa( "EPrints::DataObj::File" ) )
		{
			$dataobj = $dataobj->parent;
			$dataset = $dataobj->get_dataset;
		}
		if( $dataobj->isa( "EPrints::DataObj::Document" ) )
		{
			$r->pnotes->{document} = $dataobj;
			return EPrints::Apache::Auth::authen_doc( $r );
		}
	}

	my $priv = _priv( $r, $dataset );

	return OK if $repo->allow_anybody( $priv );

	return EPrints::Apache::Auth::authen( $r );
}

# authorisation
sub authz
{
	my( $r ) = @_;

	my $repo = $EPrints::HANDLE->current_repository;
	return HTTP_FORBIDDEN if !defined $repo;

	my $dataobj = $r->pnotes->{dataobj};
	my $dataset = $r->pnotes->{dataset};
	my $plugin = $r->pnotes->{plugin};

	my $user = $repo->current_user;

	my $write = $r->method ne "GET" && $r->method ne "HEAD";

	if( defined($plugin) && $plugin->param( "visible" ) eq "staff" )
	{
		if( $user->get_type ne "editor" && $user->get_type ne "admin" )
		{
			return HTTP_FORBIDDEN;
		}
	}

	# GET/HEAD a document
	if( defined $r->pnotes->{document} )
	{
		return EPrints::Apache::Auth::authz_doc( $r );
	}

	my $priv = _priv( $r, $dataset );

	return OK if $repo->allow_anybody( $priv );

	return HTTP_FORBIDDEN if !defined $user;

	if( $user->allow( $priv, $dataobj ) )
	{
		return OK;
	}

	return HTTP_FORBIDDEN;
}

=item $plugin = content_negotiate_best_plugin( $r )

Work out the best plugin to export/update an object based on the client-headers.

=cut

sub content_negotiate_best_plugin
{
	my( $r ) = @_;

	my $repo = EPrints->new->current_repository;

	my $dataset = $r->pnotes->{dataset};
	my $dataobj = $r->pnotes->{dataobj};
	my $uri = $r->pnotes->{uri};

	my $headers = process_headers( $repo, $r );

	my $write = $r->method eq 'POST' || $r->method eq 'PUT';

	my $accept_type = "dataobj/".$dataset->base_id;
	if( !defined $dataobj && !$write )
	{
		$accept_type = "list/".$dataset->base_id;
	}

	my $field;
	if( $uri eq "contents" )
	{
		if( $dataobj->isa( "EPrints::DataObj::EPrint" ) )
		{
			$field = $dataset->field( "documents" );
		}
		elsif( $dataobj->isa( "EPrints::DataObj::Document" ) )
		{
			$field = $dataset->field( "files" );
		}
		else
		{
			return( HTTP_NOT_FOUND, undef );
		}
		$dataset = $repo->dataset( $field->property( "datasetid" ) );

		$r->pnotes->{dataset} = $dataset;
		$r->pnotes->{field} = $field;
		if( $write )
		{
			$accept_type = "dataobj/".$dataset->base_id;
		}
		else
		{
			$accept_type = "list/".$dataset->base_id;
		}
	}
	elsif( length($uri) )
	{
		return( HTTP_NOT_FOUND, undef );
	}

	return( OK, undef ) if $r->method eq "DELETE";

	if( defined(my $package = $headers->{packaging}) )
	{
		my $plugin;
		if( $write )
		{
			($plugin) = $repo->get_plugins(
				type => "Import",
				can_accept => $PACKAGING_PREFIX.$package,
				can_produce => $accept_type,
				can_action => $headers->{actions},
			);
		}
		else
		{
			($plugin) = $repo->get_plugins(
				type => "Export",
				can_accept => $accept_type,
				can_produce => $PACKAGING_PREFIX.$package,
			);
		}
		return( OK, $plugin );
	}

	my @plugins;
	if( $write )
	{
		@plugins = $repo->get_plugins(
			type => "Import",
			can_produce => $accept_type,
			can_action => $headers->{actions},
		);
	}
	else
	{
		@plugins = $repo->get_plugins(
			type => "Export",
			can_accept => $accept_type,
		);
	}

	my %pset;

	foreach my $plugin ( @plugins )
	{
		my $mimetype = $plugin->get_type eq "Export" ?
			[ $plugin->param( "mimetype" ) ] :
			$plugin->param( "accept" );
		$mimetype = join ',', @$mimetype;
		for( HTTP::Headers::Util::split_header_words( $mimetype ) )
		{
			my( $type, undef, %params ) = @$_;

			push @{$pset{$type}}, {
				%params,
				plugin => $plugin,
				q => $plugin->param( "qs" ),
			};
		}
	}
	# sort plugins internally by q
	for(values(%pset))
	{
		@$_ = sort { $b->{q} <=> $a->{q} } @$_;
	}
	# sort supported types by the highest plugin score
	my @pset_order = sort {
		$pset{$b}->[0]->{q} <=> $pset{$a}->[0]->{q}
	} keys %pset;

	my $accept;
	if( $write )
	{
		$accept = $r->headers_in->{'Content-Type'};
	}
	else
	{
		if( !defined $field )
		{
			# summary page is higher priority than anything else
			unshift @pset_order, "text/html";
			unshift @{$pset{"text/html"}}, {
				charset => 'utf-8',
				q => 1.0,
				plugin => $repo->plugin( "Export::SummaryPage" ),
			};
			#chrome
			unshift @pset_order, "application/xhtml+xml";
			unshift @{$pset{"application/xhtml+xml"}}, {
				charset => 'utf-8',
				q => 1.0,
				plugin => $repo->plugin( "Export::SummaryPage" ),
			};
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
			$match = (sort { $b->{q} <=> $a->{q} } @$plugins)[0]->{plugin};
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

	return( OK,  $match );
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

	return [ map { delete $_->{mime_type}, undef, %$_ } @accept ];
}

sub handler
{
	my( $r ) = @_;

	my $repo = EPrints->new->current_repository;
	my $user = $repo->current_user;

	my( $rc, $owner ) = on_behalf_of( $repo, $r, $user );
	return $rc if $rc != OK;

	my $write = $r->method ne "GET" && $r->method ne "HEAD";

	my $dataset = $r->pnotes->{dataset};
	my $dataobj = $r->pnotes->{dataobj};
	my $plugin = $r->pnotes->{plugin};
	my $field = $r->pnotes->{field};
	my $uri = $r->pnotes->{uri};

	# Subject URI's redirect to the top of that particular subject tree
	# rather than the node in the tree. (the ancestor with "ROOT" as a parent).
	if( $dataset->id eq "subject" )
	{
ANCESTORS: foreach my $anc_subject_id ( @{$dataobj->get_value( "ancestors" )} )
	   {
		   my $anc_subject = $dataset->dataobj($anc_subject_id);
		   next ANCESTORS if( !$anc_subject );
		   next ANCESTORS if( !$anc_subject->is_set( "parents" ) );
		   foreach my $anc_subject_parent_id ( @{$anc_subject->get_value( "parents" )} )
		   {
			   if( $anc_subject_parent_id eq "ROOT" )
			   {
				   $dataobj = $anc_subject;
				   last ANCESTORS;
			   }
		   }
	   }
	}

	if( $r->method eq "DELETE" )
	{
		return DELETE( $r, $owner );
	}
	elsif( $r->method eq "POST" )
	{
		return POST( $r, $owner );
	}
	elsif( $r->method eq "PUT" )
	{
		return PUT( $r, $owner );
	}
	# GET/HEAD XX/contents
	elsif( defined $field )
	{
		if( $r->pnotes->{mime_type} eq "*/*" )
		{
			if( $dataobj->isa( "EPrints::DataObj::EPrint" ) )
			{
				my @docs = $dataobj->get_all_documents;
				if( @docs == 0 )
				{
					return HTTP_NOT_FOUND;
				}
				elsif( @docs == 1 )
				{
					$dataobj = $docs[0];
				}
				else
				{
					return sword_error($repo, $r,
						status => HTTP_NOT_ACCEPTABLE,
						summary => "More than one resource at this location",
					);
				}
			}
			return EPrints::Apache::Rewrite::redir_see_other( $r, $dataobj->get_url );
		}

		# negotiation failed
		return HTTP_UNSUPPORTED_MEDIA_TYPE if !defined $plugin;

		return GET( $r, $owner );
	}
	# GET/HEAD /id/contents
	elsif( !defined $dataobj )
	{
		# force Atom if match was */*
		if( $r->pnotes->{mime_type} eq "*/*" )
		{
			$plugin = $repo->plugin( "Export::Atom" );
		}

		# negotiation failed
		return HTTP_UNSUPPORTED_MEDIA_TYPE if !defined $plugin;

		return GET( $r, $owner );
	}

	# GET / HEAD
	return HTTP_UNSUPPORTED_MEDIA_TYPE if !defined $plugin;

	my $url = $dataobj->get_url;
	if( $plugin->get_subtype eq "SummaryPage" && defined $url )
	{
		if( $dataset->base_id eq "eprint" && $dataset->id ne "archive" )
		{
			$url = $dataobj->get_control_url;
		}
		return EPrints::Apache::Rewrite::redir_see_other( $r, $url );
	}

	if( $dataset->base_id eq "subject" )
	{
		return redir_see_other( $r, $plugin->dataobj_export_url( $dataobj ) );
	}

	return GET( $r, $owner );
}

sub DELETE
{
	my( $r ) = @_;

	my $repo = $EPrints::HANDLE->current_repository;
	return NOT_FOUND if !defined $repo;

	my $user = $repo->current_user;

	my $dataobj = $r->pnotes->{dataobj};
	my $dataset = $r->pnotes->{dataset};
	my $plugin = $r->pnotes->{plugin};
	my $field = $r->pnotes->{field};

	# /id/contents
	return HTTP_METHOD_NOT_ALLOWED if !defined $dataobj;

	# /XX/contents
	return HTTP_METHOD_NOT_ALLOWED if defined $field;

	# obtain lock, if available
	my $lock_obj = $dataobj;
	while( defined($lock_obj) && !$lock_obj->can( "obtain_lock" ) )
	{
		$lock_obj = $lock_obj->parent;
	}
	if( defined $lock_obj )
	{
		$lock_obj->obtain_lock( $user )
			or return HTTP_CONFLICT;
	}

	if( defined $field )
	{
		foreach my $item (@{$field->get_value( $dataobj )})
		{
			$item->remove;
		}
	}
#	elsif( $dataobj->isa( "EPrints::DataObj::EPrint" ) )
#	{
#		$dataobj->move_to_deletion;
#	}
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

sub GET
{
	my( $r, $owner ) = @_;

	my $repo = $EPrints::HANDLE->current_repository;
	return NOT_FOUND if !defined $repo;

	my $dataobj = $r->pnotes->{dataobj};
	my $dataset = $r->pnotes->{dataset};
	my $plugin = $r->pnotes->{plugin};
	my $field = $r->pnotes->{field};

	my %args = %{$plugin->param( "arguments" )};
	# fetch the plugin arguments, if any
	foreach my $argname (keys %args)
	{
		if( defined $repo->param( $argname ) )
		{
			$args{$argname} = $repo->param( $argname );
		}
	}

	$r->content_type( $plugin->param( "mimetype" ) );
	$plugin->initialise_fh( \*STDOUT );
	if( !defined $dataobj )
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

		$r->content_type( $plugin->param( "mime_type" ) );
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
	elsif( $field )
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
	else
	{
		# set Last-Modified header for individual objects
		if( my $field = $dataset->get_datestamp_field() )
		{
			my $datestamp = $field->get_value( $dataobj );
			$r->headers_out->{'Last-Modified'} = Apache2::Util::ht_time(
				$r->pool,
				EPrints::Time::datestring_to_timet( undef, $datestamp )
			);
		}
		my $output = $plugin->output_dataobj( $dataobj,
			%args,
			fh => \*STDOUT,
		);
		# optional for output_dataobj to support 'fh'
		print $output if defined $output;
	}

	return OK;
}

sub POST 
{
	my( $r, $owner ) = @_;

	my $repo = $EPrints::HANDLE->current_repository();
	return NOT_FOUND if !defined $repo;

	my $user = $repo->current_user;

	my $dataobj = $r->pnotes->{dataobj};
	my $dataset = $r->pnotes->{dataset};
	my $plugin = $r->pnotes->{plugin};
	my $field = $r->pnotes->{field};

	# can only post to XX/contents and /id/contents
	if( defined($dataobj) && !defined $field )
	{
		return HTTP_METHOD_NOT_ALLOWED;
	}

	my $headers = process_headers( $repo, $r );

	if( $headers->{packaging} && !defined $plugin )
	{
		return sword_error( $repo, $r,
			status => HTTP_BAD_REQUEST,
			href => "http://purl.org/net/sword/error/ErrorContent",
			summary => "No support for packaging '$headers->{packaging}'",
		);
	}

	# we can import any file type into /contents
	if( !defined $plugin )
	{
		$plugin = $repo->plugin( "Import::Binary" );
	}

	my( $rc, $tmpfile ) = _read_content( $repo, $r, $headers );
	return $rc if $rc != OK;

	my @items;

	my $status;
	my $rev_number;
	if( UNIVERSAL::isa( $dataobj, "EPrints::DataObj::EPrint" ) )
	{
		$status = $dataobj->value( "eprint_status" );
		$rev_number = $dataobj->value( "rev_number" );
	}
	elsif( !defined $dataobj )
	{
		$status = $headers->{in_progress} ? "inbox" : "buffer";
		$status = "archive" if ($repo->config("skip_buffer") and $status eq "buffer");
	}

	my @messages;

	$plugin->{parse_only} = 1;
	$plugin->set_handler( EPrints::CLIProcessor->new(
		message => sub { push @messages, $_[1] },
		epdata_to_dataobj => sub {
			my( $epdata ) = @_;

			if( $dataset->base_id eq "eprint" )
			{
				$epdata->{userid} = $owner->id;
				$epdata->{sword_depositor} = $user->id;
				$epdata->{eprint_status} = $status;
				$epdata->{rev_number} = $rev_number;
			}

			if( defined $dataobj )
			{
				push @items, $dataobj->create_subdataobj( $field->name, $epdata );
			}
			else
			{
				push @items, $dataset->create_dataobj( $epdata );
			}

			return $items[$#items];
		}
	) );

	my $atom = $repo->plugin( "Export::Atom" );

	my %content_type_params;
	for(keys %{$headers->{content_type_params}})
	{
		next if !$plugin->has_argument( $_ );
		$content_type_params{$_} = $headers->{content_type_params}->{$_};
	}

	my $list = eval { $plugin->input_fh(
		%content_type_params,
		dataset => $dataset,
		fh => $tmpfile,
		filename => $headers->{filename},
		mime_type => $headers->{mime_type},
		content_type => $headers->{content_type},
		actions => $headers->{actions},
	) };
	return plugin_error( $repo, $r, $plugin, \@messages ) if !defined $list;

	EPrints->abort( "Import plugin didn't create anything" ) if !@items;

	if( $headers->{metadata_relevant} )
	{
		my $file = $items[0];
		if( $file->isa( "EPrints::DataObj::EPrint" ) )
		{
			$file = ($file->get_all_documents())[0];
		}
		if( defined $file && $file->isa( "EPrints::DataObj::Document" ) )
		{
			$file = $file->stored_file( $file->value( "main" ) );
		}
		if( defined $file && $file->isa( "EPrints::DataObj::File" ) )
		{
			metadata_relevant( $repo, $r, $file );
		}
	}

	# producing more than one item (potentially)
	if( defined $dataobj && $headers->{flags}->{unpack} )
	{
		$list = EPrints::List->new(
			session => $repo,
			dataset => $items[0]->get_dataset,
			ids => [map { $_->id } @items]
		);
		return send_response( $r,
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

		return send_response( $r,
			HTTP_CREATED,
			$atom->param( "mimetype" ),
			$atom->output_dataobj( $items[0] ),
		);
	}
}

sub PUT 
{
	my( $r, $owner ) = @_;

	my $repo = $EPrints::HANDLE->current_repository();
	return NOT_FOUND if !defined $repo;

	my $user = $repo->current_user;

	my $dataobj = $r->pnotes->{dataobj};
	my $dataset = $r->pnotes->{dataset};
	my $plugin = $r->pnotes->{plugin};
	my $field = $r->pnotes->{field};

	# need an object to update
	return HTTP_METHOD_NOT_ALLOWED if !defined $dataobj;

	my $headers = process_headers( $repo, $r );

	if( $headers->{packaging} && !defined $plugin )
	{
		return sword_error( $repo, $r,
			status => HTTP_BAD_REQUEST,
			href => "http://purl.org/net/sword/error/ErrorContent",
			summary => "No support for packaging '$headers->{packaging}'",
		);
	}

	my( $rc, $tmpfile ) = _read_content( $repo, $r, $headers );
	return $rc if $rc != OK;

	if( $dataobj->isa( "EPrints::DataObj::File" ) )
	{
		my $rc = $dataobj->set_file( $tmpfile, -s $tmpfile );
		return HTTP_INTERNAL_SERVER_ERROR if !defined $rc;

		$dataobj->set_value( "filename", $headers->{filename} );
		$dataobj->set_value( "mime_type", $headers->{mime_type} );
		$dataobj->commit;

		return OK;
	}

	# we can import any file type into /contents
	if( !defined $plugin && defined $field )
	{
		$plugin = $repo->plugin( "Import::Binary" );
	}

	return HTTP_UNSUPPORTED_MEDIA_TYPE if !defined $plugin;

	my $status;
	if( $dataobj->isa( "EPrints::DataObj::EPrint" ) )
	{
		$status = $dataobj->value( "eprint_status" );
	}

	my @items;

	my @messages;

	$plugin->{parse_only} = 1;
	$plugin->set_handler( EPrints::CLIProcessor->new(
		message => sub { push @messages, $_[1] },
		epdata_to_dataobj => sub {
			my( $epdata ) = @_;

			my $new_status = delete $epdata->{eprint_status};
			if( $dataobj->isa( "EPrints::DataObj::EPrint" ) )
			{
				$epdata->{userid} = $owner->id;
				$epdata->{sword_depositor} = $user->id;
				$epdata->{eprint_status} = $status;
				$epdata->{rev_number} = $dataobj->value( "rev_number" );
			}

			if( defined $field )
			{
				# PUT /XX/contents implies DELETE existing contents
				if( !@items )
				{
					$_->remove for @{$field->get_value( $dataobj )};
				}
				push @items, $dataobj->create_subdataobj( $field->name, $epdata );
			}
			else
			{
				@items = ($dataobj);

				$dataobj->empty();
				foreach my $fieldname (keys %{$epdata})
				{
					next if !$dataset->has_field( $fieldname );
					my $f = $dataset->field( $fieldname );
					next if !$f->property( "import" );
					next if $f->isa( "EPrints::MetaField::Subobject" );

					$f->set_value( $dataobj, $epdata->{$fieldname} );
				}
				if( EPrints::Utils::is_set( $new_status ) )
				{
					my $priv = "eprint/$status/move_$new_status";
					if( $user->allow( $priv, $dataobj ) )
					{
						$dataobj->commit;
						$dataobj->_transfer( $new_status );
					}
				}
				$dataobj->commit;
			}
			return undef;
		}
	) );

	my $list = eval { $plugin->input_fh(
		fh => $tmpfile,
		dataset => $dataset,
		filename => $headers->{filename},
		mime_type => $headers->{content_type},
		actions => $headers->{actions},
	) };
	return plugin_error( $repo, $r, $plugin, \@messages ) if !defined $list;

	EPrints->abort( "Import plugin didn't create anything" ) if !@items;

	if( defined $field && $headers->{metadata_relevant} )
	{
		my $file = $items[0];
		if( $file->isa( "EPrints::DataObj::EPrint" ) )
		{
			$file = ($file->get_all_documents())[0];
		}
		if( defined $file && $file->isa( "EPrints::DataObj::Document" ) )
		{
			$file = $file->stored_file( $file->value( "main" ) );
		}
		if( defined $file )
		{
			metadata_relevant( $repo, $r, $file );
		}
	}

	return OK;
}

sub metadata_relevant
{
	my( $repo, $r, $file ) = @_;

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
		$plugin->{parse_only} = 1;
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

	foreach my $fieldname (keys %$epdata)
	{
		my $f = $dataset->field( $fieldname );
		my $v = $epdata->{$fieldname};
		next if $f->isa( "EPrints::MetaField::Subobject" );
		$f->set_value( $eprint, $v );
	}

	$eprint->commit;
}

sub _read_content
{
	my( $repo, $r, $headers ) = @_;

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
		return( sword_error( $repo, $r,
			status => HTTP_PRECONDITION_FAILED,
			href => "http://purl.org/net/sword/error/ErrorChecksumMismatch",
			summary => "MD5 digest mismatch between headers and content",
		), undef );
	}

	return( OK, $tmpfile );
}

sub servicedocument
{
	my( $r ) = @_;

	my $repo = EPrints->new->current_repository;
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
		foreach my $plugin (plugins( $repo ))
		{
			foreach my $mime_type (@{$plugin->param( "accept" )})
			{
				if( $mime_type =~ /^$PACKAGING_PREFIX(.+)$/ )
				{
					$collection->appendChild( $xml->create_data_element( "acceptPackaging", $1 ) );
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
	foreach my $type ($repo->get_types( "eprint" ))
	{
		$categories->appendChild( $xml->create_element( "atom:category",
			scheme => $repo->config( "base_url" )."/data/eprint/type/",
			term => $type,
		) );
	}
	foreach my $type (qw( inbox buffer archive deletion))
	{
		$categories->appendChild( $xml->create_element( "atom:category",
			scheme => $repo->config( "base_url" )."/data/eprint/status/",
			term => $type,
		) );
	}

	my $content = "<?xml version='1.0' encoding='UTF-8'?>\n" .
		$xml->to_string( $service, indent => 1 );

	return send_response( $r,
		OK,
		'application/xtomsvc+xml; charset=UTF-8',
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
	my ( $repo, $r ) = @_;

	my %response;

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

	return \%response;
}

sub sword_error
{
	my( $repo, $r, %opts ) = @_;

	my $xml = generate_error_document( $repo, %opts );

	$opts{status} = HTTP_BAD_REQUEST if !defined $opts{status};

	$r->status( $opts{status} );

	return send_response( $r,
		$opts{status},
		'application/xml; charset=UTF-8',
		$xml
	);
}

# input_fh() failed
sub plugin_error
{
	my( $repo, $r, $plugin, $messages ) = @_;

	$plugin->handler->message( "error", $@ ) if $@ ne "\n";
	my $ul = $repo->xml->create_element( "ul" );
	for(@{$messages}) {
		$ul->appendChild( $repo->xml->create_data_element( "li", $_ ) );
	}
	my $err = $repo->xhtml->to_xhtml( $ul );
	$repo->xml->dispose( $ul );
	return sword_error( $repo, $r,
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

sub plugins
{
	my( $repo, %constraints ) = @_;

	return $repo->get_plugins(
		type => "Import",
		can_produce => "dataobj/eprint",
		is_visible => "all",
		is_advertised => 1,
		%constraints
	);
}

sub send_response
{
	my( $r, $status, $content_type, $content ) = @_;

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

