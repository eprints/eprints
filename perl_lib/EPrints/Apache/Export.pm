package EPrints::Apache::Export;

use EPrints::Const qw( :http );

use EPrints::Apache::Auth;
use Apache2::Access;

use strict;

# authentication
sub authen
{
	my( $r ) = @_;

	my $repo = $EPrints::HANDLE->current_repository;
	return HTTP_FORBIDDEN if !defined $repo;

	my $dataobj = $r->pnotes->{dataobj};
	my $dataset = $r->pnotes->{dataset};
	my $plugin = $r->pnotes->{plugin};
	my $field = $r->pnotes->{field};

	if( $plugin->param( "visible" ) eq "staff" )
	{
		return EPrints::Apache::Auth::authen( $r );
	}

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

	my $priv = "export";
	if( $dataset->id ne $dataset->base_id )
	{
		$priv = join('/', $dataset->base_id, $dataset->id, $priv );
	}
	else
	{
		$priv = join('/', $dataset->base_id, $priv );
	}

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
	my $field = $r->pnotes->{field};

	my $user = $repo->current_user;

	if( $plugin->param( "visible" ) eq "staff" )
	{
		return HTTP_FORBIDDEN if !defined $user;
		if( $user->get_type ne "editor" && $user->get_type ne "admin" )
		{
			return HTTP_FORBIDDEN;
		}
	}

	if( $dataobj->isa( "EPrints::DataObj::File" ) )
	{
		$dataobj = $dataobj->parent;
		$dataset = $dataobj->get_dataset;
	}
	if( $dataobj->isa( "EPrints::DataObj::Document" ) )
	{
		$r->pnotes->{document} = $dataobj;
		return EPrints::Apache::Auth::authz_doc( $r );
	}

	my $priv = "export";
	if( $dataset->id ne $dataset->base_id )
	{
		$priv = join('/', $dataset->base_id, $dataset->id, $priv );
	}
	else
	{
		$priv = join('/', $dataset->base_id, $priv );
	}

	return OK if $repo->allow_anybody( $priv );

	return HTTP_FORBIDDEN if !defined $user;

	if(
		$user->allow( "$priv:owner", $dataobj ) ||
		$user->allow( "$priv:editor", $dataobj ) ||
		$user->allow( $priv )
	  )
	{
		return OK;
	}

	return HTTP_FORBIDDEN;
}

# response
sub handler
{
	my( $r ) = @_;

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

	$repo->send_http_header( "content_type"=>$plugin->param("mimetype") );
	$plugin->initialise_fh( \*STDOUT );
	if( $field )
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
		print $plugin->output_dataobj( $dataobj, %args );
	}

	return OK;
}

1;
