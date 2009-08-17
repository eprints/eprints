
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
			place => "admin_actions_system",
			position => 100,
		},
	];

	$self->{daemon} = EPrints::Index::Daemon->new(
		handle => $self->{handle},
		Handler => $self->{processor},
		logfile => EPrints::Index::logfile(),
		noise => ($self->{handle}->{noise}||1),
	);

	return $self;
}

sub get_daemon
{
	my( $self ) = @_;
	return $self->{daemon};
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "status" );
}

sub indexer_warnings 
{
	my( $self ) = @_;

	if( $self->get_daemon->has_stalled() )
	{
		my $index_screen = $self->{handle}->plugin( "Screen::Admin::IndexerControl", processor => $self->{processor} );
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
	elsif( !$self->get_daemon->is_running() )
	{
		my $index_screen = $self->{handle}->plugin( "Screen::Admin::IndexerControl", processor => $self->{processor} );
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

	my $handle = $self->{handle};
	my $user = $handle->current_user;

	my $rows;

	# Number of users in each group
	my $total_users = $handle->get_repository->get_dataset( "user" )->count( $handle );

	my %num_users = ();
	my $userds = $handle->get_repository->get_dataset( "user" );
	my $subds = $handle->get_repository->get_dataset( "saved_search" );
	my @usertypes = $handle->get_repository->get_types( "user" );
	foreach my $usertype ( @usertypes )
	{
		my $searchexp = new EPrints::Search(
			handle => $handle,
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
		$num_eprints{$_} = $handle->get_repository->get_dataset( $_ )->count( $handle );
	}
	
	my $db_status = ( $total_users > 0 ? "ok" : "down" );


	my $indexer_status;

	if( !$self->get_daemon->is_running() )
	{
		$indexer_status = "stopped";
	}
	elsif( $self->get_daemon->has_stalled() )
	{
		$indexer_status = "stalled";
	}
	else
	{
		$indexer_status = "running";
	}

	my $indexer_queue = $handle->get_database->count_table( "event_queue" );
	
	my( $html , $table , $p , $span );
	
	# Write the results to a table
	
	$html = $handle->make_doc_fragment;

	$html->appendChild( $self->render_common_action_buttons );

	$table = $handle->make_element( "table", border=>"0" );
	$html->appendChild( $table );
	
	$table->appendChild( $handle->render_row( 
			$handle->html_phrase( "cgi/users/status:release" ),
			$handle->make_text( 
				EPrints::Config::get( "version" ) ) ) );

	$table->appendChild(
		$handle->render_row( 
			$handle->html_phrase( "cgi/users/status:database_driver" ),
			$handle->make_text( $handle->get_database()->get_driver_name ) ) );
	
	$table->appendChild(
		$handle->render_row( 
			$handle->html_phrase( "cgi/users/status:database_version" ),
			$handle->make_text( $handle->get_database()->get_server_version ) ) );
	
	$table->appendChild(
		$handle->render_row( 
			$handle->html_phrase( "cgi/users/status:database" ),
			$handle->html_phrase( "cgi/users/status:database_".$db_status ) ) );
	
	$table->appendChild(
		$handle->render_row( 
			$handle->html_phrase( "cgi/users/status:indexer" ),
			$handle->html_phrase( "cgi/users/status:indexer_".$indexer_status ) ) );
	
	$table->appendChild(
		$handle->render_row( 
			$handle->html_phrase( "cgi/users/status:indexer_queue" ),
			$handle->html_phrase( "cgi/users/status:indexer_queue_size", 
				size => $handle->make_text( $indexer_queue ) ) ) );
	
	$table->appendChild(
		$handle->render_row( 
			$handle->html_phrase( "cgi/users/status:xml_version" ),
			$handle->make_text( EPrints::XML::version() ) ) );
	
	$table = $handle->make_element( "table", border=>"0" );
	$html->appendChild( $handle->html_phrase( "cgi/users/status:usertitle" ) );
	$html->appendChild( $table );
	
	foreach my $usertype ( keys %num_users )
	{
		my $k = $handle->make_doc_fragment;
		$k->appendChild( $handle->render_type_name( "user", $usertype ) );
		$table->appendChild(
			$handle->render_row( 
				$k, 
				$handle->make_text( $num_users{$usertype} ) ) );
	}
	$table->appendChild(
		$handle->render_row( 
			$handle->html_phrase( "cgi/users/status:users" ),
			$handle->make_text( $total_users ) ) );
	
	$table = $handle->make_element( "table", border=>"0" );
	$html->appendChild( $handle->html_phrase( "cgi/users/status:articles" ) );
	$html->appendChild( $table );
	
	foreach( @esets )
	{
		$table->appendChild(
			$handle->render_row( 
				$handle->html_phrase( "cgi/users/status:set_".$_ ),
				$handle->make_text( $num_eprints{$_} ) ) );
	}
	
	
	unless( $EPrints::SystemSettings::conf->{disable_df} )
	{
		$table = $handle->make_element( "table", border=>"0" );
		$html->appendChild( $handle->html_phrase( "cgi/users/status:diskspace" ) );
		$html->appendChild( $table );
	
		my $best_size = 0;
	
		my @dirs = $handle->get_repository->get_store_dirs();
		my $dir;
		foreach $dir ( @dirs )
		{
			my $size = $handle->get_repository->get_store_dir_size( $dir );
			$table->appendChild(
				$handle->render_row( 
					$handle->html_phrase( 
						"cgi/users/status:diskfree",
						dir=>$handle->make_text( $dir ) ),
					$handle->html_phrase( 
						"cgi/users/status:mbfree",
						mb=>$handle->make_text( 
							int($size/1024/1024) ) ) ) );
		
			$best_size = $size if( $size > $best_size );
		}
		
		if( $best_size < $handle->get_repository->get_conf( 
						"diskspace_error_threshold" ) )
		{
			$p = $handle->make_element( "p" );
			$html->appendChild( $p );
			$p->appendChild( 
				$handle->html_phrase( 
					"cgi/users/status:out_of_space" ) );
		}
		elsif( $best_size < $handle->get_repository->get_conf( 
							"diskspace_warn_threshold" ) )
		{
			$p = $handle->make_element( "p" );
			$html->appendChild( $p );
			$p->appendChild( 
				$handle->html_phrase( 
					"cgi/users/status:nearly_out_of_space" ) );
		}
	}
	
	
	$table = $handle->make_element( "table", border=>"0" );
	$html->appendChild( $handle->html_phrase( "cgi/users/status:saved_searches" ) );
	$html->appendChild( $table );
	
	$table->appendChild(
		$handle->render_row( 
			undef,
			$handle->html_phrase( "cgi/users/status:subcount" ),
			$handle->html_phrase( "cgi/users/status:subsent" ) ) );
	foreach my $freq ( "never", "daily", "weekly", "monthly" )
	{
		my $sent;
		if( $freq ne "never" )
		{
			$sent = EPrints::DataObj::SavedSearch::get_last_timestamp( 
				$handle, 
				$freq );
		}
		if( !defined $sent )
		{
			$sent = "?";
		}
		my $searchexp = new EPrints::Search(
			handle => $handle,
			dataset => $subds );
	
		$searchexp->add_field(
			$userds->get_field( "frequency" ),
			$freq );

		$searchexp->perform_search();
		my $n = $searchexp->count;
		$searchexp->dispose;

		my $k = $handle->make_doc_fragment;
		$k->appendChild( $handle->html_phrase( "saved_search_fieldopt_frequency_".$freq ) );
		$table->appendChild(
			$handle->render_row( 
				$k,
				$handle->make_text( $n ),
				$handle->make_text( $sent ) ) );
	}

	$self->{processor}->{title} = $handle->html_phrase( "cgi/users/status:title" );

	return $html;
}

sub render_common_action_buttons
{
	my( $self ) = @_;
	return $self->{handle}->make_doc_fragment;
}
	


1;
