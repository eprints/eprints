package EPrints::Plugin::Screen::Admin::FormatsRisks;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;
my $classified;
my $hideall;
my $unstable;
my $risks_url;
our ($classified, $hideall, $unstable, $risks_url);
$classified = "true";

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ formats_risks /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions", 
			position => 1245, 
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

	my $dataset = $session->get_repository->get_dataset( "pronom" );

	my $format_files = {};

	$dataset->map( $session, sub {
		my( $session, $dataset, $pronom_formats ) = @_;
		
		foreach my $pronom_format ($pronom_formats)
		{
			my $puid = $pronom_format->get_value( "pronomid" );
			$puid = "" unless defined $puid;
			if ($pronom_format->get_value("file_count") > 0) 
			{
				$format_files->{$puid} = $pronom_format->get_value("file_count");
			}
		}
	} );

	$dataset = $session->get_repository->get_dataset( "file" );
	my $searchexp = EPrints::Search->new(
                session => $session,
                dataset => $dataset,
                filters => [
                        { meta_fields => [qw( datasetid )], value => "document" },
                        { meta_fields => [qw( pronomid )], value => "", match => "EX" },
                ],
        );
        my $list = $searchexp->perform_search;
	my $count = $list->count;
	if ($count > 0) {
		print STDERR "Unclassified : " . $count . "\n";
		$format_files->{"Unclassified"} = $count;
	}
	
	return $format_files;
}

