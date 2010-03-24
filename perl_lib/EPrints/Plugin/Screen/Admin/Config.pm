package EPrints::Plugin::Screen::Admin::Config;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{ 
			place => "admin_actions_config", 
			position => 1300, 
		},
	];
	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/view" );
}


sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;

	my $path = $session->get_repository->get_conf( "config_path" );

	my $page = $session->make_doc_fragment;

	my $path_div = $session->make_element( "div", style=>"padding-bottom: 0.5em" );
	$path_div->appendChild( $session->make_text( $path ));
	$page->appendChild( $path_div );

	# some text like "EPrints configuration editor; with great power comes great responsibility" ?
	$page->appendChild( $self->render_dir( $path, "" ) );

	return $page;
}

sub render_dir
{
	my( $self, $realpath, $relpath ) = @_;

	my $dh;
	opendir( $dh, $realpath );
	my @files = ();
	while( my $file = readdir( $dh ) )
	{
		next if( $file =~ m/^\./ );
		next if( $file =~ m/\.broken$/ );
		next if( $file =~ m/\.backup$/ );
		push @files, $file;
	}
	closedir( $dh );

	my $div = $self->{session}->make_element( "div", style=>"margin-left: 3em; padding: 0.5em 0 0.5em 0; border-left: 1px solid blue" );
	foreach my $file ( sort @files )
	{
		my $div_title = $self->{session}->make_element( "div", style=>"padding: 0.25em 0 0.25em 0;" );
		$div->appendChild( $div_title );
		$div_title->appendChild( $self->{session}->make_text( "-- " ) );
		if( -d "$realpath/$file" )
		{
			$div_title->appendChild( $self->{session}->make_text( $file ) );
			$div_title->appendChild( $self->{session}->make_text( "/" ) );
			$div->appendChild( $self->render_dir( "$realpath/$file", "$relpath$file/" ) );
			next;
		}

		# is a file
		my $configtype = config_file_to_type( $relpath.$file );
		my $view = 0;
		if( defined $configtype )
		{
			my $screen = $self->{session}->plugin( 
				"Screen::Admin::Config::View::$configtype",
				processor => $self->{processor} );
			$view = 1 if( $screen->can_be_viewed );
		}

			
		if( !$view )
		{
			# not allowed to view this kind of config file
			$div_title->appendChild( $self->{session}->make_text( $file ) );
			next;
		}
	
		my $url = "?screen=Admin::Config::View::$configtype&configfile=$relpath$file";
		my $link = $self->{session}->render_link( $url );
		$div_title->appendChild( $link );
		$link->appendChild( $self->{session}->make_text( $file ) );
	}
	return $div;
}

sub config_file_to_type
{
	my( $configfile ) = @_;

	return "Apache" if( $configfile eq "apache.conf" );
	return "Apache" if( $configfile eq "apachevhost.conf" );

	return "Autocomplete" if( $configfile =~ m#^autocomplete/# );

	return "Perl" if( $configfile =~ m#^cfg.d/[^/]+\.pl$# );
	return "Perl" if( $configfile =~ m#^plugins/.*\.pm$# );

	return "Citation" if( $configfile =~ m#^citations/[a-z]+/[^/]+\.xml$# );

	return "Phrase" if( $configfile =~ m#^lang/[^/]+/phrases/[^/]+\.xml$# );

	return "XPage" if( $configfile =~ m#^lang/[^/]+/static/.*\.xpage$# );
	return "Static" if( $configfile =~ m#^lang/[^/]+/static/# );

	return "Template" if( $configfile =~ m#^lang/[^/]+/templates/[^/]+\.xml$# );

	return "NamedSet" if( $configfile =~ m#^namedsets/[a-z0-9_]+$# );

	return "XPage" if( $configfile =~ m#^static/.*\.xpage$# );
	return "Static" if( $configfile =~ m#^static/# );

	return "Workflow" if( $configfile =~ m#^workflows/[a-z]+/[^/]+\.xml$# );

	return "XML" if( $configfile =~ m#\.xml$# );

	return;
}


1;
