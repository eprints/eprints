=head1 NAME

EPrints::Plugin::Screen::Import

=cut


package EPrints::Plugin::Screen::Import;

use EPrints::Plugin::Screen;

use Fcntl qw(:DEFAULT :seek);

our $MAX_ERR_LEN = 1024;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

our @ENCODINGS = (
	"UTF-8",
	grep { $_ =~ /^iso|cp|UTF/ } Encode->encodings( ":all" )
);
{
my $f = sub {
	my $s = lc($_[0]);
	$s = join '',
		map { $_ =~ /[0-9]/ ? sprintf("%10d", $_) : $_ }
		split /([^0-9]+)/, $s;
	return $s;
};
@ENCODINGS = sort {
	&$f($a) cmp &$f($b)
} @ENCODINGS;
}

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ import_from test_data import_data test_upload import_upload /];

#	$self->{appears} = [
#		{
#			place => "item_tools",
#			position => 200,
#		}
#	];

	if( $self->{session} )
	{
		# screen to go to after a single item import
		$self->{post_import_screen} = $self->param( "post_import_screen" );
		$self->{post_import_screen} ||= "EPrint::Edit";

		# screen to go to after a bulk import
		$self->{post_bulk_import_screen} = $self->param( "post_bulk_import_screen" );
		$self->{post_bulk_import_screen} ||= "Items";
	}

	$self->{show_stderr} = 1;

	$self->{encodings} = \@ENCODINGS;
	$self->{default_encoding} = "iso-8859-1";

	return $self;
}

sub properties_from
{
	my( $self ) = @_;
	
	$self->SUPER::properties_from;

	my $plugin_id = $self->{session}->param( "format" );

	# dataset to import into
	$self->{processor}->{dataset} = $self->{session}->get_repository->get_dataset( "inbox" );

	if( defined $plugin_id )
	{
		my $plugin = $self->{session}->plugin(
			"Import::$plugin_id",
			session => $self->{session},
			dataset => $self->{processor}->{dataset},
			processor => $self->{processor},
		);
		if( !defined $plugin || $plugin->broken )
		{
			$self->{processor}->add_message( "error", $self->{session}->html_phrase( "general:bad_param" ) );
			return;
		}

		if( !($plugin->can_produce( "list/eprint" ) || $plugin->can_produce( "dataobj/eprint" )) )
		{
			$self->{processor}->add_message( "error", $self->{session}->html_phrase( "general:bad_param" ) );
			return;
		}

		$self->{processor}->{plugin} = $plugin;
		$self->{processor}->{plugin_id} = $plugin_id;
	}

	$self->{processor}->{encoding} = $self->{session}->param( "encoding" );
}

sub can_be_viewed
{
	my( $self ) = @_;
	return $self->allow( "create_eprint" );
}

sub allow_import_from { shift->can_be_viewed }
sub allow_test_data { shift->can_be_viewed }
sub allow_import_data { shift->can_be_viewed }
sub allow_test_upload { shift->can_be_viewed }
sub allow_import_upload { shift->can_be_viewed }

sub action_import_from
{
	my( $self ) = @_;

	my $plugin = $self->{processor}->{plugin};
	
	my $screenid = $plugin->param( "screen" );
	if( defined $screenid )
	{
		$self->{processor}->{screenid} = $screenid;
	}
}

sub action_test_data
{
	my ( $self ) = @_;

	$self->{processor}->{current} = 0;
	$self->{processor}->{encoding} = "UTF-8";

	my $tmpfile = File::Temp->new;
	binmode($tmpfile, ":utf8");
	print $tmpfile scalar($self->{repository}->param( "data" ));
	seek($tmpfile, 0, 0);

	my $list = $self->run_import( 1, 0, $tmpfile ); # dry run with messages
	$self->{processor}->{results} = $list;
}

sub action_test_upload
{
	my ( $self ) = @_;

	$self->{processor}->{current} = 1;

	my $tmpfile = $self->{repository}->get_query->upload( "file" );
	return if !defined $tmpfile;
	$tmpfile = *$tmpfile; # CGI file handles aren't proper handles
	return if !defined $tmpfile;

	my $list = $self->run_import( 1, 0, $tmpfile ); # dry run with messages
	$self->{processor}->{results} = $list;
}

sub action_import_data
{
	my( $self ) = @_;

	$self->{processor}->{current} = 0;
	$self->{processor}->{encoding} = "UTF-8";

	my $tmpfile = File::Temp->new;
	binmode($tmpfile, ":utf8");
	print $tmpfile scalar($self->{repository}->param( "data" ));
	seek($tmpfile, 0, 0);

	my $list = $self->run_import( 0, 0, $tmpfile ); # real run with messages
	return if !defined $list;

	$self->{processor}->{results} = $list;

	$self->post_import( $list );
}