sub render
{
	my( $plugin ) = @_;

	my $session = $plugin->{session};

	
	my( $html , $table , $p , $span );

	$html = $session->make_doc_fragment;
	
	my $script = $plugin->{session}->make_javascript('
		function show(id) {
			var canSee = "block";
			if(navigator.appName.indexOf("Microsoft") > -1){
				canSee = "block";
			} else {
				canSee = "table-row";
			}
			document.getElementById(id).style.display = canSee;
		}
		function hide(id) {
			
			document.getElementById(id).style.display = "none";
		}
		function plus(format) {
			hide(format + "_plus");
			show(format + "_minus");
			show(format + "_inner_row");
		}
		function minus(format) {
			show(format + "_plus");
			hide(format + "_minus");
			hide(format + "_inner_row");
		}
	');
	$html->appendChild($script);
	my $inner_panel = $plugin->{session}->make_element( 
			"div", 
			id => $plugin->{prefix}."_panel" );

	my $unclassified = $plugin->{session}->make_element(
			"div",
			align => "center"
			);	
	$unclassified->appendChild( $plugin->{session}->make_text( "You have unclassified objects in your repository, to classify these you may want to run the tools/update_pronom_puids script. If not installed this tool is availale via http://files.eprints.org" ));
	my $risks_unstable = $plugin->{session}->make_element(
			"div",
			align => "center"
			);	
	$risks_unstable->appendChild( $plugin->{session}->make_text("This EPrints install may be referecing a trial version of the risk analysis service. If you feel this is incorrect please contact the system administrator." ));

	my $br = $plugin->{session}->make_element(
			"br"
	);

	my $format_table;
	my $warning;
	my $doc;
	my $available;
	my $warning_width_table = $plugin->{session}->make_element(
		"table",
		id => "warnings",
		align=> "center",
		width => "620px"
	);
	my $wtr = $plugin->{session}->make_element( "tr" );
	my $warning_width_limit = $plugin->{session}->make_element( "td", width => "620px", align=>"center" );

	
	my $unstable = $session->get_repository->get_conf( "pronom_unstable" );	

	if ($unstable eq 1) {
		$warning = $plugin->{session}->render_message("warning",
				$risks_unstable
				);
		$warning_width_limit->appendChild($warning);
	}
	$format_table = $plugin->get_format_risks_table();

	if ($classified eq "false") {
		$warning = $plugin->{session}->render_message("warning",
			$unclassified
		);
		$warning_width_limit->appendChild($warning);
	}

	$wtr->appendChild($warning_width_limit);
	$warning_width_table->appendChild($wtr);
	$inner_panel->appendChild($warning_width_table);
	$inner_panel->appendChild($format_table);
	$html->appendChild( $inner_panel );
	
	$script = $plugin->{session}->make_javascript(
		$hideall
	);
	$html->appendChild($script);
	
	
	return $html;
}

sub get_format_risks_table {
	
	my( $plugin ) = @_;

	my $files_by_format = $plugin->fetch_data();
	
	my $green = $plugin->{session}->make_element( "div", class=>"ep_msg_message", id=>"green" );
	my $orange = $plugin->{session}->make_element( "div", class=>"ep_msg_warning", id=>"orange" );
	my $red = $plugin->{session}->make_element( "div", class=>"ep_msg_error", id=>"red" );
	my $blue = $plugin->{session}->make_element( "div", class=>"ep_msg_other", id=>"blue" );
	#my $unclassified_orange = $plugin->{session}->make_element( "div", class=>"ep_msg_warning", id=>"unclassified_orange" );
	my $green_content_div = $plugin->{session}->make_element( "div", class=>"ep_msg_message_content" );
	my $orange_content_div = $plugin->{session}->make_element( "div", class=>"ep_msg_warning_content" );
	#my $unclassified_orange_content_div = $plugin->{session}->make_element( "div", class=>"ep_msg_warning_content" );
	my $red_content_div = $plugin->{session}->make_element( "div", class=>"ep_msg_error_content" );
	my $blue_content_div = $plugin->{session}->make_element( "div", class=>"ep_msg_other_content" );

	my $heading_red = $plugin->{session}->make_element( "h1" );
	$heading_red->appendChild( $plugin->{session}->make_text( " High Risk Objects ") );
	$red_content_div->appendChild( $heading_red );
	my $heading_orange = $plugin->{session}->make_element( "h1" );
	$heading_orange->appendChild( $plugin->{session}->make_text( " Medium Risk Objects ") );
	$orange_content_div->appendChild( $heading_orange );
	my $heading_green = $plugin->{session}->make_element( "h1" );
	$heading_green->appendChild( $plugin->{session}->make_text( " Low Risk Objects ") );
	$green_content_div->appendChild( $heading_green );
	my $heading_blue = $plugin->{session}->make_element( "h1" );
	$heading_blue->appendChild( $plugin->{session}->make_text( " No Risk Scores Available ") );
	$blue_content_div->appendChild( $heading_blue );
	#my $heading_unclassified_orange = $plugin->{session}->make_element( "h1" );
	#$heading_unclassified_orange->appendChild( $plugin->{session}->make_text( " Unclassified Objects ") );
	#$unclassified_orange_content_div->appendChild( $heading_unclassified_orange );
	
#	$div->appendChild( $title_div );
	my $green_count = 0;
	my $orange_count = 0;
	my $red_count = 0;
	my $blue_count = 0;
	#my $unclassified_count = 0;


	my $url = $risks_url;

	my $max_count = 0;	
	my $max_width = 300;
	
	
	my $green_format_table = $plugin->{session}->make_element( "table", width => "100%");
	my $orange_format_table = $plugin->{session}->make_element( "table", width => "100%");
	#my $unclassified_orange_format_table = $plugin->{session}->make_element( "table", width => "100%");
	my $red_format_table = $plugin->{session}->make_element( "table", width => "100%");
	my $blue_format_table = $plugin->{session}->make_element( "table", width => "100%");
	
	my $format_table = $blue_format_table;
	
	my $pronom_error_message = "";
	foreach my $format (sort { $files_by_format->{$b} <=> $files_by_format->{$a} } keys %{$files_by_format})
	{
		my $color = "blue";
		my $pronom_data = $plugin->{session}->get_repository->get_dataset("pronom")->get_object($plugin->{session}, $format);
		my $result = $pronom_data->get_value("risk_score");


		my $high_risk_boundary = $plugin->{session}->get_repository->get_conf( "high_risk_boundary" );
		my $medium_risk_boundary = $plugin->{session}->get_repository->get_conf( "medium_risk_boundary" );

		print STDERR $format . " : ". $result . "\n";

		if ($result <= $high_risk_boundary) {
			$format_table = $red_format_table;
			$red_count = $red_count + 1;
			$color = "red";
		} elsif ($result > $high_risk_boundary && $result <= $medium_risk_boundary) {
			$format_table = $orange_format_table;
			$orange_count = $orange_count + 1;
			$color = "orange";
		} elsif ($result > $medium_risk_boundary) {
			$format_table = $green_format_table;
			$green_count = $green_count + 1;
			$color = "green";
		} else {
			$format_table = $blue_format_table;
			$blue_count = $blue_count + 1;
			$color = "blue";
		}
	
		my $count = $files_by_format->{$format};
		if ($max_count < 1) {
			$max_count = $count;
		}
		my $format_name = "";
		my $format_code = "";
		my $format_version = "";

		if ($format eq "" || $format eq "NULL") {
			$format_name = "Not Classified";
			$classified = "false";
		} else {
			$format_name = $pronom_data->get_value("name");
			$format_version = $pronom_data->get_value("version");
		}
		if ($format_name eq "") {
			$format_name = $format;
		}
			
		my $format_panel_tr = $plugin->{session}->make_element( 
				"tr", 
				id => $plugin->{prefix}."_".$format );

		my $format_details_td = $plugin->{session}->make_element(
				"td",
				width => "50%",
				align => "right"
		);
		my $format_count_td = $plugin->{session}->make_element(
				"td",
				width => "50%",
				align => "left"
		);
		my $pronom_output = $format_name . " ";
		if (trim($format_version) eq "") {
		} else {	
			$pronom_output .= "(Version " . $format_version . ") ";
		}
		my $imagesurl = $plugin->{session}->get_repository->get_conf( "rel_path" );
		my $plus_button = $plugin->{session}->make_element(
			"img",
			id => $format . "_plus",
			onclick => 'plus("'.$format.'")',
			src => "$imagesurl/style/images/plus.png",
			border => 0,
			alt => "PLUS"
		);
		my $minus_button = $plugin->{session}->make_element(
			"img",
			id => $format . "_minus",
			onclick => 'minus("'.$format.'")',
			src => "$imagesurl/style/images/minus.png",
			border => 0,
			alt => "MINUS"
		);
		my $format_bar_width = ($count / $max_count) * $max_width;
		if ($format_bar_width < 10) {
			$format_bar_width = 10;
		}
		my $format_count_bar = $plugin->{session}->make_element(
				"table",
				#type => "submit",
				cellpadding => 0,
				cellspacing => 0,
				width => "100%",
				style => "background-color=$color;"
				#value => ""
		);
		my $format_count_bar_tr = $plugin->{session}->make_element(
				"tr"
		);
		my $format_count_bar_td = $plugin->{session}->make_element(
				"td",
				width => $format_bar_width."px",
				style => "background-color: $color;"
		);
		my $format_count_bar_td2 = $plugin->{session}->make_element(
				"td",
				style => "padding-left: 2px"
				
		);
		
		$format_count_bar_td->appendChild( $plugin->{session}->make_text( "  " ) );
		$format_count_bar_td2->appendChild ( $plugin->{session}->make_text( " " .$count) );
		$format_count_bar_tr->appendChild( $format_count_bar_td ); 
		$format_count_bar_tr->appendChild( $format_count_bar_td2 ); 
		$format_count_bar->appendChild( $format_count_bar_tr );
		$format_details_td->appendChild ( $plugin->{session}->make_text( $pronom_output ) );
		if ($result <= $medium_risk_boundary) 
		{
			$format_details_td->appendChild ( $plus_button );
			$format_details_td->appendChild ( $minus_button );
			$hideall = $hideall . 'hide("'.$format.'_minus");' . "\n";
		}
		$format_count_td->appendChild( $format_count_bar );
		$format_panel_tr->appendChild( $format_details_td );
		$format_panel_tr->appendChild( $format_count_td );
		#if ($format_name eq "Not Classified") {
		#	$unclassified_orange_format_table->appendChild ( $format_panel_tr );
		#	$unclassified_count = $unclassified_count + 1;
		#} else {
			$format_table->appendChild( $format_panel_tr );
		#}
		
		my $other_row = $plugin->{session}->make_element(
			"tr"
			);
		my $other_column = $plugin->{session}->make_element(
			"td",
			colspan => 2
			);
		my $inner_table = $plugin->{session}->make_element(
			"table",
			width => "100%"
			);
		my $inner_row = $plugin->{session}->make_element(
			"tr",
			id => $format . "_inner_row"
			);
		$hideall = $hideall . 'hide("'. $format.'_inner_row");' . "\n";
		my $inner_column1 = $plugin->{session}->make_element(
			"td",
			style => "width: 70%;",
			valign => "top"
			);
		my $inner_column2 = $plugin->{session}->make_element(
			"td",
			style => "width: 30%;",
			valign => "top"
			);

		my $format_users = {};
		my $format_eprints = {};
		if ($result <= $medium_risk_boundary)
		{
			my $search_format;
			my $dataset = $plugin->{session}->get_repository->get_dataset( "file" );
			if ($format eq "Unclassified") {
				$classified = "false";
				$search_format = "";
			} else {
				$search_format = $format;
			}
			my $searchexp = EPrints::Search->new(
				session => $plugin->{session},
				dataset => $dataset,
				filters => [
				{ meta_fields => [qw( datasetid )], value => "document" },
				{ meta_fields => [qw( pronomid )], value => "$search_format", match => "EX" },
				],
				);
			my $list = $searchexp->perform_search;
			$list->map( sub { 
					my $file = $_[2];	
					my $fileid = $file->get_id;
					my $document = $file->get_parent();
					my $eprint = $document->get_parent();
					my $eprint_id = $eprint->get_value( "eprintid" );
					my $user = $eprint->get_user();
					my $user_id = $eprint->get_value( "userid" );
					push(@{$format_eprints->{$format}->{$eprint_id}},$fileid);
					push(@{$format_users->{$format}->{$user_id}},$fileid);
			} );
			my $table = $plugin->get_user_files($format_users,$format);
			my $eprints_table = $plugin->get_eprints_files($format_eprints,$format);
			$inner_column1->appendChild ( $eprints_table );
			$inner_column2->appendChild ( $table );
		}
		$inner_row->appendChild( $inner_column1 );
		$inner_row->appendChild( $inner_column2 );
		$inner_table->appendChild( $inner_row );
		$other_column->appendChild( $inner_table );
		$other_row->appendChild( $other_column );
		#if ($format_name eq "Not Classified") {
		#	$unclassified_orange_format_table->appendChild ( $other_row );
		#} else {
			$format_table->appendChild( $other_row );
		#}
	}
	my $ret = $plugin->{session}->make_doc_fragment;

	if (!($pronom_error_message eq "")) {
		my $pronom_error_div = $plugin->{session}->make_element(
			"div",
			align => "center"
			);	
		$pronom_error_div->appendChild( $plugin->{session}->make_text($pronom_error_message ));

		my $warning = $plugin->{session}->render_message("warning",
			$pronom_error_div
		);
		$ret->appendChild($warning);
		
	}

	$green_content_div->appendChild($green_format_table);
	$orange_content_div->appendChild($orange_format_table);
	$red_content_div->appendChild($red_format_table);
	$blue_content_div->appendChild($blue_format_table);
	#$unclassified_orange_content_div->appendChild($unclassified_orange_format_table);
	if ($green_count > 0 || $orange_count > 0 || $red_count > 0) {
		$green->appendChild( $green_content_div );
		$orange->appendChild( $orange_content_div );
		$red->appendChild( $red_content_div );
		$ret->appendChild($red);
		$ret->appendChild($orange);
		$ret->appendChild($green);
	}
	#if ($unclassified_count > 0) {
	#	$unclassified_orange->appendChild( $unclassified_orange_content_div );
	#	$ret->appendChild($unclassified_orange);
	#}
	if ($blue_count > 0) {
		$blue->appendChild( $blue_content_div );
		$ret->appendChild($blue);
	}
	
	return $ret;
}

sub get_eprints_files
{
	my ( $plugin, $format_eprints, $format ) = @_;
	
	my $block = $plugin->{session}->make_element(
		"div",
		style=>"max-width: 500px; max-height: 400px; overflow: auto;"
		);
	#my $eprint_ids = %{$format_eprints}->{$format};
	#foreach my $eprint_id (keys %{$eprint_ids})
	my @eprint_ids = keys %{$format_eprints->{$format}};
	foreach my $eprint_id (@eprint_ids)
	{

		my @file_ids = @{$format_eprints->{$format}->{$eprint_id}};
		foreach my $file_id (@file_ids)
		{
			my $file = EPrints::DataObj::File->new(
                                $plugin->{session},
                                $file_id
                        );

			my $table = $plugin->{session}->make_element(
					"table",
					width => "100%"
                        );
			my $row1 = $plugin->{session}->make_element(
					"tr"
			);			
			my $col1 = $plugin->{session}->make_element(
					"td",
					style => "border: 1px dashed black; padding: 0.3em;",
					colspan => 2
			);
			my $file_url = $file->get_parent()->get_url();			
			my $file_href = $plugin->{session}->make_element(
					"a",
					href => $file_url
			);
			my $bold = $plugin->{session}->make_element(
					"b"
			);
			$bold->appendChild( $plugin->{session}->make_text( $file->get_value("filename") ));	
			$file_href->appendChild( $bold );
			$col1->appendChild( $file_href );
			$col1->appendChild( $plugin->{session}->make_text(" (" . EPrints::Utils::human_filesize($file->get_value("filesize")) . ")"));
			$row1->appendChild( $col1 );
			$table->appendChild ( $row1 );
			my $row2 = $plugin->{session}->make_element(
					"tr"
			);			
			my $col2 = $plugin->{session}->make_element(
					"td",
					style => "border-right: 1px dashed black; border-left: 1px dashed black; padding: 0.3em;",
					colspan => 2
			);
			$bold = $plugin->{session}->make_element(
					"b"
			);
			$bold->appendChild( $plugin->{session}->make_text("Title: " ));
			$col2->appendChild( $bold );
			$col2->appendChild( $plugin->{session}->make_text($file->get_parent()->get_parent()->get_value( "title" )));
			$row2->appendChild( $col2 );
			$table->appendChild ( $row2 );
			my $row3 = $plugin->{session}->make_element(
					"tr"
			);			
			my $col3a = $plugin->{session}->make_element(
					"td",
					style => "border: 1px dashed black; padding: 0.3em;"
			);
			my $eprint_href = $plugin->{session}->make_element(
					"a",
					href => $file->get_parent()->get_parent()->get_url()
			);
			$eprint_href->appendChild( $plugin->{session}->make_text($file->get_parent()->get_parent()->get_value( "eprintid" ) ));	
			$bold = $plugin->{session}->make_element(
					"b"
			);
			$bold->appendChild( $plugin->{session}->make_text("EPrint ID: " ));
			$col3a->appendChild( $bold );
			$col3a->appendChild( $eprint_href );
			my $col3b = $plugin->{session}->make_element(
					"td",
					style => "border-right: 1px dashed black; border-top: 1px dashed black; border-bottom: 1px dashed black; padding: 0.3em;"
			);
			$bold = $plugin->{session}->make_element(
					"b"
			);
			$bold->appendChild( $plugin->{session}->make_text("User: " ));
			$col3b->appendChild( $bold );
			my $eprint = $file->get_parent()->get_parent();
			my $user = $eprint->get_user();
			if( defined $user )
			{
				$col3b->appendChild( $user->render_description() );
			}
			else
			{
				$col3b->appendChild( $plugin->{session}->make_text( "Unknown User (ID: ".$eprint->get_value( "userid" ).")"));
			}
			$row3->appendChild( $col3a );
			$row3->appendChild( $col3b );
			$table->appendChild( $row3 );
			$block->appendChild($table);
			my $br = $plugin->{session}->make_element(
				"br"
			);
			$block->appendChild($br);
		}
	}
	
	return $block;
}

sub get_user_files 
{
	my ( $plugin, $format_users, $format ) = @_;

	
	my $user_format_count_table = $plugin->{session}->make_element(
			"table",
			width => "250px",
			cellpadding => 1,
			style => "border: 1px solid black;",
			cellspacing => 0
			);
	my $user_format_count_tr = $plugin->{session}->make_element(
			"tr"
			);
	my $user_format_count_htr = $plugin->{session}->make_element(
			"tr"
			);
	my $user_format_count_th1 = $plugin->{session}->make_element(
			"th",
			align => "center",
			style => "font-size: 1em; font-weight: bold;"
			);
	my $user_format_count_th2 = $plugin->{session}->make_element(
			"th",
			align => "center",
			style => "font-size: 1em; font-weight: bold;"
			);
	$user_format_count_th1->appendChild( $plugin->{session}->make_text( "User" ));
	$user_format_count_th2->appendChild( $plugin->{session}->make_text( "No of Files" ));
	$user_format_count_htr->appendChild( $user_format_count_th1 );
	$user_format_count_htr->appendChild( $user_format_count_th2 );
	
	$user_format_count_table->appendChild( $user_format_count_htr );
	
	my $max_width=120;
	my $max_count = 0;



	my @user_ids = keys %{$format_users->{$format}};

	foreach my $user_id (sort  @user_ids)
	{
		my $count = $#{$format_users->{$format}->{$user_id}};
		$count++;
		if ($max_count < 1) {
			$max_count = $count;
		}
		my $user_format_count_tr = $plugin->{session}->make_element(
				"tr",
				);
		my $user_format_count_td1 = $plugin->{session}->make_element(
				"td",
				align => "right",
				style => "font-size: 0.9em;",
				width => "120px"
				);
		my $user = EPrints::DataObj::User->new( $plugin->{session}, $user_id );
		if( defined $user )
		{
			$user_format_count_td1->appendChild( $user->render_description() );
		}
		else
		{
			$user_format_count_td1->appendChild( $plugin->{session}->make_text( "Unknown User (ID: $user_id)"));
		}
		my $user_format_count_td2 = $plugin->{session}->make_element(
				"td",
				width => "130px"
				);
		my $file_count_bar = $plugin->{session}->make_element(
				"table",
				cellpadding => 0,
				cellspacing => 0,
				style => "width: 130px;"
				);
		my $file_count_bar_tr = $plugin->{session}->make_element(
				"tr"
				);
		my $file_bar_width = ($count / $max_count) * $max_width;
		if ($file_bar_width < 10) {
			$file_bar_width = 10;
		}
		my $file_count_bar_td1 = $plugin->{session}->make_element(
				"td",
				width => $file_bar_width . "px"
				);
		$file_bar_width = ($count / $max_count) * $max_width;
		if ($file_bar_width < 10) {
			$file_bar_width = 10;
		}
		my $file_count_bar_div = $plugin->{session}->make_element(
				"div",
				style => "width=".$file_bar_width."px; height: 10px; background-color: blue;"
				);
		my $file_count_bar_td2 = $plugin->{session}->make_element(
				"td",
				style => "padding-left: 2px;font-size: 0.8em;"
				);
		$file_count_bar_td1->appendChild( $file_count_bar_div );
		$file_count_bar_td2->appendChild( $plugin->{session}->make_text( $count ));
		$file_count_bar_tr->appendChild( $file_count_bar_td1 );
		$file_count_bar_tr->appendChild( $file_count_bar_td2 );
		$file_count_bar->appendChild( $file_count_bar_tr );
		$user_format_count_td2->appendChild( $file_count_bar );
		$user_format_count_tr->appendChild( $user_format_count_td1 );
		$user_format_count_tr->appendChild( $user_format_count_td2 );
		$user_format_count_table->appendChild( $user_format_count_tr );
	}
	return $user_format_count_table;	
}

sub redirect_to_me_url
{
	my( $plugin ) = @_;

	return undef;
}


1;
