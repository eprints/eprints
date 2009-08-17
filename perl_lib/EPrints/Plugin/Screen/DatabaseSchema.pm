
package EPrints::Plugin::Screen::DatabaseSchema;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "admin_actions_system",
			position => 3000,
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "status" );
}

sub render
{
	my( $self ) = @_;

	my $handle = $self->{handle};
	my $user = $handle->current_user;

	my( $html , $table , $p , $span );
	
	# Write the results to a table
	
	$html = $handle->make_doc_fragment;

	# Write the results to a table
	
	$table = $handle->make_element( "table", border=>"0" );
	$html->appendChild( $handle->html_phrase( "cgi/users/status:cache_tables" ) );
	$html->appendChild( $table );

	$table->appendChild(
		$handle->render_row( 
			undef,
			$handle->html_phrase( "cgi/users/status:cachedate" ),
			$handle->html_phrase( "cgi/users/status:cachesize" ) ) );

	my $cache_ds = $handle->get_repository->get_dataset( "cachemap" );
	foreach my $name ($handle->get_database->get_tables)
	{
		next unless $name =~ /^cache(\d+)$/;
		my $cachemap = $cache_ds->get_object( $handle, $1 );
		my $count = $handle->get_database->count_table($name);
		my $created;
		if( $cachemap )
		{
			$created = scalar gmtime($cachemap->get_value( "created" ));
		}
		else
		{
			$created = "Ooops! Orphaned!";
		}

		$table->appendChild(
			$handle->render_row( 
				$handle->make_text( $name ),
				$handle->make_text( $created ),
				$handle->make_text( $count ) ) );
	}
	
	$html->appendChild( $handle->html_phrase( "cgi/users/status:database_tables" ) );

	$p = $handle->make_element( "p" );
	$html->appendChild( $p );
	$html->appendChild( $handle->make_text( "Schema version " . $handle->get_database->get_version ));

	my %all_tables = map { $_ => 1 } $handle->get_database->get_tables;

	my $langs = $handle->get_repository->get_conf( "languages" );

	$html->appendChild( $handle->html_phrase( "cgi/users/status:dataset_tables" ) );

	my $dataset_table = $handle->make_element( "table", border=>"0" );
	$html->appendChild( $dataset_table );

	foreach my $datasetid (sort { $a cmp $b } $handle->get_repository->get_sql_dataset_ids())
	{
		my $dataset = $handle->get_repository->get_dataset( $datasetid );

		my $table_name = $dataset->get_sql_table_name;
		delete $all_tables{$table_name};

		my $url = "#$datasetid";
		my $link = $handle->render_link( $url );
		$link->appendChild( $handle->html_phrase( "datasetname_$datasetid" ) );

		$dataset_table->appendChild(
			$handle->render_row(
				$handle->make_text( $table_name ),
				$link,
				$handle->html_phrase( "datasethelp_$datasetid" ),
		) );

		$table = $handle->make_element( "table", border=>"0" );

		foreach my $aux_type (qw( index rindex index_grep ))
		{
			my $aux_table = $table_name."__".$aux_type;
			next unless delete $all_tables{$aux_table};

			my $name = $handle->html_phrase( "database/name__$aux_type" );
			my $help = $handle->html_phrase( "database/help__$aux_type" );

			$table->appendChild(
					$handle->render_row(
						$handle->make_text( $aux_table ),
						$name,
						$help,
						) );
		}

		foreach my $lang (@$langs)
		{
			my $aux_table = $table_name."__ordervalues_".$lang;
			next unless delete $all_tables{$aux_table};

			my $name = $handle->html_phrase( "database/name__ordervalues" );
			my $help = $handle->html_phrase( "database/help__ordervalues",
				lang => $handle->html_phrase( "languages_typename_$lang" ),
			);

			$table->appendChild(
					$handle->render_row(
						$handle->make_text( $aux_table ),
						$name,
						$help,
						) );
		}

		foreach my $field ($dataset->get_fields)
		{
			next if $field->is_virtual;
			next unless $field->get_property( "multiple" );

			my $field_name = $field->get_name;

			delete $all_tables{"$table_name\_$field_name"};

			my $nameid = "${datasetid}_fieldname_$field_name";
			my $name = $handle->html_phrase( $nameid );

			my $helpid = "${datasetid}_fieldhelp_$field_name";
			my $help = $handle->get_lang->has_phrase( $helpid, $handle ) ?
				$handle->html_phrase( $helpid ) :
				$handle->make_text( "" );

			$table->appendChild(
					$handle->render_row(
						$handle->make_text( "$table_name\_$field_name" ),
						$name,
						$help
						) );
		}

		if( $table->hasChildNodes )
		{
			my $link = $handle->make_element( "a",
				name => $datasetid,
			);
			my $h = $handle->make_element( "h4" );
			$html->appendChild( $link );
			$link->appendChild( $h );
			$h->appendChild( $handle->html_phrase( "datasetname_$datasetid" ) );
			$html->appendChild( $table );
		}
	}

	$html->appendChild( $handle->html_phrase( "cgi/users/status:misc_tables" ) );

	$table = $handle->make_element( "table", border=>"0" );
	$html->appendChild( $table );

	foreach my $table_name (sort { $a cmp $b } keys %all_tables)
	{
		next if $table_name =~ /^cache(\d+)$/;

		my $nameid = "database/name_$table_name";
		my $name = $handle->get_lang->has_phrase( $nameid, $handle ) ?
			$handle->html_phrase( $nameid ) :
			$handle->html_phrase( "database/name_" );

		my $helpid = "database/help_$table_name";
		my $help = $handle->get_lang->has_phrase( $helpid, $handle ) ?
			$handle->html_phrase( $helpid ) :
			$handle->html_phrase( "database/help_" );

		$table->appendChild(
			$handle->render_row(
				$handle->make_text( $table_name ),
				$name,
				$help
		) );
	}

	$self->{processor}->{title} = $handle->html_phrase( "cgi/users/status:title" );

	return $html;
}

1;