sub action_import_upload
{
	my( $self ) = @_;

	$self->{processor}->{current} = 1;

	my $tmpfile = $self->{repository}->get_query->upload( "file" );
	return if !defined $tmpfile;

	$tmpfile = *$tmpfile; # CGI file handles aren't proper handles
	return if !defined $tmpfile;

	$self->{processor}->{filename} = $self->{repository}->get_query->param( "file" );

	my $list = $self->run_import( 0, 0, $tmpfile ); # real run with messages
	return if !defined $list;

	$self->{processor}->{results} = $list;

	$self->post_import( $list );
}

sub post_import
{
	my( $self, $list ) = @_;

	my $processor = $self->{processor};

	my $n = $list->count;

	if( $n == 1 )
	{
		my( $eprint ) = $list->get_records( 0, 1 );
		# add in eprint/eprintid for backwards compatibility
		$processor->{dataobj} = $processor->{eprint} = $eprint;
		$processor->{dataobj_id} = $processor->{eprintid} = $eprint->get_id;
		$processor->{screenid} = $self->{post_import_screen};
	}
	elsif( $n > 1 )
	{
		$processor->{screenid} = $self->{post_bulk_import_screen};
	}
}

sub epdata_to_dataobj
{
	my( $self, $epdata, %opts ) = @_;

	$self->{processor}->{count}++;
			
	my $dataset = $opts{dataset};
	if( $dataset->base_id eq "eprint" )
	{
		$epdata->{userid} = $self->{repository}->current_user->id;
		$epdata->{eprint_status} = "inbox";
	}	

	return undef if $opts{parse_only};

	return $dataset->create_dataobj( $epdata );
}

sub arguments
{
	my( $self ) = @_;

	return ();
}

sub run_import
{
	my( $self, $dryrun, $quiet, $tmp_file ) = @_;

	seek($tmp_file, 0, SEEK_SET);

	my $session = $self->{session};
	my $dataset = $self->{processor}->{dataset};
	my $user = $self->{processor}->{user};
	my $plugin = $self->{processor}->{plugin};
	my $show_stderr = $session->config(
		"plugins",
		"Screen::Import",
		"params",
		"show_stderr"
		);
	$show_stderr = $self->{show_stderr} if !defined $show_stderr;

	$self->{processor}->{count} = 0;

	$plugin->{parse_only} = $dryrun;
	$plugin->set_handler( EPrints::CLIProcessor->new(
		message => sub { !$quiet && $self->{processor}->add_message( @_ ) },
		epdata_to_dataobj => sub {
			return $self->epdata_to_dataobj(
				@_,
				parse_only => $dryrun,
			);
		},
	) );

	my $err_file;
	if( $show_stderr )
	{
		$err_file = EPrints->system->capture_stderr();
	}

	my @problems;

	my @actions;
	foreach my $action (@{$plugin->param( "actions" )})
	{
		push @actions, $action
			if scalar($session->param( "action_$action" ));
	}

	# Don't let an import plugin die() on us
	my $list = eval {
		$plugin->input_fh(
			$self->arguments,
			dataset=>$dataset,
			fh=>$tmp_file,
			user=>$user,
			filename=>$self->{processor}->{filename},
			actions=>\@actions,
			encoding=>$self->{processor}->{encoding},
		);
	};

	if( $show_stderr )
	{
		EPrints->system->restore_stderr( $err_file );
	}

	if( $@ )
	{
		if( $show_stderr )
		{
			push @problems, [
				"error",
				$session->phrase( "Plugin/Screen/Import:exception",
					plugin => $plugin->{id},
					error => $@,
				),
			];
		}
		else
		{
			$session->log( $@ );
			push @problems, [
				"error",
				$session->phrase( "Plugin/Screen/Import:exception",
					plugin => $plugin->{id},
					error => "See Apache error log file",
				),
			];
		}
	}
	elsif( !defined $list && !@{$self->{processor}->{messages}} )
	{
		push @problems, [
			"error",
			$session->phrase( "Plugin/Screen/Import:exception",
				plugin => $plugin->{id},
				error => "Plugin returned undef",
			),
		];
	}

	my $count = $self->{processor}->{count};

	if( $show_stderr )
	{
		my $err;
		sysread($err_file, $err, $MAX_ERR_LEN);
		$err =~ s/\n\n+/\n/g;

		if( length($err) )
		{
			push @problems, [
				"warning",
				$session->phrase( "Plugin/Screen/Import:warning",
					plugin => $plugin->{id},
					warning => $err,
				),
			];
		}
	}

	foreach my $problem (@problems)
	{
		my( $type, $message ) = @$problem;
		$message =~ s/^(.{$MAX_ERR_LEN}).*$/$1 .../s;
		$message =~ s/\t/        /g; # help _mktext out a bit
		$message = join "\n", EPrints::DataObj::History::_mktext( $session, $message, 0, 0, 80 );
		my $pre = $session->make_element( "pre" );
		$pre->appendChild( $session->make_text( $message ) );
		$self->{processor}->add_message( $type, $pre );
	}

	my $ok = (scalar(@problems) == 0 and $count > 0);

	if( $dryrun )
	{
		if( $ok )
		{
			$self->{processor}->add_message( "message", $session->html_phrase(
				"Plugin/Screen/Import:test_completed", 
				count => $session->make_text( $count ) ) ) unless $quiet;
		}
		else
		{
			$self->{processor}->add_message( "warning", $session->html_phrase( 
				"Plugin/Screen/Import:test_failed", 
				count => $session->make_text( $count ) ) );
		}
	}
	else
	{
		if( $ok )
		{
			$self->{processor}->add_message( "message", $session->html_phrase( 
				"Plugin/Screen/Import:import_completed", 
				count => $session->make_text( $count ) ) );
		}
		else
		{
			$self->{processor}->add_message( "warning", $session->html_phrase( 
				"Plugin/Screen/Import:import_failed", 
				count => $session->make_text( $count ) ) );
		}
	}

	return $list;
}

