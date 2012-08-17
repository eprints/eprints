=head1 NAME

EPrints::Plugin::Screen::Import::Upload

=cut


package EPrints::Plugin::Screen::Import::Upload;

use base qw( EPrints::Plugin::Screen::Import );

use Fcntl qw(:DEFAULT :seek);

our $MAX_ERR_LEN = 1024;

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

	push @{$self->{appears}}, {
			place => "user_tasks",
			position => 500,
		};

	push @{$self->{actions}}, qw/ upload paste /;

	$self->{post_import_screen} = "EPrint::Edit";
	$self->{post_bulk_import_screen} = "Items";

	$self->{show_stderr} = 1;

	$self->{encodings} = \@ENCODINGS;
	$self->{default_encoding} = "iso-8859-1";

	$self->{bulk_import_limit} = 30;
	$self->{bulk_import_warn} = 10;

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	my $datasetid = $self->{session}->param( "dataset" );
	if( $datasetid )
	{
		$self->{processor}->{dataset} = $self->{session}->dataset( $datasetid );
		EPrints->abort( "Invalid dataset" ) if !defined $self->{processor}->{dataset};
	}

	my $plugin_id = $self->{processor}->{format};

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

	$self->{processor}->{plugin} = $plugin;

	my $cache_dataset = $self->{session}->dataset( "cache_dataobj_map" );
	foreach my $key ($self->{session}->param)
	{
		if( $key =~ /^cache_(.+)$/ )
		{
			my $cache_id = $self->{session}->param( $key );
			$self->{processor}->{results}->{$1} = $cache_dataset->dataobj( $cache_id );
		}
	}
}

sub action_import_from
{
	my( $self ) = @_;

	delete $self->{processor}->{results};

	return $self->SUPER::action_import_from;
}

sub hidden_bits
{
	my( $self ) = @_;

	my @hidden_bits = $self->SUPER::hidden_bits;

	foreach my $datasetid (keys %{$self->{processor}->{results} || {}})
	{
		push @hidden_bits, 
			"cache_$datasetid" => $self->{processor}->{results}->{$datasetid}->id;
	}

	if( defined $self->{processor}->{dataset} )
	{
		push @hidden_bits, dataset => $self->{processor}->{dataset}->base_id;
	}

	return @hidden_bits;
}

sub action_add
{
	my( $self ) = @_;

	my $datasetid = $self->{processor}->{dataset}->base_id;

	local $self->{processor}->{results} = $self->{processor}->{results}->{$datasetid};

	return $self->SUPER::action_add;
}

sub action_all
{
	my( $self ) = @_;

	my $datasetid = $self->{processor}->{dataset}->base_id;

	local $self->{processor}->{results} = $self->{processor}->{results}->{$datasetid};

	return $self->SUPER::action_add;
}

sub action_confirm_all
{
	my( $self ) = @_;

	my $datasetid = $self->{processor}->{dataset}->base_id;

	local $self->{processor}->{results} = $self->{processor}->{results}->{$datasetid};

	return $self->SUPER::action_add;
}

sub allow_paste { shift->can_be_viewed }
sub allow_upload { shift->can_be_viewed }

sub action_paste
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $plugin = $self->{processor}->{plugin};
	
	my $data = $repo->param( "data" );

	my $tmpfile = File::Temp->new;
	binmode($tmpfile, ":utf8");
	print $tmpfile $data;
	seek($tmpfile, 0, 0);

	my $total = $self->run_import(
			fh => $tmpfile,
			offset => 0,
		);
}

sub action_upload
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $plugin = $self->{processor}->{plugin};
	
	my $tmpfile = $self->{repository}->get_query->upload( "file" );
	return if !defined $tmpfile;

	$tmpfile = *$tmpfile; # CGI file handles aren't proper handles
	return if !defined $tmpfile;
	seek($tmpfile, 0, 0);

	my $total = $self->run_import(
			fh => $tmpfile,
			filename => scalar($repo->get_query->param( "file" )),
			encoding => scalar($repo->param( "encoding" )),
			offset => 0,
		);
}

sub epdata_to_dataobj
{
	my( $self, $epdata, %opts ) = @_;

	my $repo = $self->repository;

	$self->{count}++;

	my $dataset = $opts{dataset};
	if( $dataset->base_id eq "eprint" )
	{
		$epdata->{userid} = $self->{repository}->current_user->id;
		$epdata->{eprint_status} = "inbox";
	}

	my $cache = $self->{processor}->{results}->{$dataset->base_id};
	if( !defined $cache )
	{
		$cache = $repo->dataset( "cache_dataobj_map" )->create_dataobj({
				userid => $repo->current_user->id,
				count => 0,
			});
		$self->{processor}->{results}->{$dataset->base_id} = $cache;
	}

	$cache->create_subdataobj( "dataobjs", {
			pos => $cache->value( "count" ) + 1, # 1-indexed
			datasetid => $opts{dataset}->base_id,
			epdata => $epdata,
		});
	$cache->set_value( "count", $cache->value( "count" ) + 1 );
	$cache->commit;

	return undef;
}

