######################################################################
#
# EPrints::Plugin::Screen::Admin::StorageManager
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::Plugin::Screen::Admin::StorageManager;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

my $LOADING_DIV = "ep_busy_fragment";
my $JAVASCRIPT = join "", <DATA>;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ storage_manager /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions_config", 
			position => 1246, 
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $plugin ) = @_;

	return 1;
}

sub wishes_to_export
{
	my( $self ) = @_;

	return defined $self->{handle}->param( "ajax" );
}

# "ajax"
sub export
{
	my( $self ) = @_;

	my $handle = $self->{handle};

	my $action = $handle->param( "ajax" );
	return unless defined $action;

	if( $action eq "stats" )
	{
		$self->ajax_stats();
	}
	elsif( $action eq "migrate" )
	{
		$self->ajax_migrate();
	}
	elsif( $action eq "delete" )
	{
		$self->ajax_delete();
	}
}

sub ajax_stats
{
	my( $self ) = @_;

	my $handle = $self->{handle};

	my $pluginid = $handle->param( "store" );
	return "Requires store argument" unless defined $pluginid;
	my $store = $handle->plugin( $pluginid );
	return "$pluginid is not a valid plugin name" unless defined $store;

	my $dataset = $handle->get_repository->get_dataset( "file" );

	my $data = {
			total => 0,
			bytes => 0,
			parent => {},
		};

	my $searchexp = EPrints::Search->new(
		handle => $handle,
		dataset => $dataset,
		allow_blank => 1,
		filters => [
			{ meta_fields => ["copies_pluginid"], value => $pluginid },
		]);
	$searchexp->perform_search;
	$searchexp->map(sub {
		my( undef, undef, $file ) = @_;

		my $datasetid = $file->get_value( "datasetid" );
		my $filesize = $file->get_value( "filesize" );

		$data->{parent}->{$datasetid} ||= { total => 0, bytes => 0 };

		$data->{total} ++;
		$data->{bytes} += $filesize;
		$data->{parent}->{$datasetid}->{total} ++;
		$data->{parent}->{$datasetid}->{bytes} += $filesize;
	});
	$searchexp->dispose;

	my $html = $handle->make_doc_fragment;

	$html->appendChild( $self->html_phrase( "store_summary",
		total => $handle->make_text( $data->{total} ),
		bytes => $handle->make_text( $data->{bytes} ),
		human_bytes => $handle->make_text( EPrints::Utils::human_filesize( $data->{bytes} ) ),
		) );

	my $table = $handle->make_element( "table" );
	$html->appendChild( $table );

	my $max = 1;
	my $max_bytes = 1;
	for(values %{$data->{parent}})
	{
		$max = $_->{total} if $_->{total} > $max;
		$max_bytes = $_->{bytes} if $_->{bytes} > $max_bytes;
	}

	my $max_width = 200;

	my @plugins = $handle->get_plugins( type => "Storage" );

	foreach my $datasetid (sort { $a cmp $b } keys %{$data->{parent}})
	{
		my $ddata = $data->{parent}->{$datasetid};
		my $total_width = $max_width * $ddata->{total} / $max;
		my $bytes_width = $max_width * $ddata->{bytes} / $max_bytes;
		my $form = $handle->render_form( "GET", "#" );
		$form->appendChild( $handle->render_hidden_field( screen => $self->{processor}->{screenid} ) );
		$form->appendChild( $handle->render_hidden_field( store => $pluginid ) );
		$form->appendChild( $handle->render_hidden_field( datasetid => $datasetid ) );
		$form->appendChild( $handle->render_button(
			onclick => "return js_admin_storagemanager_migrate(this);",
			value => $self->phrase( "migrate" )
			) );
		my $select = $handle->make_element( "select", name => "target" );
		$form->appendChild( $select );
		my $option = $handle->make_element( "option" );
		$select->appendChild( $option );
		foreach my $plugin (@plugins)
		{
			next if $plugin->get_id eq $pluginid;
			my $option = $handle->make_element( "option", value => $plugin->get_id );
			$select->appendChild( $option );
			$option->appendChild( $handle->make_text( $plugin->get_name ) );
		}
		$form->appendChild( $handle->make_element( "br" ) );
		$form->appendChild( $handle->render_button(
			onclick => "return js_admin_storagemanager_delete(this);",
			value => $self->phrase( "delete" )
			) );

		$table->appendChild( $handle->render_row(
			$handle->html_phrase( "dataset_name_$datasetid" ),
			$self->get_count_bar( "#00f", $total_width, $handle->make_text( $ddata->{total} ) ),
#			$self->get_count_bar( "#00f", $bytes_width, $handle->make_text( EPrints::Utils::human_filesize( $ddata->{bytes} ) ) ),
			$form
			) );
	}

	binmode(STDOUT, ":utf8");
	print EPrints::XML::to_string( $html );
	EPrints::XML::dispose( $html );
}

