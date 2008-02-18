
package EPrints::Plugin::Screen::Status;

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
			position => 100,
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "status" );
}

sub indexer_warnings 
{
	my( $self ) = @_;

	if( EPrints::Index::has_stalled() )
	{
		my $index_screen = $self->{session}->plugin( "Screen::Admin::IndexerControl", processor => $self->{processor} );
		my $force_start_button = $self->render_action_button_if_allowed( 
		{ 
			action => "force_start_indexer", 
			screen => $index_screen, 
			screen_id => $index_screen->{id} 
		} );

		$self->{processor}->add_message( 
			"warning",
			$self->html_phrase( "indexer_stalled", force_start_button => $force_start_button ) 
		);
	}
	elsif( !EPrints::Index::is_running() )
	{
		my $index_screen = $self->{session}->plugin( "Screen::Admin::IndexerControl", processor => $self->{processor} );
		my $start_button = $self->render_action_button_if_allowed( 
		{ 
			action => "start_indexer", 
			screen => $index_screen, 
			screen_id => $index_screen->{id} ,
		} );
 
		$self->{processor}->add_message( 
			"warning", 
			$self->html_phrase( "indexer_not_running", start_button => $start_button ) 
		);
	}
}

sub render
{
	my( $self ) = @_;

	$self->indexer_warnings();

	my $session = $self->{session};
	my $user = $session->current_user;

	my $rows;

	# Number of users in each group
	my $total_users = $session->get_repository->get_dataset( "user" )->count( $session );

	my %num_users = ();
	my $userds = $session->get_repository->get_dataset( "user" );
	my $subds = $session->get_repository->get_dataset( "saved_search" );
	my @usertypes = $session->get_repository->get_types( "user" );
	foreach my $usertype ( @usertypes )
	{
		my $searchexp = new EPrints::Search(
			session => $session,
			dataset => $userds );
	
		$searchexp->add_field(
			$userds->get_field( "usertype" ),
			$usertype );

		$searchexp->perform_search();
		$num_users{ $usertype } = $searchexp->count();
		$searchexp->dispose();
	}

	my %num_eprints = ();
	my @esets = ( "archive", "buffer", "inbox", "deletion" );

	foreach( @esets )
	{
		# Number of submissions in dataset
		$num_eprints{$_} = $session->get_repository->get_dataset( $_ )->count( $session );
	}
	
	my $db_status = ( $total_users > 0 ? "ok" : "down" );


	my $indexer_status;

	if( !EPrints::Index::is_running() )
	{
		$indexer_status = "stopped";
	}
	elsif( EPrints::Index::has_stalled() )
	{
		$indexer_status = "stalled";
	}
	else
	{
		$indexer_status = "running";
	}

	my $indexer_queue = $session->get_database->count_table( "index_queue" );
	
	my( $html , $table , $p , $span );
	
	# Write the results to a table
	
	$html = $session->make_doc_fragment;

	$html->appendChild( $self->render_common_action_buttons );

	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $table );
	
	$table->appendChild( $session->render_row( 
			$session->html_phrase( "cgi/users/status:release" ),
			$session->make_text( 
				EPrints::Config::get( "version" ) ) ) );

	$table->appendChild(
		$session->render_row( 
			$session->html_phrase( "cgi/users/status:database_driver" ),
			$session->make_text( $session->get_database()->get_driver_name ) ) );
	
	$table->appendChild(
		$session->render_row( 
			$session->html_phrase( "cgi/users/status:database_version" ),
			$session->make_text( $session->get_database()->get_server_version ) ) );
	
	$table->appendChild(
		$session->render_row( 
			$session->html_phrase( "cgi/users/status:database" ),
			$session->html_phrase( "cgi/users/status:database_".$db_status ) ) );
	
	$table->appendChild(
		$session->render_row( 
			$session->html_phrase( "cgi/users/status:indexer" ),
			$session->html_phrase( "cgi/users/status:indexer_".$indexer_status ) ) );
	
	$table->appendChild(
		$session->render_row( 
			$session->html_phrase( "cgi/users/status:indexer_queue" ),
			$session->html_phrase( "cgi/users/status:indexer_queue_size", 
				size => $session->make_text( $indexer_queue ) ) ) );
	
	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $session->html_phrase( "cgi/users/status:usertitle" ) );
	$html->appendChild( $table );
	
	foreach my $usertype ( keys %num_users )
	{
		my $k = $session->make_doc_fragment;
		$k->appendChild( $session->render_type_name( "user", $usertype ) );
		$table->appendChild(
			$session->render_row( 
				$k, 
				$session->make_text( $num_users{$usertype} ) ) );
	}
	$table->appendChild(
		$session->render_row( 
			$session->html_phrase( "cgi/users/status:users" ),
			$session->make_text( $total_users ) ) );
	
	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $session->html_phrase( "cgi/users/status:articles" ) );
	$html->appendChild( $table );
	
	foreach( @esets )
	{
		$table->appendChild(
			$session->render_row( 
				$session->html_phrase( "cgi/users/status:set_".$_ ),
				$session->make_text( $num_eprints{$_} ) ) );
	}
	
	
	unless( $EPrints::SystemSettings::conf->{disable_df} )
	{
		$table = $session->make_element( "table", border=>"0" );
		$html->appendChild( $session->html_phrase( "cgi/users/status:diskspace" ) );
		$html->appendChild( $table );
	
		my $best_size = 0;
	
		my @dirs = $session->get_repository->get_store_dirs();
		my $dir;
		foreach $dir ( @dirs )
		{
			my $size = $session->get_repository->get_store_dir_size( $dir );
			$table->appendChild(
				$session->render_row( 
					$session->html_phrase( 
						"cgi/users/status:diskfree",
						dir=>$session->make_text( $dir ) ),
					$session->html_phrase( 
						"cgi/users/status:mbfree",
						mb=>$session->make_text( 
							int($size/1024/1024) ) ) ) );
		
			$best_size = $size if( $size > $best_size );
		}
		
		if( $best_size < $session->get_repository->get_conf( 
						"diskspace_error_threshold" ) )
		{
			$p = $session->make_element( "p" );
			$html->appendChild( $p );
			$p->appendChild( 
				$session->html_phrase( 
					"cgi/users/status:out_of_space" ) );
		}
		elsif( $best_size < $session->get_repository->get_conf( 
							"diskspace_warn_threshold" ) )
		{
			$p = $session->make_element( "p" );
			$html->appendChild( $p );
			$p->appendChild( 
				$session->html_phrase( 
					"cgi/users/status:nearly_out_of_space" ) );
		}
	}
	
	
	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $session->html_phrase( "cgi/users/status:saved_searches" ) );
	$html->appendChild( $table );
	
	$table->appendChild(
		$session->render_row( 
			undef,
			$session->html_phrase( "cgi/users/status:subcount" ),
			$session->html_phrase( "cgi/users/status:subsent" ) ) );
	foreach my $freq ( "never", "daily", "weekly", "monthly" )
	{
		my $sent;
		if( $freq ne "never" )
		{
			$sent = EPrints::DataObj::SavedSearch::get_last_timestamp( 
				$session, 
				$freq );
		}
		if( !defined $sent )
		{
			$sent = "?";
		}
		my $searchexp = new EPrints::Search(
			session => $session,
			dataset => $subds );
	
		$searchexp->add_field(
			$userds->get_field( "frequency" ),
			$freq );

		$searchexp->perform_search();
		my $n = $searchexp->count;
		$searchexp->dispose;

		my $k = $session->make_doc_fragment;
		$k->appendChild( $session->html_phrase( "saved_search_fieldopt_frequency_".$freq ) );
		$table->appendChild(
			$session->render_row( 
				$k,
				$session->make_text( $n ),
				$session->make_text( $sent ) ) );
	}

	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $session->html_phrase( "cgi/users/status:cache_tables" ) );
	$html->appendChild( $table );

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
	
	$self->{processor}->{title} = $session->html_phrase( "cgi/users/status:title" );

	return $html;
}

sub render_common_action_buttons
{
	my( $self ) = @_;
	return $self->{session}->make_doc_fragment;
}
	


1;
