package EPrints::Plugin::Controller::CRUD;

use strict;
use EPrints;
use EPrints::Const qw( :http );
use MIME::Base64;
use HTTP::Headers::Util;
use Digest::MD5;
use EPrints::Apache::Auth;
use Apache2::Access;

our @ISA = qw/ EPrints::Plugin::Controller /;

# sf2 - removed CRUD_SCOPE_USER_CONTENTS ( => 1 )
#	removed CRUD_SCOPE_CONTENTS ( => 5 )
#	removed CRUD_SCOPE_SERVICEDOCUMENT ( => 6)
use constant {
	CRUD_SCOPE_DATASET => 2,
	CRUD_SCOPE_DATAOBJ => 3,
	CRUD_SCOPE_FIELD => 4,
	CRUD_SCOPE_FIELD_FILE => 7,
};


#
# (this is a refactored/generalised version of 3.3's Apache::CRUD (for SWORD2))
#
# TODO
#
# some methods here should be moved to @ISA coz they will likely be used by other controllers (eg read_content, content_nego etc.)
# 

sub new
{
	my( $class, %params ) = @_;
	
	$params{priority} = 50;

	my $self = $class->SUPER::new(%params);
	
	# matches /data/datasetid?/dataobjid?/fieldid?/pos?
	$self->register_endpoint(
		qr{^/data/(?:([^/]+)(?:/([^/]+)(?:/([^/]+)(?:/([^/]+)?))?)?)$},
		qw/ datasetid dataobjid fieldid posid/,
	);

	return $self;
}

sub init
{
	my( $self ) = @_;

	$self->{options} = [qw( GET HEAD OPTIONS )];

	if( !defined $self->{datasetid} )
	{
		return HTTP_NOT_FOUND;
	}
	
	my $repo = $self->repository;

	# /id/{datasetid}
	$self->{dataset} = $repo->dataset( $self->{datasetid} );
	if( !defined $self->{dataset} )
	{
		return HTTP_NOT_FOUND;
	}
	$self->{options} = [qw( GET HEAD OPTIONS )];
	
	if( !$self->{dataset}->property( 'read-only' ) )
	{
		push @{$self->{options}}, (qw( POST ));
	}
	$self->{scope} = CRUD_SCOPE_DATASET;

	# /id/{datasetid}/{dataobjid}
	if( defined $self->{dataobjid} )
	{
		$self->{dataobj} = $self->{dataset}->dataobj( $self->{dataobjid} );

		# adjust /id/eprint/23 to /id/archive/23
		# elf->{dataset} = $self{dataobj}->dataset if defined $self{dataobj};
		$self->{options} = [qw( GET HEAD OPTIONS )];
		if( !$self->{dataset}->property( 'read-only' ) )
		{
			push @{$self->{options}}, (qw( PUT PATCH DELETE ));
		}
		$self->{scope} = CRUD_SCOPE_DATAOBJ;
	}
	
	# /id/{datasetid}/{dataobjid}/{fieldname}[/{posid}]
	if( defined $self->{fieldid} )
	{
		if( !$self->{dataset}->has_field( $self->{fieldid} ) )
		{
			return HTTP_NOT_FOUND;
		}
		
		$self->{field} = $self->{dataset}->field( $self->{fieldid} );

		# if file is of type 'file' things work differently: we need to know the position of the file 
		# to replace (or /0 for a single field)

		# TODO maybe we should still allow to post directly to the fieldname (/id/image/3/{some 'file' field}/)
		if( $self->{field}->isa( 'EPrints::MetaField::File' ) )
		{
			if( !defined $self->{posid} || $self->{posid} !~ /^\d+$/ )
			{
				# position must be defined for FILE queries
				return HTTP_BAD_REQUEST;
			}
			$self->{options} = [qw( GET HEAD OPTIONS )];
			
			if( !$self->{dataset}->property( 'read-only' ) )
			{
				push @{$self->{options}}, (qw( POST ));
			}
			$self->{scope} = CRUD_SCOPE_FIELD_FILE;
			
#			# sf2 - debug file uploader
#
#			sf2: not good cos this consumes the POST param (ie. an uploaded file!...)
#
#			print STDERR "FIELD_FILE\n";
#
#			if( defined $repo->query->param( 'datafile' ) )
#			{
#				print STDERR "DATAFILE DEFINED\n";
#			}
#			else
#			{
#				print STDERR "DATAFILE NOT DEFINED :((\n";
#			}
		}
		else
		{
			$self->{options} = [qw( GET HEAD OPTIONS )];
			
			if( !$self->{dataset}->property( 'read-only' ) )
			{
				push @{$self->{options}}, (qw( PUT PATCH ));
			}
			$self->{scope} = CRUD_SCOPE_FIELD;
		}
	}

	
	if( $self->dataset->property( 'read-only' ) && $self->is_write )
	{
		return HTTP_METHOD_NOT_ALLOWED;
	}

	return EPrints::Const::HTTP_OK;
}