sub ajax_migrate
{
	my( $self ) = @_;

	my $handle = $self->{handle};

	my $pluginid = $handle->param( "store" );
	return "Requires store argument" unless defined $pluginid;
	my $store = $handle->plugin( $pluginid );
	return "$pluginid is not a valid plugin name" unless defined $store;
	my $target = $handle->param( "target" );
	return "Requires target argument" unless defined $target;
	my $target_store = $handle->plugin( $target );
	return "$target is not a valid plugin name" unless defined $target_store;
	my $datasetid = $handle->param( "datasetid" );

	my $dataset = $handle->get_repository->get_dataset( "file" );

	my $searchexp = EPrints::Search->new(
		handle => $handle,
		dataset => $dataset,
		filters => [
			{ meta_fields => ["copies_pluginid"], value => $pluginid },
			{ meta_fields => ["datasetid"], value => $datasetid },
		] );

	my $total = 0;

	$searchexp->perform_search;
	$searchexp->map(sub {
		my( undef, undef, $file ) = @_;

		$total ++ if $handle->get_storage->copy( $target_store, $file );
	});
	$searchexp->dispose;

	print "$total";
}

sub ajax_delete
{
	my( $self ) = @_;

	my $handle = $self->{handle};

	my $pluginid = $handle->param( "store" );
	return "Requires store argument" unless defined $pluginid;
	my $store = $handle->plugin( $pluginid );
	return "$pluginid is not a valid plugin name" unless defined $store;
	my $datasetid = $handle->param( "datasetid" );

	my $dataset = $handle->get_repository->get_dataset( "file" );

	my $searchexp = EPrints::Search->new(
		handle => $handle,
		dataset => $dataset,
		filters => [
			{ meta_fields => ["copies_pluginid"], value => $pluginid },
			{ meta_fields => ["datasetid"], value => $datasetid },
		] );

	my $total = 0;

	$searchexp->perform_search;
	$searchexp->map(sub {
		my( undef, undef, $file ) = @_;

		my @copies = @{$file->get_value( "copies" )};
		return if scalar(@copies) <= 1;

		$total ++ if $handle->get_storage->delete_copy( $store, $file );
	});
	$searchexp->dispose;

	print "$total";
}

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub fetch_data
{
	my ( $plugin ) = @_;

	my $handle = $plugin->{handle};

	my $dataset = $handle->get_repository->get_dataset( "file" );

	my $plugin_datasets = {};

	$dataset->map( $handle, sub {
		my( $handle, $dataset, $file ) = @_;
		
		my $fileid = $file->get_value( "fileid" );
		my $datasetid = $file->get_value( "datasetid");
		my $filesize = $file->get_value( "filesize" );
		my $copies = $file->get_value( "copies_pluginid" );
		foreach my $plugin_id (@$copies)
		{
			$plugin_datasets->{$plugin_id} ||= {$datasetid => []};
			push @{$plugin_datasets->{$plugin_id}->{$datasetid}}, $file;
		}
	} );
	my $return = {};
	foreach my $plugin_id (keys %{$plugin_datasets})
	{
		foreach my $datasetid (keys %{$plugin_datasets->{$plugin_id}})
		{
			my $count = scalar(@{$plugin_datasets->{$plugin_id}->{$datasetid}});
			$return->{$plugin_id}->{$datasetid} = $count;
		}
	}
	return $return;
}

