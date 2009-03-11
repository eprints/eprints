
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
			place => "admin_actions",
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

	my $session = $self->{session};
	my $user = $session->current_user;

	my( $html , $table , $p , $span );
	
	# Write the results to a table
	
	$html = $session->make_doc_fragment;

	# Write the results to a table
	
	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $session->html_phrase( "cgi/users/status:cache_tables" ) );
	$html->appendChild( $table );

	$table->appendChild(
		$session->render_row( 
			undef,
			$session->html_phrase( "cgi/users/status:cachedate" ),
			$session->html_phrase( "cgi/users/status:cachesize" ) ) );

	my $cache_ds = $session->get_repository->get_dataset( "cachemap" );
	foreach my $name ($session->get_database->get_tables)
	{
		next unless $name =~ /^cache(\d+)$/;
		my $cachemap = $cache_ds->get_object( $session, $1 );
		my $count = $session->get_database->count_table($name);
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
			$session->render_row( 
				$session->make_text( $name ),
				$session->make_text( $created ),
				$session->make_text( $count ) ) );
	}
	
	$html->appendChild( $session->html_phrase( "cgi/users/status:database_tables" ) );

	$p = $session->make_element( "p" );
	$html->appendChild( $p );
	$html->appendChild( $session->make_text( "Schema version " . $session->get_database->get_version ));

	my %all_tables = map { $_ => 1 } $session->get_database->get_tables;

	my $langs = $session->get_repository->get_conf( "languages" );

	$html->appendChild( $session->html_phrase( "cgi/users/status:dataset_tables" ) );

	my $dataset_table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $dataset_table );

	foreach my $datasetid (sort { $a cmp $b } $session->get_repository->get_sql_dataset_ids())
	{
		my $dataset = $session->get_repository->get_dataset( $datasetid );

		my $table_name = $dataset->get_sql_table_name;
		delete $all_tables{$table_name};

		my $url = "#$datasetid";
		my $link = $session->render_link( $url );
		$link->appendChild( $session->html_phrase( "datasetname_$datasetid" ) );

		$dataset_table->appendChild(
			$session->render_row(
				$session->make_text( $table_name ),
				$link,
				$session->html_phrase( "datasethelp_$datasetid" ),
		) );

		$table = $session->make_element( "table", border=>"0" );

		foreach my $aux_type (qw( index rindex index_grep ))
		{
			my $aux_table = $table_name."__".$aux_type;
			next unless delete $all_tables{$aux_table};

			my $name = $session->html_phrase( "database/name__$aux_type" );
			my $help = $session->html_phrase( "database/help__$aux_type" );

			$table->appendChild(
					$session->render_row(
						$session->make_text( $aux_table ),
						$name,
						$help,
						) );
		}

		foreach my $lang (@$langs)
		{
			my $aux_table = $table_name."__ordervalues_".$lang;
			next unless delete $all_tables{$aux_table};

			my $name = $session->html_phrase( "database/name__ordervalues" );
			my $help = $session->html_phrase( "database/help__ordervalues",
				lang => $session->html_phrase( "languages_typename_$lang" ),
			);

			$table->appendChild(
					$session->render_row(
						$session->make_text( $aux_table ),
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
			my $name = $session->html_phrase( $nameid );

			my $helpid = "${datasetid}_fieldhelp_$field_name";
			my $help = $session->get_lang->has_phrase( $helpid ) ?
				$session->html_phrase( $helpid ) :
				$session->make_text( "" );

			$table->appendChild(
					$session->render_row(
						$session->make_text( "$table_name\_$field_name" ),
						$name,
						$help
						) );
		}

		if( $table->hasChildNodes )
		{
			my $link = $session->make_element( "a",
				name => $datasetid,
			);
			my $h = $session->make_element( "h4" );
			$html->appendChild( $link );
			$link->appendChild( $h );
			$h->appendChild( $session->html_phrase( "datasetname_$datasetid" ) );
			$html->appendChild( $table );
		}
	}

	$html->appendChild( $session->html_phrase( "cgi/users/status:misc_tables" ) );

	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $table );

	foreach my $table_name (sort { $a cmp $b } keys %all_tables)
	{
		next if $table_name =~ /^cache(\d+)$/;

		my $nameid = "database/name_$table_name";
		my $name = $session->get_lang->has_phrase( $nameid ) ?
			$session->html_phrase( $nameid ) :
			$session->html_phrase( "database/name_" );

		my $helpid = "database/help_$table_name";
		my $help = $session->get_lang->has_phrase( $helpid ) ?
			$session->html_phrase( $helpid ) :
			$session->html_phrase( "database/help_" );

		$table->appendChild(
			$session->render_row(
				$session->make_text( $table_name ),
				$name,
				$help
		) );
	}

	$self->{processor}->{title} = $session->html_phrase( "cgi/users/status:title" );

	return $html;
}

1;