sub header_parser
{
	my( $self ) = @_;

	my $rc = $self->SUPER::header_parser;
	return $rc if $rc != OK;

	if( !defined $self->{plugin} )
	{
		$self->{plugin} = $self->content_negotiate_best_plugin;
	}

	return OK;
}


sub auth
{
	my( $self ) = @_;

	return EPrints::Apache::Auth::authen_dataobj_action(
		repository => $self->repository,
		request => $self->request,
		dataobj => $self->dataobj,
		dataset => $self->dataset,
		action => $self->action
	);
}	

sub authz
{
	my( $self ) = @_;

	return EPrints::Apache::Auth::authz_dataobj_action(
		repository => $self->repository,
		request => $self->request,
		dataobj => $self->dataobj,
		dataset => $self->dataset,
		action => $self->action
	);
}


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


=item @verbs = $crud->options()

Returns the available HTTP verbs for the current request.

=cut

sub options { @{$_[0]->{options}} }

=item $plugin = $crud->plugin()

Returns the current plugin (if available).

=cut

sub plugin { $_[0]->{plugin} }


=item $accept_type = $crud->accept_type()

Returns the EPrints type for the current request.

=cut

sub accept_type
{
	my( $self ) = @_;

	if( $self->method eq 'POST' && $self->scope == CRUD_SCOPE_FIELD_FILE )
	{
		# woot new file!
		return "dataobj/file";
	}

	my $accept_type = $self->dataset->base_id;
	if(
		$self->is_write ||
		$self->scope == CRUD_SCOPE_DATAOBJ
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

# returns the requested 'action' on the dataset/dataobj (e.g. 'view')
# privs are generated and processed internally from that 'action'
sub action
{
	my( $self ) = @_;

	# caching: otherwise called by authen() then authz()
	return $self->{".action"} if( exists $self->{".action"} );

	my $r = $self->request;
	my $dataset = $self->dataset;
	my $dataobj = $self->dataobj;
	my $plugin = $self->plugin;
	my $field = $self->field;

	my $action;
	if( $self->method eq "POST" )
	{
		if( $self->scope == CRUD_SCOPE_FIELD_FILE || $self->scope == CRUD_SCOPE_FIELD )
		{
			$action = "edit";
		}
		else
		{
			$action = "create";
		}
	}
	elsif( $self->method eq "PUT" )
	{
		if( $self->scope == CRUD_SCOPE_DATAOBJ && !defined $dataobj )
		{
			$action = "upsert";
		}
		else
		{
			$action = "edit";
		}
	}
	elsif( $self->method eq "PATCH" )
	{
		$action = "edit";
	}
	elsif( $self->method eq "DELETE" )
	{
		$action = "destroy";
	}
	elsif( $self->method eq "GET" && $self->scope == CRUD_SCOPE_DATASET )
	{
		$action = "search";
	}
	elsif( defined($plugin) && $plugin->get_subtype ne "SummaryPage" )
	{
		$action = "export";
	}
	else
	{
		$action = "view";
	}

	$self->repository->debug_log( "crud", "action '%s' selected", $action );

	$self->{".action"} = $action;
	return $action;
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

	my $ctx = $self->header( 'Content-MD5' ) ? Digest::MD5->new : undef;

	my $extension = $self->filename =~ /((?:\.[^\.]+){1,2})$/;

	my $tmpfile = File::Temp->new( SUFFIX => $extension, UNLINK => 0 );
	binmode($tmpfile);

	my $len = 0;

	# multipart/form-data
	my $mime_type = $r->pnotes( 'mime_type' );
	if( defined $mime_type && $mime_type eq 'multipart/form-data' )
	{
		# file uploader?
		if( defined ( my $file = $repo->param( 'file' ) ) )
		{
			printf STDERR "CRUD: File uploader? %s >> %s\n\n", "$tmpfile", "$file";

			binmode( $file );

			while( <$file> )
			{
				print $tmpfile $_;
				$len += length($_);
				$ctx->add( $_ ) if defined $ctx;
			}
		}
	}
	# CGI.pm may have consumed the POSTDATA (if another sub-process called $repo->query->param for instance)
	# it stored the data in $method . "DATA" for PUT and POST - PATCH method doesn't seem supported by CGI
	elsif( $repo->{query} && defined $repo->query->param( $self->method.'DATA' ) )
	{
		# TODO fix this... also writing unbuffered string to file, nem jo

		$repo->debug_log( "crud", "CRUD saving the day by getting postdata thru query_string" );

		my $param = $self->method."DATA";
		my $postdata = $repo->query->param( $param );
		print $tmpfile $postdata;
		$len += length($postdata);
		$ctx->add( $postdata ) if defined $ctx;
	}
	else
	{
		$repo->debug_log( "crud", "reading POSTDATA" );

		while($r->read(my $buffer, 4096*4)) {
			$len += length($buffer);
			$ctx->add( $buffer ) if defined $ctx;
			print $tmpfile $buffer;
		}
	}
	seek($tmpfile,0,0);

	if( defined $ctx && $ctx->hexdigest ne $self->header( 'Content-MD5' ) )
	{
		# TODO sf2 - must return HTTP_PRECONDITION_FAILED;
		return undef;
	}

	return $tmpfile;
}

sub parse_input
{
	my( $self, $plugin, $f, %params ) = @_;

	my $repo = $self->repository;

	my @messages;
	my $count = 0;

	$plugin->set_handler( EPrints::CLIProcessor->new(
		message => sub { push @messages, $_[1] },
		epdata_to_dataobj => sub { ++$count; &$f },
		) );

	my $tmpfile = $self->_read_content();
	return undef if !defined $tmpfile;

	my( $mime_type, %http_params ) = @{(HTTP::Headers::Util::split_header_words( $self->header( 'Content-Type' ) ))[0]};

	my %content_type_params;
	for( keys %http_params )
	{
		next if !$plugin->has_argument( $_ );
		$content_type_params{$_} = $http_params{$_};
	}

	my $list = eval { $plugin->input_fh(
		%content_type_params,
		dataset => $self->dataset,
		fh => $tmpfile,
		filename => $self->filename,
		mime_type => $mime_type,
		content_type => $self->header( 'Content-Type' ),
		%params,
	) };

	return $list;

=pod
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
=cut
}

sub create_dataobj
{
	my( $self, $epdata ) = @_;

	$epdata = {} if !defined $epdata;

	my $repo = $self->repository;
	my $dataset = $self->dataset;

	local $repo->{config}->{enable_import_fields} = 1;

	$epdata->{$dataset->key_field->name} = $self->{dataobjid};

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
	
	return undef if $self->method eq "DELETE";

	my $r = $self->request;
	my $repo = $self->repository;
	my $dataset = $self->dataset;
	my $accept_type = $self->accept_type;

	my @plugins;
	if( $self->is_write )
	{
		@plugins = $self->import_plugins();
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
		$accept = $self->header( 'Content-Type' );
	}
	else
	{
=pod
		# summary page is higher priority than anything else for /id/eprint/23
		# and /id/contents
		if( $self->scope == CRUD_SCOPE_DATAOBJ && defined ( my $plugin = $repo->plugin( 'Export::SummaryPage' ) ) )
		{
#			my $plugin = $repo->plugin( "Export::SummaryPage" );
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
=cut
		$accept = $self->header( 'Accept' );
	}

	my @accept = EPrints::Utils::parse_media_range( $accept || "" );

	my $match;
	CHOICE: foreach my $choice ( @accept )
	{
		my( $mime_type, undef, %params ) = @$choice;
		my( $type, $subtype ) = split '/', $mime_type;

		$repo->debug_log( "crud", "processing mime type %s", $mime_type );

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

	if( $match )
	{
		$repo->debug_log( "crud", "Selected plug-ing '%s'", $match->get_id );
	}

	return $match;
}

# TODO/sf2: should be global (property of DataObj or DataSet)
sub generate_etag
{
	my( $self, $dataobj ) = @_;

	use bytes;
	my $ctx = Digest::MD5->new;
	$ctx->add( $dataobj->internal_uri );
	$ctx->add( $dataobj->revision );
	return $ctx->hexdigest;
}


sub PATCH { &PUT }

sub HEAD { &GET }

sub OPTIONS { &GET }

=item $rc = $crud->DELETE()

Handle DELETE requests.

=over 4

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

	if( $self->scope == CRUD_SCOPE_DATAOBJ )
	{
		$dataobj->remove;
	}
	else
	{
		return HTTP_METHOD_NOT_ALLOWED;
	}

	if( defined $lock_obj && $lock_obj ne $dataobj )
	{
		$lock_obj->remove_lock( $user );
	}

	return HTTP_NO_CONTENT;
}

=item $rc = $crud->GET()

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
	my( $self ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;
	my $dataset = $self->dataset;
	my $dataobj = $self->dataobj;
	my $field = $self->field;
	my $plugin = $self->plugin;
		
	$r->err_headers_out->{Allow} = join ',', $self->options;

	# what to do when the user doesn't ask for a specific content type
	if( $r->pnotes->{mime_type} eq "*/*" )
	{
		if( $self->scope == CRUD_SCOPE_FIELD_FILE )
		{
			# then we need to output the content of the file...

			my $values = $field->get_value( $dataobj );
			$values = ref( $values ) eq 'ARRAY' ? $values : [$values];

			my $selected_file = $values->[$self->{posid}];

			if( defined $selected_file )
			{
				$repo->debug_log( "crud", "redirecting to %s", $selected_file->get_url );
				return EPrints::Apache::Rewrite::redir_see_other( $r, $selected_file->get_url );
			}

			return HTTP_NOT_FOUND;
		}
		elsif( $self->scope == CRUD_SCOPE_DATAOBJ )
		{

		}
	}

# TODO/sf2 - 406 the response SHOULD include an entity containing a list of available entity characteristics and locations
	return HTTP_NOT_ACCEPTABLE if( !defined $plugin );
	
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

	if( $self->scope == CRUD_SCOPE_DATASET )
	{
		my $indexOffset = $repo->param( "indexOffset" ) || 0;
		
		if( $indexOffset !~ /^\d+$/ )
		{
			$indexOffset = 0;
		}
		
		my $page_size = $repo->param( "pageSize" ) || 20;
		
		if( $page_size !~ /^\d+$/ )
		{
			$page_size = 20;
		}

		my $base = $repo->current_url( host => 1 );
		my $next = $base->clone;
		$next->query_form( indexOffset => $indexOffset + $page_size );
		my $previous = $base->clone;
		$previous->query_form( indexOffset => $indexOffset - $page_size );

		my $list;
		if( $repo->param( 'q' ) )
		{
			# Xapian
			$list = $self->search;
		}
		else
		{
			$list = $dataset->search();
		}

		if( !$list )
		{
			return HTTP_INTERNAL_SERVER_ERROR;
		}

# a few headers to help clients? look for standards if any
		$r->headers_out->{'X-Search-Results'} = $list->count;
		$r->headers_out->{'X-Search-Offset'} = $indexOffset;
		$r->headers_out->{'X-Search-Pagesize'} = $page_size > $list->count && $page_size > 0 ? $list->count : $page_size;

		$list->{ids} = $list->ids( $indexOffset, $page_size ) if( $page_size > 0 );

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
		return OK;
	}

	if( $self->scope == CRUD_SCOPE_DATAOBJ )
	{
		return HTTP_NOT_FOUND if !defined $dataobj;

		# set Last-Modified header for individual objects
		if( $dataset->property( 'lastmod' ) && defined ( my $field = $dataset->field( 'lastmod' ) ) )
		{
			my $datestamp = $field->get_value( $dataobj );
			$r->headers_out->{'Last-Modified'} = Apache2::Util::ht_time(
				$r->pool,
				EPrints::Time::datestring_to_timet( undef, $datestamp )
			);
		}

		# sf2 - test ETag - use the dataobj uid and its revision number to generate the ETag
		if( $dataset->property( 'revision' ) )
		{
	                $r->headers_out->{'ETag'} = $self->generate_etag( $dataobj );
		}
		# don't output stuff for OPTIONS?
		# for HEAD content must be returned (Apache will discard it)
		# http://perl.apache.org/docs/2.0/user/handlers/http.html#Handling_HEAD_Requests
		if( $self->method eq 'GET' || $self->method eq 'HEAD' )
		{
	                $r->headers_out->{'Cache-Control'} = 'no-cache';
			$r->content_type( $plugin->param( "mimetype" ) );
			$plugin->initialise_fh( \*STDOUT );
			my $output = $plugin->output_dataobj( $dataobj,
				%args,
				fh => \*STDOUT,
			);
			# optional for output_dataobj to support 'fh'
			print $output if defined $output;
		}
	}
	# /id/{datasetid}/{dataobjid}/{fieldname}
	elsif( $self->scope == CRUD_SCOPE_FIELD && defined $field )
	{
		return HTTP_NOT_FOUND if !defined $dataobj;

		# sf2 - test ETag - use the dataobj uid and its revision number to generate the ETag
		if( $dataset->property( 'revision' ) )
		{
	                $r->headers_out->{'ETag'} = $self->generate_etag( $dataobj );
			$repo->debug_log( "crud", "ETag set" );
		}

# TODO/sf2 - warning ->output_field() only implemented by Export/JSON
		if( $self->method eq 'GET' )
		{
			$r->content_type( $plugin->param( "mimetype" ) );
			$plugin->initialise_fh( \*STDOUT );
			my $output = $plugin->output_field( $dataobj,
				$field,
				%args,
				fh => \*STDOUT,
			);
			# optional for output_dataobj to support 'fh'
			print $output if defined $output;
		}
	}
	# /id/{datasetid}, not supported yet (what would it do? searching?)
	else
	{
		return HTTP_NOT_FOUND;
	}

	return OK;
}

sub search
{
	my( $self ) = @_;

	my $repo = $self->repository;

	my $xapian;
	eval {
		my $path = $repo->config( "variables_path" ) . "/xapian";
		$xapian = Search::Xapian::Database->new( $path );
	};

	if( $@ )
	{
		$repo->log( "CRUD-Xapian-Search error: $@" );
		return undef;
	}

	my $plugin = $repo->plugin( 'Search::Xapian' );
	if( !defined $plugin )
	{
		$repo->log( "Search::Xapian not available" );
		return undef;
	}
	my $stemmer = $plugin->stemmer;
	my $stopper = $plugin->stopper;

	my $qp = Search::Xapian::QueryParser->new( $xapian );
	$qp->set_stemmer( $stemmer );
	$qp->set_stopper( $stopper );
	$qp->set_stemming_strategy( Search::Xapian::STEM_SOME() );
	$qp->set_default_op( Search::Xapian::OP_AND() );

	# not in my version of xapian it seems:
	$qp->set_max_wildcard_expansion( 1_000 );

	my $dataset = $self->dataset;

	my $query = Search::Xapian::Query->new( "_dataset:".$dataset->id );

	# the actual query
	# my $q = "yellow OR green OR habits";
	my $q = $repo->param( "q" );

#	my $q = shift @ARGV or die( "\nusage: $0 query [facet1] [facet2] [..]\n\n" );

=pod

	# facets as args
	my @facet_filters;
	for(@ARGV)
	{
		my( $qfacet_field, $qfacet_value ) = split( ":", $_ );
		next if( !defined $qfacet_field || !length $qfacet_field || !defined $qfacet_value );
		if( !length $qfacet_value )
		{
			print STDERR "Ignoring empty facet $qfacet_field\n";
			next;
		}

		# TODO
		# technically qfacet_field should be checked as to whether it's a valid field to facet with!
		# otherwise we're allowing any field to be searched:
		#
		# also single fields are not allowed to be specified twice as facet (because an item couldn't be X and Y at the same time)
		# perhaps facets should only specified once anyways (so you can never facet X and Y for the same field)
		#

		# lc() cos xapian lc's the indexed terms
		push @facet_filters, { field => $qfacet_field, value => lc( $qfacet_value ) };
	}

	my $facet_conf = $repo->config('datasets', 'eprint', 'facets');
	my $valid_facets = {};
	my $facets_idx = {};

	my $datasetid = 'image';

	foreach my $index ( keys %{ $repo->config( 'xapian', $datasetid, 'indexes' ) || [] } ) 
	{
		my $iconf = $repo->config( 'xapian', $datasetid, 'indexes', $index );

		next if( !$iconf || !$iconf->{facet} );

		# ooch
		my $max_slots = 5;

		foreach my $i ( 0..$max_slots )
		{
			my $slot_key = join( ".", $datasetid, "facet", $index, $i );
			my $idx = $xapian->get_metadata( $slot_key );
			next if( !length $idx );
			print "Found facet $slot_key ($idx)\n";

			push @{$facets_idx->{'_'.$index}}, $idx;

			$valid_facets->{'_'.$index} = undef;
		}
	}

	foreach my $ff (@facet_filters)
	{
	#	if( !exists $valid_facets->{$ff->{field}} )
	#	{
	#		print STDERR "Invalid facet $ff->{field}\n";
	#		next;
	#	}

		$query = Search::Xapian::Query->new(
			Search::Xapian::OP_AND(),
			$query,
			new Search::Xapian::Query( "_" . $ff->{field} . ":" . $ff->{value} )
		);
	}

	my $dataset = $repo->dataset( 'image' );
=cut

	my $ctx = $dataset->active_context;

	if( $ctx )
	{
		my $conf = $dataset->property( 'contexts' ) || {};
		next if( !$conf || !$conf->{$ctx} || !$conf->{$ctx}->{xapian} );

		my $fn = $conf->{$ctx}->{xapian};
		
		my $filter = &$fn( $repo );

		if( $filter )
		{
			$query = Search::Xapian::Query->new(
				Search::Xapian::OP_AND(),
				$query,
				new Search::Xapian::Query( "_" . $filter->{index} . ":" . $filter->{value} )
			);
		}
	}

	my $state = $dataset->state;

	if( defined $state )
	{
		$query = Search::Xapian::Query->new(
			Search::Xapian::OP_AND(),
			$query,
			new Search::Xapian::Query( "_dataobj_state:" . $state )
		);
	}

	# problem with _WILDCARD? nah :)
	# it's possible to search for 't*' which returns a very long query all all possible prefixed term which prefix starts in 't' (eg title:)
	# that sux

	$query = Search::Xapian::Query->new(
		Search::Xapian::OP_AND(),
		$query,
		$qp->parse_query( $q,
			Search::Xapian::FLAG_PHRASE() |
			Search::Xapian::FLAG_BOOLEAN() |
			Search::Xapian::FLAG_LOVEHATE() |
			Search::Xapian::FLAG_WILDCARD()
		)
	);

=pod
	# sf2 - if i recall correctly the $decider fn should decide to include/exclude results from the MSet
	# but we use this to iterate over the MSet and look if there are values which are facet-able
	my $facets = {};
	my $decider = sub {

		my( $doc ) = @_;

		foreach my $facet ( %{$facets_idx||{}} )
		{
			foreach my $slot ( @{ $facets_idx->{$facet} || [] } )
			{
				my $value = $doc->get_value( $slot );
				next if( !length $value );			
				$facets->{$facet}->{$value}++;
			}
		}

		return 1;
	};
=cut

	my $enq = $xapian->enquire( $query );

	#my $mset = $enq->get_mset( 0, $xapian->get_doccount, $decider );
	my $mset = $enq->get_mset( 0, $xapian->get_doccount );

=pod
	if( $mset->get_matches_estimated > 1 )
	{
		foreach my $facet ( keys %{$facets||{}} )
		{
			# TODO if only one distinct value -> not a facet (filtering wouldn't actually remove any items)
			next if( scalar( keys %{$facets->{$facet}||{}} ) < 2 );

			foreach my $value ( keys %{$facets->{$facet}||{}} )
			{
				my $occ = $facets->{$facet}->{$value};
				print "Facet $facet -> $value ($occ)\n";
			}
		}
	}
=cut

	printf STDERR "CRUD/search: Running query '%s'\n\n", $enq->get_query()->get_description();

	# return all results
	my @matches = $enq->matches(0, $mset->get_matches_estimated);

	my @ids;
	foreach my $match ( @matches ) 
	{
		my $doc = $match->get_document();

		my $data = Storable::thaw( $doc->get_data );

		push @ids, $data->{id};
	}

	return $self->dataset->list( \@ids );

=pod

	$list->map( sub {
		
		my $dataobj = $_[2];

	#	my $desc = defined $dataobj ? $dataobj->internal_uri. " (".$dataobj->value( 'title' ).")" : 'unknown item';

		printf "%s > %s (%s)\n", $dataobj->internal_uri, $dataobj->value( 'title' ), $dataobj->state;

	#	printf "ID %d %d%% [ %s ]\n", $match->get_docid(), $match->get_percent(), $desc;
	} );

	print "\n\n";
=cut

}

=item $rc = $crud->POST()

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
	my( $self ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;
	my $dataset = $self->dataset;
	my $dataobj = $self->dataobj;
	my $field = $self->field;
	my $plugin = $self->plugin;

	my $user = $repo->current_user;

	# sf2 - and to XX as in /id/{datasetid} - to create a new object of that type
	if(
		$self->scope != CRUD_SCOPE_DATASET &&
		$self->scope != CRUD_SCOPE_FIELD_FILE
	  )
	{
		return HTTP_METHOD_NOT_ALLOWED;
	}

	# POST'ing a file
	if( $self->scope == CRUD_SCOPE_FIELD_FILE )
	{
		if( !defined $dataobj )
		{
			return HTTP_NOT_FOUND;
		}

		$plugin ||= $repo->plugin( "Import::File" );
	}

	$repo->debug_log( "crud", "plug-in %s selected", $plugin->get_id ) if( $plugin );

	my $list = $self->parse_input( $plugin, sub {
			my( $epdata ) = @_;

			my $item;

			if( $self->scope == CRUD_SCOPE_DATASET )
			{
				# create a new object via normal POST
				$item = $dataset->create_dataobj( $epdata );
			}
			elsif( $self->scope == CRUD_SCOPE_FIELD_FILE )
			{
				$epdata->{datasetid} = $dataset->base_id;
				$epdata->{objectid} = $dataobj->id;
				$epdata->{fieldname} = $field->name;
				$epdata->{fieldpos} = $self->{posid};
				$epdata->{filename} = $self->filename;
				
				## perhaps we're updating that field (ie replacing a file...)
#TODO
#my $item = $field->get_value( $dataobj, $self->{posid} );

				if( $field->property( 'multiple' ) )
				{
					# retrieve the $self->{posid}-th value
					my $values = $field->value( $dataobj ) || [];
					$item = $values->[$self->{posid}];
# my $file = $field->value( $dataobj, $pos )

# $dataobj->replace_file( $field, $epdata, $pos );

				}
				else
				{
					$item = $field->value( $dataobj );
# $dataobj->replace_file( $field, $epdata )
				}
				if( defined $item )
				{
					# update!
					$item->update( $epdata, include_subdataobjs => 1 );
					# must force commit cos we're likely not updating any metadata (just the file on disk) so without
					# 'force' the lastmod, revision number ... fields wouldn't get updated
					$item->commit( 1 );
				}
				else
				{
# my $file = $field->add_file( $epdata )
					$item = $dataobj->create_subdataobj( $field->name, $epdata );
				}
			}
			else
			{
				$item = $dataobj->create_subdataobj( $field->name, $epdata );
			}
			
			return $item;
		}
	);
	# return undef if !defined $list;

	if( !defined $list )
	{
		# sf2 - internal error? bad request?
		return HTTP_BAD_REQUEST;
	}

	my $new_dataobj = ($list->slice(0,1))[0];

	if( !defined $new_dataobj )
	{
		# sf2 - internal error? bad request?
		return HTTP_BAD_REQUEST;
	}

	$r->err_headers_out->{Location} = $new_dataobj->uri;

	return HTTP_CREATED;
}

=item $rc = $crud->PUT()

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
	my( $self ) = @_;

	my $r = $self->request;
	my $repo = $self->repository;
	my $dataset = $self->dataset;
	my $dataobj = $self->dataobj;
	my $plugin = $self->plugin;

	my $user = $repo->current_user;

	if( !defined $plugin && $dataset->base_id eq "file" )
	{
		$plugin = $repo->plugin( "Import::Binary" );
	}

	if( !defined $plugin )
	{
		return HTTP_NOT_ACCEPTABLE;
	}

	# We support Content-Ranges for writing to files
	if( defined(my $offset = $self->{content_range}->{offset} ) )
	{
		my $total = $self->{content_range}->{total};
		if( $dataset->base_id ne "file" || !defined $dataobj )
		{
			return HTTP_RANGE_NOT_SATISFIABLE;
		}
		my $tmpfile = $self->_read_content;
		return $r->status if !defined $tmpfile;

		if( $total eq '*' || ($offset + -s $tmpfile) > $total )
		{
			return HTTP_RANGE_NOT_SATISFIABLE;
		}

		my $rlen = $dataobj->set_file_chunk( $tmpfile, -s $tmpfile, $offset, $total );
		return HTTP_INTERNAL_SERVER_ERROR if !defined $rlen;

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
		$dataobj = $self->create_dataobj();
		return HTTP_FORBIDDEN if !defined $dataobj;
	}

# sf2 - ETag
	if( defined (my $client_etag = $self->header( 'If-None-Match' ) ) )
	{
		$repo->debug_log( 'crud', "checked ETag '%s' is valid for object %s", $client_etag, $dataobj->internal_uri );

		if( $dataset->property( 'revision' ) )
		{
			my $server_etag = $self->generate_etag( $dataobj );

			if( $client_etag ne $server_etag )
			{
				$repo->debug_log( 'crud', "ETag's don't match (client: '%s' - server: '%s')", $client_etag, $server_etag );
				# cannot carry on with the request - the client's copy of the resource is out-of-sync
				return HTTP_PRECONDITION_FAILED; 
			}
			else
			{
				$repo->debug_log( 'crud', "ETag's OK" );

			}
                }
		else
		{
			# odd: client supplied an ETag but we can't generate one at our end
			return HTTP_BAD_REQUEST;
		}
	}

#
# sf2 - PUT requests should empty the object - this is a global update of the object
# sf2 - PATCH requests shouldn't - this is a partial update - see http://tools.ietf.org/html/rfc5789
#	PATCH'es are however problematic to implement: it is possible that the object has been modified since the last read operation (detectable by using ETag headers
#	Also modifying some fields of an object may automatically update some other fields (eprint_fields_automatic) therefore the client would need to re-read the entire resource (but that's also true for PUT requests).
#
#	Also read on Accept-Patch header (in the RFC above)

	if( $self->method ne "PATCH" )
	{
		$dataobj->empty();
	}

	my $rc = $dataobj->update( $epdata, include_subobjects => 1 );

	if( !$rc )
	{
		# failed - should return
		# TODO? this could also be because the USER couldn't transfer the data-obj (so that's more of a 403...)
		return HTTP_BAD_REQUEST;
	}

	$dataobj->commit;

	if( !defined $self->dataobj )
	{
		$self->request->err_headers_out->{Location} = $dataobj->uri;
		return HTTP_CREATED;
	}

	return HTTP_NO_CONTENT;
}


# input_fh() failed
sub plugin_error
{
	my( $self, $plugin, $messages ) = @_;

	my $repo = $self->repository;

	$plugin->handler->message( "error", $@ ) if $@ ne "\n";

	my $err = "";
	for(@{$messages}) {
		$err .= "$_\n";
	}

# sf2 - repo->xhtml not available - yet
#
#	my $ul = $repo->xml->create_element( "ul" );
#	for(@{$messages}) {
#		$ul->appendChild( $repo->xml->create_data_element( "li", $_ ) );
#	}
#	my $err = $repo->xhtml->to_xhtml( $ul );
#	$repo->xml->dispose( $ul );

	return undef;

	# TODO sf2 :
#	return $self->sword_error(
#		status => HTTP_INTERNAL_SERVER_ERROR,
#		summary => $err
#	);
}



1;