sub render
{
	my( $plugin ) = @_;

	my $handle = $plugin->{handle};
	
#	my $plugin_datasets = $plugin->fetch_data();
	my $plugin_datasets = {};
	
	my( $html, $div, $h2, $h3 );

	$html = $handle->make_doc_fragment;

	$div = $handle->make_element( "div", id => $LOADING_DIV, style => "display: none" );
	$html->appendChild( $div );
	$div->appendChild( $handle->make_element( "img",
		src => $handle->get_repository->get_conf( "rel_path" )."/style/images/loading.gif"
		) );

	my @plugins = $handle->get_plugins( type => "Storage" );

	my $script = $handle->make_element( "script", type => "text/javascript" );
	$html->appendChild( $script );
	$script->appendChild( $handle->make_comment( "\n$JAVASCRIPT\n// " ) );

	$div = $handle->make_element( "div" );
	$html->appendChild( $div );

	my $plugin_classes = {};
	foreach my $store (sort {defined($a->{position}) <=> defined($b->{position}) || $a <=> $b } @plugins) {
		$plugin_classes->{$store->{storage_class}} ||= [];
		push(@{$plugin_classes->{$store->{storage_class}}},$plugin->render_plugin( $store, \@plugins ) );
	}
	foreach my $plug (sort {$a cmp $b} keys(%{$plugin_classes})) {
		my $part = $handle->make_element( "div", class=>"ep_toolbox", id=>"blue" );
		my $part_content_div = $handle->make_element( "div", class=>"ep_toolbox_content", style=>"padding-left:6px; padding-bottom: 6px;" );
		my $heading_blue = $handle->make_element( "div", align=>"center", style=>"margin: 0px 0px 10px 0px;
		    		font: bold 130% Arial,Sans-serif;
				text-align: center;
				color: #606060;"
				);
		$heading_blue->appendChild( $plugin->html_phrase($plug) );
		
		my $pic = $plug . "_pic";
		$part_content_div->appendChild($plugin->html_phrase($pic));
		$part_content_div->appendChild($heading_blue);
		
		foreach my $sections (@{$plugin_classes->{$plug}})
		{
			$part_content_div->appendChild ( $sections );
		}
		$part->appendChild($part_content_div);
		$html->appendChild($part);
	}
	#foreach my $store (sort { $a->get_id cmp $b->get_id } @plugins)
	#{
	#	$html->appendChild( $plugin->render_plugin( $store, \@plugins ) );
	#}

	my $stats = $plugin->{handle}->make_element(
			"div",
			align => "center"
			);

	my $br = $plugin->{handle}->make_element(
		"br"
		);
	
	my $max_width=300;
	
	my $max_counts = {};

	foreach my $plugin_id (keys %{$plugin_datasets})
        {
		my $content_div = $plugin->{handle}->make_element( "div", class=>"ep_msg_other_content" );
		my $heading = $plugin->{handle}->make_element( "h1" );
	        $heading->appendChild( $plugin->html_phrase($plugin_id) );
	        $content_div->appendChild( $heading );
		my $count_table = $plugin->{handle}->make_element( "table", width => "100%");

		foreach my $datasetid (keys %{$plugin_datasets->{$plugin_id}})
		{
			my $max = 0;
			if (defined($max_counts->{$plugin_id}->{"MAX"})) 
			{
				$max = $max_counts->{$plugin_id}->{"MAX"};
			}
			my $count = $plugin_datasets->{$plugin_id}->{$datasetid};
			if ($count > $max) {
				$max_counts->{$plugin_id}->{"MAX"} = $count;
			}
		}
		foreach my $datasetid (keys %{$plugin_datasets->{$plugin_id}})
		{
			
			my $max = $max_counts->{$plugin_id}->{"MAX"};
	                my $count = $plugin_datasets->{$plugin_id}->{$datasetid};
			my $panel_tr = $plugin->{handle}->make_element(
				"tr",
				id => $plugin->{prefix}."_".$plugin_id . "_" . $datasetid );
			my $details_td = $plugin->{handle}->make_element(
				"td",
				width => "50%",
				align => "right"
				);
			my $count_td = $plugin->{handle}->make_element(
                                "td",
                                width => "50%",
                                align => "left"
	                );
			my $width = ($count / $max) * $max_width;	
			my $count_bar = $plugin->get_count_bar("blue",$width,$count);
			$count_td->appendChild($count_bar);
			my $hover = $plugin->{handle}->make_element( "a", 
								style => "color: black;",
								href => "#",
								title => $plugin->{handle}->phrase("datasethelp_". $datasetid ),
								);
			$hover->appendChild( $plugin->{handle}->html_phrase("datasetname_". $datasetid ));
        		$details_td->appendChild( $hover );

			$panel_tr->appendChild($details_td);
			$panel_tr->appendChild($count_td);
			
			$count_table->appendChild($panel_tr);
        		#$stats->appendChild( $plugin->{handle}->make_text( $plugin_id . " " . $datasetid . " " . $count ))m
			#$stats->appendChild($br);
			#$stats->appendChild($br);
		}
		$content_div->appendChild($count_table);
		$stats->appendChild($content_div);
	}
	$html->appendChild($stats);
	return $html;
}

sub render_plugin
{
	my( $self, $plugin, $plugins ) = @_;

	my $handle = $self->{handle};

	my $html = $handle->make_doc_fragment;

	my $h3 = $handle->make_element( "h3" );
	$html->appendChild( $h3 );
	$h3->appendChild( $handle->make_text( $plugin->get_name ) );

	my $stats = $handle->make_element( "div",
			class => "js_admin_storagemanager_show_stats",
			id => "stats_".$plugin->get_id
		);
	$html->appendChild( $stats );

	$stats->appendChild( $handle->make_element( "img",
		src => $handle->get_repository->get_conf( "rel_path" )."/style/images/loading.gif"
		) );

	return $html;
}

