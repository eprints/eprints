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

	$self->{actions} = [qw/ paste upload search add all import_from /];

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

sub from
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $action = $self->{processor}->{action};

	if( $action && $action =~ /^add_(.*)$/ )
	{
		$self->{processor}->{notes}->{n} = $1;
		$self->{processor}->{action} = "add";
	}

	return $self->SUPER::from;
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
		$self->{processor}->{notes}->{prefix} = $plugin->get_subtype;

		my @query;
		foreach my $key ($self->{session}->param)
		{
			next if $key !~ /^$self->{processor}->{notes}->{prefix}_(.+)$/;
			push @query, map {
					$1 => $_
				} $self->{session}->param( $key );
		}
		if( @query )
		{
			my $uri = URI::http->new();
			$uri->query_form( @query );
			$self->{processor}->{notes}->{query} = $uri->query;
		}
	}

	$self->{processor}->{encoding} = $self->{session}->param( "encoding" );

	my $results = $self->{session}->dataset( "import" )->dataobj(
			scalar $self->{session}->param( "import" )
		);
	if( $results )
	{
		$self->{processor}->{results} = $results;
		$results->touch;
	}
}

sub can_be_viewed
{
	my( $self ) = @_;
	return $self->allow( "create_eprint" );
}

sub allow_import_from { shift->can_be_viewed }

sub allow_paste { shift->can_be_viewed }
sub allow_upload { shift->can_be_viewed }
sub allow_search { shift->can_be_viewed }
sub allow_add { shift->can_be_viewed }
sub allow_all { shift->can_be_viewed }

sub action_import_from
{
	my( $self ) = @_;
}

sub action_paste
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $plugin = $self->{processor}->{plugin};
	
	my $data = $repo->param( "data" );

	my $import = $repo->dataset( "import" )->create_dataobj({
			userid => $repo->current_user->id,
			pluginid => $plugin->get_subtype,
			query => $data,
		});

	my $tmpfile = File::Temp->new;
	binmode($tmpfile, ":utf8");
	print $tmpfile $data;
	seek($tmpfile, 0, 0);

	$self->{processor}->{offset} = 0;
	$self->{processor}->{results} = $import;

	$self->run_import( $tmpfile );

	$import->set_value( "count", $self->{processor}->{count} );
	$import->commit;
}

sub action_upload
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $plugin = $self->{processor}->{plugin};
	
	my $import = $repo->dataset( "import" )->create_dataobj({
			userid => $repo->current_user->id,
			pluginid => $plugin->get_subtype,
		});

	my $tmpfile = $self->{repository}->get_query->upload( "file" );
	return if !defined $tmpfile;

	$tmpfile = *$tmpfile; # CGI file handles aren't proper handles
	return if !defined $tmpfile;

	$self->{processor}->{filename} = $self->{repository}->get_query->param( "file" );
	$self->{processor}->{offset} = 0;
	$self->{processor}->{results} = $import;

	$self->run_import( $tmpfile );

	$import->set_value( "count", $self->{processor}->{count} );
	$import->commit;
}

sub action_search
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $plugin = $self->{processor}->{plugin};
	
	my $data = $self->{processor}->{notes}->{query};

	my $import = $repo->dataset( "import" )->create_dataobj({
			userid => $repo->current_user->id,
			pluginid => $plugin->get_subtype,
			query => $data,
		});

	my $tmpfile = File::Temp->new;
	binmode($tmpfile, ":utf8");
	print $tmpfile $data;
	seek($tmpfile, 0, 0);

	$self->{processor}->{mime_type} = "application/x-www-form-urlencoded";
	$self->{processor}->{offset} = 0;
	$self->{processor}->{results} = $import;

	$self->run_import( $tmpfile );

	$import->set_value( "count", $plugin->{count} );
	$import->commit;
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

sub action_add
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $import = $self->{processor}->{results};
	return if !defined $import;

	my $dataobj = $import->item( $self->{processor}->{notes}->{n} );

	$dataobj = $dataobj->get_dataset->create_dataobj( $dataobj->get_data );

	$self->{processor}->add_message( "message", $self->html_phrase( "add",
			dataset => $dataobj->get_dataset->render_name,
			dataobj => $dataobj->render_citation( "default",
				url => $dataobj->uri,
			)
		) );
}