sub run_import
{
	my( $self, %opts ) = @_;

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

	$plugin->set_handler( EPrints::CLIProcessor->new(
		message => sub { !$opts{quiet} && $self->{processor}->add_message( @_ ) },
		epdata_to_dataobj => sub {
			return $self->epdata_to_dataobj( @_ );
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

	my $f = defined $opts{fh} ? "input_fh" : "input_form";

	local $self->{offset} = $opts{offset};
	local $self->{count} = 0;

	# Don't let an import plugin die() on us
	my $rc = eval { $plugin->$f(
			%opts,
			dataset=>$dataset,
			user=>$user,
			actions=>\@actions,
		) };

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
	elsif( !defined $rc && !@{$self->{processor}->{messages}} )
	{
		push @problems, [
			"error",
			$session->phrase( "Plugin/Screen/Import:exception",
				plugin => $plugin->{id},
				error => "Plugin returned undef",
			),
		];
	}

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

	my $ok = (scalar(@problems) == 0 and $self->{count} > 0);

	if( !$ok )
	{
		$self->{processor}->add_message( "warning", $session->html_phrase( 
			"Plugin/Screen/Import:import_failed", 
			count => $session->make_text( $self->{count} ) ) );
	}

	return $self->{count};
}

sub render_input
{
	my ( $self ) = @_;

	my $session = $self->{session};
	my $plugin = $self->{processor}->{plugin};

	my $form = $self->render_form;

	my @labels;
	my @panels;

	if( $plugin->can_input( "textarea" ) )
	{
		push @labels, $session->html_phrase( "Plugin/Screen/Import:data" );
		push @panels, $self->render_import_form;
	}
	if( $plugin->can_input( "file" ) )
	{
		push @labels, $session->html_phrase( "Plugin/Screen/Import:upload" );
		push @panels, $self->render_upload_form;
	}

	my $base_url = $session->current_url;
	$base_url->query_form( $self->hidden_bits );

	$form->appendChild( $session->xhtml->tabs( \@labels, \@panels,
		base_url => $base_url,
	) );

	return $form;
}

sub render_results
{
	my( $self, $results ) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $f = $xml->create_document_fragment;

	my @tabs;
	my @panels;

	my $i = 0;
	my $current = 0;

	foreach my $datasetid (sort keys %$results)
	{
		$current = $i if $datasetid eq $self->{processor}->{dataset}->base_id;
		$i++;

		# for hidden_bits
		local $self->{processor}->{dataset} = $repo->dataset( $datasetid );

		my $title = $xml->create_document_fragment;
		$title->appendChild( $repo->dataset( $datasetid )->render_name );
		$title->appendChild( $xml->create_text_node( " (" . $results->{$datasetid}->count . ")" ) );
		push @tabs, $title;
		push @panels, $self->SUPER::render_results( $results->{$datasetid} );
	}

	$f->appendChild( $xhtml->tabs( \@tabs, \@panels,
			current => $current,
		) );

	return $f;
}

sub render_import_all
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $plugin = $self->{processor}->{plugin};

	my $f = $xml->create_document_fragment;
	return $f if !$self->{processor}->{results};

	my $div = $xml->create_element( "div", class => "ep_block ep_sr_component" );
	$f->appendChild( $div );

	$div->appendChild( $repo->render_action_buttons(
		 all => $repo->phrase( "Plugin/Screen/Import:action:all:title" ),
	) );

	return $f;
}

sub render_import_form
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $div = $xml->create_element( "div", class => "ep_block ep_sr_component" );

	$div->appendChild(EPrints::MetaField->new(
			name => "data",
			type => "longtext",
			repository => $repo,
		)->render_input_field(
			$repo,
			undef,
		) );
	$div->appendChild( $repo->render_action_buttons(
		paste => $repo->phrase( "Plugin/Screen/Import:action:paste:title" ),
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

	$div->appendChild( $xhtml->input_field(
		file => undef,
		type => "file"
		) );
	$div->appendChild( $repo->render_option_list(
		name => "encoding",
		default => ($repo->param( "encoding" ) || $self->param( "default_encoding" )),
		values => $self->param( "encodings" ),
		labels => {
			map { $_ => $_ } @{$self->param( "encodings" )},
		},
	) );
	$div->appendChild( $repo->render_action_buttons(
		upload => $repo->phrase( "Plugin/Screen/Import:action:upload:title" ),
	) );

	return $div;
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

sub render_action_link
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
			value=>$session->phrase( "Plugin/Screen/Import:action:import_from:title" ) ) );
	$button->appendChild( 
		$session->render_hidden_field( "screen", substr($self->{id},8) ) ); 

	my $form = $session->render_form( "GET" );
	$form->appendChild( $session->html_phrase( "Plugin/Screen/Import:import_section",
					tools => $tools,
					menu => $select,
					button => $button ));

	return $form;
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