sub get_count_bar 
{
	my ( $plugin, $color, $width, $label ) = @_;

	if ($width < 10) {
		$width = 10;
	}
	my $count_bar = $plugin->{handle}->make_element(
			"table",
			cellpadding => 0,
			cellspacing => 0,
			width => "100%",
			);
	my $count_bar_tr = $plugin->{handle}->make_element(
			"tr"
			);
	my $count_bar_td = $plugin->{handle}->make_element(
			"td",
			width => $width."px",
			style => "background-color: $color;"
			);
	my $count_bar_td2 = $plugin->{handle}->make_element(
			"td",
			style => "padding-left: 2px"

			);

	$count_bar_td->appendChild( $plugin->{handle}->make_text( "  " ) );
	if( defined $label && ref($label) )
	{
		$count_bar_td2->appendChild( $plugin->{handle}->make_text( " " ) );
		$count_bar_td2->appendChild( $label );
	}
	$count_bar_tr->appendChild( $count_bar_td ); 
	$count_bar_tr->appendChild( $count_bar_td2 ); 
	$count_bar->appendChild( $count_bar_tr );

	return $count_bar;
}

sub get_colors
{
	my ($plugin) = @_;
	my $colors = {};
	return $colors->{"ep_msg_warning_content"} = "orange";
	return $colors->{"ep_msg_other_content"} = "blue";
	return $colors->{"ep_msg_error_content"} = "red";
	return $colors->{"ep_msg_message_content"} = "green";
}

sub redirect_to_me_url
{
	my( $plugin ) = @_;

	return undef;
}

1;

__DATA__

Event.observe(window,'load',function () {
	$$('.js_admin_storagemanager_show_stats').each(function(div) {
		js_admin_storagemanager_load_stats(div);
	});
});

function js_admin_storagemanager_load_stats(div)
{
	var pluginid = div.id.substring(6);

	new Ajax.Request(
		eprints_http_cgiroot+"/users/home",
		{
			method: "post",
			onFailure: function() { 
				alert( "AJAX request failed..." );
			},
			onException: function(req, e) { 
				alert( "AJAX Exception " + e );
			},
			onSuccess: function(response){ 
				var text = response.responseText;
				if( text.length == 0 )
				{
					alert( "No response from server..." );
				}
				else
				{
					div._original = div.innerHTML;
					Element.update( div, text );
				}
			},
			parameters: { 
				ajax: "stats",
				screen: "Admin::StorageManager", 
				store: pluginid
			} 
		} 
	);
}

function js_admin_storagemanager_migrate(button)
{
	Element.extend(button);

	var form = button.up('form');
	Element.extend(form);

	var ajax_parameters = form.serialize(1);
	ajax_parameters['ajax'] = 'migrate';

	form._original = form.innerHTML;
	form.update( $('ep_busy_fragment').innerHTML );

	new Ajax.Request(
		eprints_http_cgiroot+"/users/home",
		{
			method: "post",
			onFailure: function() { 
				alert( "AJAX request failed..." );
				form.update( form._original );
			},
			onException: function(req, e) { 
				alert( "AJAX Exception " + e );
				form.update( form._original );
			},
			onSuccess: function(response){ 
				var text = response.responseText;
				if( text.length == 0 )
				{
					alert( "No response from server..." );
				}
				else
				{
					// Element.update( div, text );
					div = $('stats_'+ajax_parameters['target']);
					if( !div )
					{
						alert("Can't find stats_"+ajax_parameters['target']);
					}
					else
					{
						Element.update(div,div._original);
						js_admin_storagemanager_load_stats(div);
					}
				}
				form.update( form._original );
			},
			parameters: ajax_parameters
		} 
	);

	return false;
}

function js_admin_storagemanager_delete(button)
{
	Element.extend(button);

	var form = button.up('form');
	Element.extend(form);

	var ajax_parameters = form.serialize(1);
	ajax_parameters['ajax'] = 'delete';

	form._original = form.innerHTML;
	form.update( $('ep_busy_fragment').innerHTML );

	new Ajax.Request(
		eprints_http_cgiroot+"/users/home",
		{
			method: "post",
			onFailure: function() { 
				alert( "AJAX request failed..." );
				form.update( form._original );
			},
			onException: function(req, e) { 
				alert( "AJAX Exception " + e );
				form.update( form._original );
			},
			onSuccess: function(response){ 
				var text = response.responseText;
				if( text.length == 0 )
				{
					alert( "No response from server..." );
				}
				else
				{
					// Element.update( div, text );
					div = $('stats_'+ajax_parameters['store']);
					if( !div )
					{
						alert("Can't find stats_"+ajax_parameters['target']);
					}
					else
					{
						Element.update(div,div._original);
						js_admin_storagemanager_load_stats(div);
					}
				}
				form.update( form._original );
			},
			parameters: ajax_parameters
		} 
	);

	return false;
}