sub action_all
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $import = $self->{processor}->{results};
	return if !defined $import;

	my $c = 0;

	for(my $i = 0; $i < $import->value( "count" ); $i += 100)
	{
		foreach my $dataobj ($self->slice( $i, 100 ))
		{
			next if $self->duplicates( $dataobj )->count;

			$dataobj = $dataobj->get_dataset->create_dataobj( $dataobj->get_data );
			++$c if defined $dataobj;
		}
	}

	$self->{processor}->add_message( "message", $self->html_phrase( "all",
			n => $repo->make_text( $c ),
		) );
}

sub epdata_to_dataobj
{
	my( $self, $epdata, %opts ) = @_;

	my $import = $self->{processor}->{results};

	$self->{processor}->{count}++;

	my $dataset = $opts{dataset};
	if( $dataset->base_id eq "eprint" )
	{
		$epdata->{userid} = $self->{repository}->current_user->id;
		$epdata->{eprint_status} = "inbox";
	}

	$import->create_subdataobj( "cache", {
			pos => ++$self->{processor}->{offset},
			datasetid => $opts{dataset}->base_id,
			epdata => $epdata,
		});

	return undef;
}

sub arguments
{
	my( $self ) = @_;

	return ();
}

sub run_import
{
	my( $self, $tmp_file, %opts ) = @_;

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

	$self->{processor}->{count} = 0;

	# Don't let an import plugin die() on us
	my $list = eval { $plugin->input_fh(
			$self->arguments,
			dataset=>$dataset,
			fh=>$tmp_file,
			user=>$user,
			filename=>$self->{processor}->{filename},
			mime_type=>$self->{processor}->{mime_type},
			encoding=>$self->{processor}->{encoding},
			actions=>\@actions,
			offset=>$self->{processor}->{offset},
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

	if( $ok )
	{
		$self->{processor}->add_message( "message", $session->html_phrase( 
			"Plugin/Screen/Import:import_completed", 
			count => $session->make_text( $count ) ) ) unless $opts{quiet};
	}
	else
	{
		$self->{processor}->add_message( "warning", $session->html_phrase( 
			"Plugin/Screen/Import:import_failed", 
			count => $session->make_text( $count ) ) );
	}

	return $list;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $uri = URI::http->new($self->{processor}->{url});
	$uri->query_form( $self->hidden_bits );

	return $uri;
}

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

	my $action = $self->{processor}->{action};
	$action = "" if !defined $action;

	my $f = $session->make_doc_fragment;

	if( $self->{processor}->{results} && $self->{processor}->{results}->value( "count" ) )
	{
		$f->appendChild( $self->render_input( 1 ) ); # collapsed
		$f->appendChild( $self->render_results );
	}
	else
	{
		$f->appendChild( $self->render_input );
	}

	return $f;
}

sub render_input
{
	my ( $self, $collapsed ) = @_;

	my $session = $self->{session};
	my $plugin = $self->{processor}->{plugin};

	my $form = $self->render_form;

	my @labels;
	my @panels;

	if( $collapsed )
	{
		push @labels, $self->html_phrase( "results" );
		push @panels, $self->render_import_all;
	}
	if( $plugin->can_input( "textarea" ) )
	{
		push @labels, $self->html_phrase( "data" );
		push @panels, $self->render_import_form;
	}
	if( $plugin->can_input( "file" ) )
	{
		push @labels, $self->html_phrase( "upload" );
		push @panels, $self->render_upload_form;
	}
	if( $plugin->can_input( "form" ) )
	{
		push @labels, $self->html_phrase( "form" );
		push @panels, $plugin->render_input_form( $self, $self->{processor}->{notes}->{prefix},
				query => (defined $self->{processor}->{results} ? $self->{processor}->{results}->value( "query" ) : undef),
			);
	}

	my $base_url = $session->current_url;
	$base_url->query_form( $self->hidden_bits );

	$form->appendChild( $session->xhtml->tabs( \@labels, \@panels,
		base_url => $base_url,
	) );

	return $form;
}

sub count { shift->{processor}->{results}->value( "count" ) }
*get_records = \&slice;
sub slice
{
	my( $self, $offset, $count ) = @_;

	my $import = $self->{processor}->{results};

	$offset ||= 0;

	return () if $offset >= $import->value( "count" );

	if( !defined $count || $offset + $count > $import->value( "count" ) )
	{
		$count = $import->value( "count" ) - $offset;
	}

	my @records = $import->slice( $offset, $count );
	# query for more records
	if( @records < $count && $import->is_set( "query" ) )
	{
		$_->remove for @records;
		@records = ();

		while(@records < $count)
		{
			my $tmpfile = File::Temp->new;
			binmode($tmpfile, ":utf8");
			print $tmpfile $import->value( "query" );
			seek($tmpfile,0,0);

			$self->{processor}->{offset} = $offset + @records;
			$self->{processor}->{mime_type} = "application/x-www-form-urlencoded";

			$self->run_import( $tmpfile, quiet => 1 );

			my @chunk = $import->slice( $offset + @records, $count - @records );
			last if !@chunk; # no more records found
			push @records, @chunk;
		}
	}

	# convert import cache objects into the actual objects
	local $_;
	for(@records)
	{
		my $dataset = $self->{session}->dataset( $_->value( "datasetid" ) );
		$_ = $dataset->make_dataobj( $_->value( "epdata" ) );
	}

	return @records;
}

sub render_results
{
	my ( $self ) = @_;

	my $session = $self->{session};
	my $plugin = $self->{processor}->{plugin};

	my $f = $session->make_doc_fragment;
	return $f if !$self->{processor}->{results};

	my $form = $self->render_form;
	$f->appendChild( $form );

	$form->appendChild( EPrints::Paginate->paginate_list(
			$session,
			undef,
			$self,
			params => {$self->hidden_bits},
			container => $session->make_element(
				"table",
				class=>"ep_paginate_list"
			),
			render_result => sub {
				my( undef, $result, undef, $n ) = @_;

				return $self->render_result_row( $result, $n );
			},
		) );

	return $f;
}

sub duplicates
{
	my( $self, $dataobj ) = @_;

	my $dataset = $dataobj->get_dataset;

	if( $dataobj->exists_and_set( "source" ) )
	{
		return $dataset->search(filters => [
				{ meta_fields => [qw( source )], value => $dataobj->value( "source" ), match => "EX", },
			],
			limit => 1,
		);
	}

	return $dataset->list( [] );
}

sub render_result_row
{
	my( $self, $dataobj, $n ) = @_;

	my $repo = $self->{session};
	my $xhtml = $repo->xhtml;
	my $dataset = $dataobj->{dataset};

	my $match = $self->duplicates( $dataobj )->item( 0 );

	my $tr = $repo->make_element( "tr" );
	my $td;

	$td = $tr->appendChild( $repo->make_element( "td" ) );
	$td->appendChild( $repo->make_text( $n ) );

	$td = $tr->appendChild( $repo->make_element( "td" ) );
	$td->appendChild( $dataset->render_name );

	$td = $tr->appendChild( $repo->make_element( "td" ) );
	if( $match )
	{
		$td->appendChild( $dataobj->render_citation( "default",
				url => $match->uri,
			) );
	}
	else
	{
		$td->appendChild( $dataobj->render_citation );
	}

	my $input = $xhtml->action_button(
			"add_" . $n,
			$self->phrase( "action:add:title" ),
			class => ($match ? "ep_blister_node" : ""),
		);
	$td = $tr->appendChild( $repo->make_element( "td" ) );
	$td->appendChild( $input );

	return $tr;
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
			(defined $self->{processor}->{results} ? $self->{processor}->{results}->value( "query" ) : undef),
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

sub _vis_level
{
	my( $self ) = @_;

	my $user = $self->{session}->current_user;

	return $user->is_staff ? "staff" : "all";
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
		import => ($self->{processor}->{results} ? $self->{processor}->{results}->id : undef),
	);
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

