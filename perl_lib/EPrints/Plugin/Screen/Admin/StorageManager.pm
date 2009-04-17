#######################################################
###                                                 ###
###  Preserv2/EPrints StorageManager Screen Plugin  ###
###                                                 ###
#######################################################
###                                                 ###
###     Developed by David Tarrant and Tim Brody    ###
###                                                 ###
###          Released under the GPL Licence         ###
###           (c) University of Southampton         ###
###                                                 ###
###        Install in the following location:       ###
###  eprints/perl_lib/EPrints/Plugin/Screen/Admin/  ###
###                                                 ###
#######################################################

package EPrints::Plugin::Screen::Admin::StorageManager;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ storage_manager /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions", 
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

	my $session = $plugin->{session};

	my $dataset = $session->get_repository->get_dataset( "file" );

	my $plugin_datasets = {};

	$dataset->map( $session, sub {
		my( $session, $dataset, $file ) = @_;
		
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

	my $session = $plugin->{session};
	
	my $plugin_datasets = $plugin->fetch_data();
	
	my $html = $session->make_doc_fragment;
	my $stats = $plugin->{session}->make_element(
                        "div",
                        align => "center"
                        );

        my $br = $plugin->{session}->make_element(
                        "br"
        );
	
	my $max_width=300;
	
	my $max_counts = {};

	foreach my $plugin_id (keys %{$plugin_datasets})
        {
		my $content_div = $plugin->{session}->make_element( "div", class=>"ep_msg_other_content" );
		my $heading = $plugin->{session}->make_element( "h1" );
	        $heading->appendChild( $plugin->html_phrase($plugin_id) );
	        $content_div->appendChild( $heading );
		my $count_table = $plugin->{session}->make_element( "table", width => "100%");

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
			my $panel_tr = $plugin->{session}->make_element(
				"tr",
				id => $plugin->{prefix}."_".$plugin_id . "_" . $datasetid );
			my $details_td = $plugin->{session}->make_element(
				"td",
				width => "50%",
				align => "right"
				);
			my $count_td = $plugin->{session}->make_element(
                                "td",
                                width => "50%",
                                align => "left"
	                );
			my $width = ($count / $max) * $max_width;	
			my $count_bar = $plugin->get_count_bar("blue",$width,$count);
			$count_td->appendChild($count_bar);
			my $hover = $plugin->{session}->make_element( "a", 
								style => "color: black;",
								href => "#",
								title => $plugin->{session}->phrase("datasethelp_". $datasetid ),
								);
			$hover->appendChild( $plugin->{session}->html_phrase("datasetname_". $datasetid ));
        		$details_td->appendChild( $hover );

			$panel_tr->appendChild($details_td);
			$panel_tr->appendChild($count_td);
			
			$count_table->appendChild($panel_tr);
        		#$stats->appendChild( $plugin->{session}->make_text( $plugin_id . " " . $datasetid . " " . $count ))m
			#$stats->appendChild($br);
			#$stats->appendChild($br);
		}
		$content_div->appendChild($count_table);
		$stats->appendChild($content_div);
	}
	$html->appendChild($stats);
	return $html;
}

sub get_count_bar 
{
	my ( $plugin, $color, $width, $count ) = @_;

	if ($width < 10) {
		$width = 10;
	}
	my $count_bar = $plugin->{session}->make_element(
			"table",
#type => "submit",
			cellpadding => 0,
			cellspacing => 0,
			width => "100%",
			style => "background-color=$color;"
#value => ""
			);
	my $count_bar_tr = $plugin->{session}->make_element(
			"tr"
			);
	my $count_bar_td = $plugin->{session}->make_element(
			"td",
			width => $width."px",
			style => "background-color: $color;"
			);
	my $count_bar_td2 = $plugin->{session}->make_element(
			"td",
			style => "padding-left: 2px"

			);

	$count_bar_td->appendChild( $plugin->{session}->make_text( "  " ) );
	$count_bar_td2->appendChild ( $plugin->{session}->make_text( " " .$count) );
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