sub redirect_to_me_url { }

sub render_title
{
	my( $self ) = @_;

	return $self->{session}->html_phrase( "Plugin/Screen/Import:title",
		input => $self->{processor}->{plugin}->render_name );
}

sub render
{
	my ( $self ) = @_;

	my $session = $self->{session};
	my $plugin = $self->{processor}->{plugin};

	my @labels;
	my @panels;

	push @labels, $self->html_phrase( "data" );
	push @panels, $self->render_import_form;

	push @labels, $self->html_phrase( "upload" );
	push @panels, $self->render_upload_form;

	my $base_url = $session->current_url;
	$base_url->query_form( $self->hidden_bits );

	return $session->xhtml->tabs( \@labels, \@panels,
		base_url => $base_url,
		current => $self->{processor}->{current},
	);
}

sub render_actions
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;
	my $plugin = $self->{processor}->{plugin};

	my $ul = $self->{session}->make_element( "ul",
		style => "list-style-type: none"
	);

	foreach my $action (sort @{$plugin->param( "actions" )})
	{
		my $li = $xml->create_element( "li" );
		$ul->appendChild( $li );
		my $action_id = "action_$action";
		my $checkbox = $xml->create_element( "input",
			type => "checkbox",
			name => $action_id,
			id => $action_id,
			value => "yes",
			checked => "yes",
		);
		$li->appendChild( $checkbox );
		my $label = $xml->create_element( "label",
			for => $action_id,
		);
		$li->appendChild( $label );
		$label->appendChild( $plugin->html_phrase( $action_id ) );
	}

	return $ul->hasChildNodes ? $ul : $xml->create_document_fragment;
}

sub render_import_form
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $div = $xml->create_element( "div", class => "ep_block ep_sr_component" );

	my $form = $div->appendChild( $self->{processor}->screen->render_form );
	$form->appendChild(EPrints::MetaField->new(
			name => "data",
			type => "longtext",
			repository => $repo,
		)->render_input_field(
			$repo,
			scalar($repo->param( "data" )),
		) );
	$form->appendChild( $self->render_actions );
	$form->appendChild( $repo->render_action_buttons(
		test_data => $repo->phrase( "Plugin/Screen/Import:action_test_data" ),
		import_data => $repo->phrase( "Plugin/Screen/Import:action_import_data" ),
		_order => [qw( test_data import_data )],
	) );

	return $div;
}

