=head1 NAME

EPrints::Plugin::Screen::Admin::Config

=cut

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

	$self->{actions} = [qw( add_file )];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	$self->{processor}->{relpath} = $self->{session}->param( "relpath" );
	$self->{processor}->{relpath} = ""
		if !defined $self->{processor}->{relpath};
	my $filename = $self->{session}->param( "filename" );
	if( $filename =~ /^[a-zA-Z0-9_][a-zA-Z0-9_\.]+$/ ) {
		$self->{processor}->{filename} = $filename;
	}
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/view" );
}

sub allow_add_file
{
	my( $self ) = @_;

	# allows error to go through to the action
	return 1 if !defined $self->{processor}->{filename};

	my $screen = $self->edit_plugin(
		$self->{processor}->{relpath},
		$self->{processor}->{filename}
	);

	return defined($screen) && $screen->can_be_viewed;
}

sub action_add_file
{
	my( $self ) = @_;

	my $processor = $self->{processor};

	my $filename = $processor->{filename};
	if( !defined $filename )
	{
		$processor->add_message( "error", $self->html_phrase( "bad_file") );
		return;
	}
 
	my $relpath = $self->{processor}->{relpath};

	my $path = $self->{session}->config( "config_path" );
	my $filepath = "$path/$relpath$filename";

	if( !-e $filepath )
	{
		if( open(my $fh, ">", $filepath) )
		{
			close($fh);
		}
		else
		{
			$processor->add_message( "error", $self->{session}->make_text( $! ) );
			return;
		}
	}

	my $screen = $self->edit_plugin( $relpath, $filename );

	$self->{processor}->{configfile} = "$relpath$filename";
	$self->{processor}->{screenid} = $screen->get_subtype;
}

sub edit_plugin
{
	my( $self, $relpath, $filename ) = @_;

	return if !EPrints::Utils::is_set( $filename );

	my $configtype = config_file_to_type( "$relpath$filename" );

	return $self->{session}->plugin( 
		"Screen::Admin::Config::View::$configtype",
		processor => $self->{processor} );
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;

	my $path = $session->config( "config_path" );

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

	my $xhtml = $self->{session}->xhtml;

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
	$div->appendChild($self->{session}->make_element( "a",
		name => $relpath
	));
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
	
		my $url = URI->new( $self->{session}->current_url );
		$url->query_form(
			screen => "Admin::Config::View::$configtype",
			configfile => "$relpath$file",
		);
		my $link = $self->{session}->render_link( $url );
		$div_title->appendChild( $link );
		$link->appendChild( $self->{session}->make_text( $file ) );
	}
	my $form = $self->render_form;
	$div->appendChild( $form );
	$form->appendChild( $xhtml->hidden_field( "relpath", $relpath ) );
	$form->appendChild( $xhtml->input_field( "text", undef,
		name => "filename",
	) );
	$form->appendChild( $self->{session}->render_button(
		type => "submit",
		name => "_action_add_file",
		value => $self->phrase( "add_file" )
	) );

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

