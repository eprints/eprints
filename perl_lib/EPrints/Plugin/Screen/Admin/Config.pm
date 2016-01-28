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

	$self->{actions} = [qw( add_file add_directory delete confirm cancel )];

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

sub allow_cancel { 1 }
sub action_cancel {}

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
sub allow_add_directory
{
	my( $self ) = @_;

	# allows error to go through to the action
	return 1 if !defined $self->{processor}->{filename};

	return $self->allow( "config/edit/static" );
}
sub allow_confirm { return shift->allow_delete( @_ ); }
sub allow_delete
{
	my( $self ) = @_;

	return $self->allow( "config/delete/static" );
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

sub action_add_directory
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
		if( EPrints->system->mkdir( $filepath ) )
		{
		}
		else
		{
			$processor->add_message( "error", $self->{session}->make_text( $! ) );
			return;
		}
	}
}

sub action_delete
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $path = $repo->config( "config_path" );
	my $relpath = $repo->param( "configfile" );

	my $frag = $repo->xml->create_document_fragment;

	$frag->appendChild( $repo->html_phrase( "Plugin/Screen/Workflow/Destroy:sure_delete",
		title => $repo->xml->create_text_node( "$path/$relpath" ),
	) );
	my $form = $frag->appendChild( $self->render_form );
	$form->appendChild( $repo->xhtml->hidden_field( "configfile", $relpath ) );
	$form->appendChild( $repo->render_action_buttons(
		confirm => $repo->phrase( "lib/submissionform:action_confirm" ),
		cancel => $repo->phrase( "lib/submissionform:action_cancel" ),
		_order => [qw( confirm cancel )],
	) );

	$self->{processor}->add_message( "warning", $frag );
}

sub action_confirm
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $path = $repo->config( "config_path" );

	my $relpath = $repo->param( "configfile" );
	return if $relpath =~ /^\./ || $relpath =~ m#[\\/]\.#;

	my $rc = 0;

	if( -d "$path/$relpath" )
	{
		$rc = rmdir( "$path/$relpath" );
	}
	else
	{
		$rc = scalar unlink( "$path/$relpath" );
	}

	if( $rc )
	{
		$self->{processor}->add_message( "message", $repo->html_phrase( "Plugin/Screen/EPrint/RemoveWithEmail:item_removed" ) );
	}
	else
	{
		$self->{processor}->add_message( "error", $repo->xml->create_text_node( $! ) );
	}
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

#	my $path_div = $session->make_element( "div", style=>"padding-bottom: 0.5em" );
#	$path_div->appendChild( $session->make_text( $path ));
#	$page->appendChild( $path_div );

	# build a tree of all of the configuration files
	my $tree = [ undef, [] ]; # this is a dummy root element
	my @stack = ($tree);
	my $dirlen = length($path) - 1;

	File::Find::find({
		no_chdir => 1,
		preprocess => sub {
			my $filename = substr($File::Find::dir, $dirlen);
			my $ctree = [{
				filename => $filename,
				path => substr($File::Find::dir,length($path)+1)
			}, []];
			push @{$tree->[1]}, $ctree;
			push @stack, $tree = $ctree;
			$dirlen += length($filename) + 1;
			return sort grep {
				$_ !~ /^\./ &&
				$_ !~ /\.backup$/ &&
				$_ !~ /\.broken$/
			} @_;
		},
		wanted => sub {
			$tree->[0]->{contents}++;
			return if -d $File::Find::name;
			my $filename = substr($File::Find::name,length($File::Find::dir)+1);
			my $relpath = substr($File::Find::dir,length($path)+1);
			$relpath .= '/' if $relpath;
			# must use HASH because ARRAYs mean more tree structure
			push @{$tree->[1]}, {
				filename => $filename,
				path => $relpath,
			};
		},
		postprocess => sub {
			my $relpath = substr($File::Find::dir,length($path)+1);
			$relpath .= '/' if $relpath;
			push @{$tree->[1]}, $self->render_add_file( $relpath );
			$dirlen -= length($tree->[0]->{filename}) + 1;
			pop @stack;
			$tree = $stack[$#stack];
		},
	}, $path);

	# move to the first directory and set it to the complete path name
	$tree = $tree->[1];
	$tree->[0]->[0] = {
		filename => $path,
		path => undef,
	};

	# open the root directory (suppress default display:none)
	push @{$tree->[0]}, show => 1;

#EPrints->dump( $tree );

	$page->appendChild( $session->xhtml->tree( $tree,
		prefix => "ep_fileselector",
		render_value => sub { $self->_render_value( @_ ) },
	) );

	# some text like "EPrints configuration editor; with great power comes great responsibility" ?
#	$page->appendChild( $self->render_dir( $path, "" ) );

	return $page;
}

sub _render_value
{
	my( $self, $ctx, $children ) = @_;

	return $ctx if ref($ctx) ne "HASH";

	my $session = $self->{session};

	my $filename = $ctx->{filename};
	my $relpath = $ctx->{path};

	my $frag = $session->make_doc_fragment;

	# directory
	if( defined $children )
	{
		$frag->appendChild( $session->make_text( $filename ) );

		if( defined $relpath && !$ctx->{contents} )
		{
			my $url = URI->new( $session->current_url );
			$frag->appendChild( $session->make_text( " [ " ) );
			$url->query_form(
				$self->hidden_bits,
				configfile => $relpath,
				_action_delete => "1",
			);
			my $link = $session->render_link( $url );
			$link->appendChild( $session->html_phrase( "lib/submissionform:delete" ) );
			$frag->appendChild( $link );
			$frag->appendChild( $session->make_text( " ] " ) );
		}
	}
	# editable file
	elsif( defined(my $configtype = config_file_to_type( "$relpath$filename" )) )
	{
		my $url = URI->new( $session->current_url );
		$url->query_form(
			screen => "Admin::Config::View::$configtype",
			configfile => "$relpath$filename",
		);
		my $link = $session->render_link( $url,
			target => "_blank",
		);
		$link->appendChild( $session->make_text( $filename ) );
		$frag->appendChild( $link );
		$frag->appendChild( $session->make_text( " [ " ) );
		$url->query_form(
			$self->hidden_bits,
			configfile => "$relpath$filename",
			_action_delete => "1",
		);
		$link = $session->render_link( $url );
		$link->appendChild( $session->html_phrase( "lib/submissionform:delete" ) );
		$frag->appendChild( $link );
		$frag->appendChild( $session->make_text( " ] " ) );
	}
	# plain file
	else
	{
		$frag->appendChild( $session->make_text( $filename ) );
	}

	return $frag;
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

sub render_add_file
{
	my( $self, $relpath ) = @_;

	my $xhtml = $self->{session}->xhtml;

	my $form = $self->render_form;
	$form->appendChild( $xhtml->hidden_field( "relpath", $relpath ) );
	$form->appendChild( $xhtml->input_field( "text", undef,
		name => "filename",
	) );
	$form->appendChild( $self->{session}->render_button(
		type => "submit",
		name => "_action_add_file",
		value => $self->phrase( "add_file" )
	) );
	$form->appendChild( $self->{session}->render_button(
		type => "submit",
		name => "_action_add_directory",
		value => $self->phrase( "add_directory" )
	) );

	return $form;
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

