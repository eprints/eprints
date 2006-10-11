
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
			place => "other_tools",
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


sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;

	my $rows;

	# Number of users in each group
	my $total_users = $session->get_repository->get_dataset( "user" )->count( $session );

	my %num_users = ();
	my $userds = $session->get_repository->get_dataset( "user" );
	my $subds = $session->get_repository->get_dataset( "subscription" );
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
	
	my $db_status = ( $total_users > 0 ? "OK" : "DOWN" );
	
	my( $html , $table , $p , $span );
	
	# Write the results to a table
	
	$html = $session->make_doc_fragment;
	
	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $table );
	
	$table->appendChild( render_row( 
			$session,
			$session->html_phrase( "cgi/users/status:release" ),
			$session->make_text( 
				EPrints::Config::get( "version" ) ) ) );

	$table->appendChild(
		render_row( 
			$session,
			$session->html_phrase( "cgi/users/status:database" ),
			$session->make_text( $db_status ) ) );
	
	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $session->html_phrase( "cgi/users/status:usertitle" ) );
	$html->appendChild( $table );
	
	foreach my $usertype ( keys %num_users )
	{
		my $k = $session->make_doc_fragment;
		$k->appendChild( $session->render_type_name( "user", $usertype ) );
		$k->appendChild( $session->make_text( ":" ) );
		$table->appendChild(
			render_row( 
				$session,
				$k, 
				$session->make_text( $num_users{$usertype} ) ) );
	}
	$table->appendChild(
		render_row( 
			$session,
			$session->html_phrase( "cgi/users/status:users" ),
			$session->make_text( $total_users ) ) );
	
	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $session->html_phrase( "cgi/users/status:articles" ) );
	$html->appendChild( $table );
	
	foreach( @esets )
	{
		$table->appendChild(
			render_row( 
				$session,
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
				render_row( 
					$session,
					$session->html_phrase( 
						"cgi/users/status:diskfree",
						dir=>$session->make_text( $dir ) ),
					$session->html_phrase( 
						"cgi/users/status:mbfree",
						mb=>$session->make_text( 
							int($size/1024) ) ) ) );
		
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
	$html->appendChild( $session->html_phrase( "cgi/users/status:subscriptions" ) );
	$html->appendChild( $table );
	
	$table->appendChild(
		render_row( 
			$session,
			undef,
			$session->html_phrase( "cgi/users/status:subcount" ),
			$session->html_phrase( "cgi/users/status:subsent" ) ) );
	foreach my $freq ( "never", "daily", "weekly", "monthly" )
	{
		my $sent;
		if( $freq ne "never" )
		{
			$sent = EPrints::DataObj::Subscription::get_last_timestamp( 
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
		$k->appendChild( $session->html_phrase( "subscription_fieldopt_frequency_".$freq ) );
		$k->appendChild( $session->make_text( ":" ) );
		$table->appendChild(
			render_row( 
				$session,
				$k,
				$session->make_text( $n ),
				$session->make_text( $sent ) ) );
	}

	$self->{processor}->{title} = $session->html_phrase( "cgi/users/status:title" );

	return $html;
}


	
# this cjg should probably by styled.
sub render_row
{
	my( $session, $key, @vals ) = @_;
	
	my( $tr, $td );
	$tr = $session->make_element( "tr" );

	if( !defined $key )
	{
		$td = $session->make_element( "td" );
		$tr->appendChild( $td );
	}
	else
	{
		$td = $session->make_element( "td", class=>"status_row_heading" );
		$tr->appendChild( $td );
		$td->appendChild( $key );
	}

	foreach( @vals )
	{
		$td = $session->make_element( "td", align=>"center", class=>"status_cell"  );
		$tr->appendChild( $td );
		$td->appendChild( $_ );
	}
	return $tr;
}


1;