sub render_upload_form
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $div = $xml->create_element( "div", class => "ep_block" );

	my $form = $div->appendChild( $self->{processor}->screen->render_form );
	$form->appendChild( $xhtml->input_field(
		file => undef,
		type => "file"
		) );
	$form->appendChild( $repo->render_option_list(
		name => "encoding",
		default => ($repo->param( "encoding" ) || $self->param( "default_encoding" )),
		values => $self->param( "encodings" ),
		labels => {
			map { $_ => $_ } @{$self->param( "encodings" )},
		},
	) );
	$form->appendChild( $self->render_actions );
	$form->appendChild( $repo->render_action_buttons(
		test_upload => $repo->phrase( "Plugin/Screen/Import:action_test_upload" ),
		import_upload => $repo->phrase( "Plugin/Screen/Import:action_import_upload" ),
		_order => [qw( test_upload import_upload )],
	) );

	return $div;
}

sub _vis_level
{
	my( $self ) = @_;

	return "all";
}

sub _get_import_plugins
{
	my( $self ) = @_;

	my %opts =  (
			type=>"Import",
			is_advertised => 1,
#			can_produce=>"list/eprint",
			is_visible=>$self->_vis_level,
	);

	return
		$self->{session}->plugin_list( %opts, can_produce => "list/eprint" ),
		$self->{session}->plugin_list( %opts, can_produce => "dataobj/eprint" );
}

sub render_action_button
{
	my( $self, $params, $asicon ) = @_;

	return $self->render_import_bar;
}

sub render_import_bar
{
	my( $self ) = @_;

	my $session = $self->{session};

	my @plugins = $self->_get_import_plugins;
	if( scalar @plugins == 0 ) 
	{
		return $session->make_doc_fragment;
	}

	my $tools = $session->make_doc_fragment;
	my $options = {};
	foreach my $plugin_id ( @plugins ) 
	{
		$plugin_id =~ m/^[^:]+::(.*)$/;
		my $id = $1;
		my $plugin = $session->plugin( $plugin_id );
		my $dom_name = $plugin->render_name;
		if( $plugin->is_tool )
		{
			my $type = "tool";
			my $span = $session->make_element( "span", class=>"ep_search_$type" );
			my $url = $self->export_url( $id );
			my $a1 = $session->render_link( $url );
			my $icon = $session->make_element( "img", src=>$plugin->icon_url(), alt=>"[$type]", border=>0 );
			$a1->appendChild( $icon );
			my $a2 = $session->render_link( $url );
			$a2->appendChild( $dom_name );
			$span->appendChild( $a1 );
			$span->appendChild( $session->make_text( " " ) );
			$span->appendChild( $a2 );

			$tools->appendChild( $session->make_text( " " ) );
			$tools->appendChild( $span );	
		}
		else
		{
			my $option = $session->make_element( "option", value=>$id );
			# EPrints Services/tmb select default plugin
			my $default = $self->param( "default_import_plugin" );
			$option->setAttribute( "selected", "selected" ) if EPrints::Utils::is_set( $default ) && $default eq $plugin_id;
			# EPrints Services/tmb end
			$option->appendChild( $dom_name );
			$options->{EPrints::XML::to_string($dom_name)} = $option;
		}
	}

	my $select = $session->make_element( "select", name=>"format" );
	foreach my $optname ( sort keys %{$options} )
	{
		$select->appendChild( $options->{$optname} );
	}
	my $button = $session->make_doc_fragment;
	$button->appendChild( $session->render_button(
			name=>"_action_import_from",
			value=>$self->phrase( "action:import_from:title" ) ) );
	$button->appendChild( 
		$session->render_hidden_field( "screen", substr($self->{id},8) ) ); 

	my $form = $session->render_form( "GET" );
	$form->appendChild( $self->html_phrase( "import_section",
					tools => $tools,
					menu => $select,
					button => $button ));

	return $form;
}

sub hidden_bits
{
	my( $self ) = @_;

	return(
		$self->SUPER::hidden_bits,
		format => scalar($self->{repository}->param( "format" )),
	);
}

package EPrints::Plugin::Screen::Import::Handler;

sub new
{
	my( $class, %self ) = @_;

	$self{wrote} = 0;
	$self{parsed} = 0;

	bless \%self, $class;
}

sub message
{
	my( $self, $type, $msg ) = @_;

	unless( $self->{quiet} )
	{
		$self->{processor}->add_message( $type, $msg );
	}
}

sub epdata_to_dataobj
{
	my( $self, $epdata, %opts ) = @_;

	$self->{parsed}++;

	return if $self->{dryrun};

	my $dataset = $opts{dataset};
	if( $dataset->base_id eq "eprint" )
	{
		$epdata->{userid} = $self->{user}->id;
		$epdata->{eprint_status} = "inbox";
	}	

	$self->{wrote}++;

	return $dataset->create_dataobj( $epdata );
}

sub parsed { }
sub object { }

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

