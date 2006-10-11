
package EPrints::Plugin::Screen::Review;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "key_tools",
			position => 400,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "editorial_review" );
}


sub render
{
	my( $self ) = @_;

	my $user = $self->{session}->current_user;

	my $page = $self->{session}->make_doc_fragment();

	# Get EPrints in the submission buffer
	my $list = $user->get_editable_eprints();

	if( $list->count == 0 )
	{
		# Empty list
		return $self->{session}->html_phrase( "cgi/users/buffer:no_entries", scope=>$self->_get_scope( $user ) );
	}

	$page->appendChild( $self->{session}->html_phrase( 
		"cgi/users/buffer:buffer_blurb",
		scope=>$self->_get_scope( $user ) ) );

	# Sorting options
	my $form = $self->{session}->render_form( "GET" );
	$page->appendChild( $form );

	my $sort_order = $self->{session}->param( "_order" );
	my $search = EPrints::Search->new(
		session => $self->{session},
		dataset => $self->{session}->get_repository->get_dataset( "eprint" ),
		order_methods => $self->{session}->get_repository->get_conf( "order_methods", "eprint.review" ), # will use default if not defined
		order => $sort_order,
	);
	$form->appendChild( $search->render_order_menu );

	my $basename = "_review";
	my $offset = $self->{session}->param( "$basename\_offset" );
	if( defined $offset && $offset ne "" )
	{
		$form->appendChild( $self->{session}->render_hidden_field( "$basename\_offset", $offset ) );
	}
	$form->appendChild( $self->{session}->render_hidden_field( "screen", "Review" ) );
	$form->appendChild( $self->{session}->render_action_buttons( submit => "Submit" ) ); 

	# TODO Add filters that respect editorial scope
	#my $fieldnames = $self->{session}->get_repository->get_conf( "editor_limit_fields" );
	#foreach my $sv ( @{ $user->get_value( "editperms" ) } )
	#{
	#	my $data = EPrints::Search::Field->unserialise( $sv );
	#}
	
	if( defined $sort_order && $sort_order ne "" )
	{
		my $order = $self->{session}->get_repository->get_conf( "order_methods" , "eprint.review", $sort_order );
		$list = $list->reorder( $order );
	}

	# Headers for paginated list
	my $table = $self->{session}->make_element( "table", border=>0, cellpadding=>4, cellspacing=>0, width=>"100%" );
	my $tr = $self->{session}->make_element( "tr", class=>"header_plain" );
	$table->appendChild( $tr );
	
	my $th = $self->{session}->make_element( "th" );
	$th->appendChild( $self->{session}->html_phrase( "cgi/users/buffer:title" ) );
	$tr->appendChild( $th );

	$th = $self->{session}->make_element( "th" );
	$th->appendChild( $self->{session}->html_phrase( "cgi/users/buffer:sub_by" ) );
	$tr->appendChild( $th );

	$th = $self->{session}->make_element( "th" );
	$th->appendChild( $self->{session}->html_phrase( "cgi/users/buffer:sub_date" ) );
	$tr->appendChild( $th );
	
	my $info = {row => 1};
	my %opts = (
		params => {
			screen => "Review",
			_order => defined $sort_order ? $sort_order : "",
		},
		container => $table,
		pins => {
			searchdesc => $self->_get_scope( $user ),
		},
		render_result_params => $info,
		render_result => sub {
			my( $session, $e, $info ) = @_;

			my $tr = $session->make_element( "tr", class=>"row_".($info->{row}%2?"b":"a") );

			# Title
			my $td = $session->make_element( "td", class=>"first_col" );
			$tr->appendChild( $td );
			my $link = $session->render_link( "?screen=EPrint::View::Editor&eprintid=".$e->get_value("eprintid") );
			$link->appendChild( $e->render_description() );
			$td->appendChild( $link );
		
			# Link to user
			my $user = new EPrints::User( $session, $e->get_value( "userid" ) );
		
			$td = $session->make_element( "td", class=>"middle_col" );
			$tr->appendChild( $td );
			if( defined $user )
			{
				#cjg Has view-user priv?
				$td->appendChild( $user->render_citation_link( undef, 1 ) );
			}
			else
			{
				$td->appendChild( $session->html_phrase( "cgi/users/buffer:invalid" ) );
			}
	
			my $buffds = $session->get_repository->get_dataset( "buffer" );	
		
			$td = $session->make_element( "td", class=>"last_col" );
			$tr->appendChild( $td );
			$td->appendChild( $buffds->get_field( "status_changed" )->render_value( $session, $e->get_value( "status_changed" ) ) );
			++$info->{row};

			return $tr;
		},
	);
	$page->appendChild( EPrints::Paginate->paginate_list( $self->{session}, $basename, $list, %opts ) );


	return $page;
}

sub _get_scope
{
	my( $self, $user ) = @_;
	if( $user->is_set( "editperms" ) )
	{
		return $user->render_value( "editperms" );
	}
	else
	{
		return $self->{session}->html_phrase( "lib/metafield:unspecified_editperms" );
	}
}

# ignore the form. We're screwed at this point, and are just reporting.
sub from
{
	my( $self ) = @_;

	return;
}




1;
