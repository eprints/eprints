package EPrints::Plugin::Screen::Admin::FormatsRisks;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

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

	my $dataset = $session->get_repository->get_dataset( "eprint" );

	my $format_files = {};

	$dataset->map( $session, sub {
		my( $session, $dataset, $eprint ) = @_;
		
		foreach my $doc ($eprint->get_all_documents)
		{
			foreach my $file (@{($doc->get_value( "files" ))})
			{
				my $puid = $file->get_value( "pronom_uid" );
				$puid = "" unless defined $puid;
				push @{ $format_files->{$puid} }, $file->get_id;
			}
		}
	} );

	return $format_files;
}

sub render
{
	my( $plugin ) = @_;

	my $session = $plugin->{session};

	my $files_by_format = $plugin->fetch_data();
	
	my( $html , $table , $p , $span );

	$html = $session->make_doc_fragment;
	
	my $inner_panel = $plugin->{session}->make_element( 
			"div", 
			id => $plugin->{prefix}."_panel" );

	my $max_count = 0;	
	my $max_width = 300;
	my $format_table = $plugin->{session}->make_element(
			"table",
			width => "100%"
	);
	my $classified = "true";
	my $unclassified = $plugin->{session}->make_element(
			"div",
			align => "center"
			);	
	$unclassified->appendText( "You have unclassified objects in your repository, to classify these you may want to run the tools/update_pronom_uids script. If not installed this tool is availale via http://files.eprints.org" );
	my $br = $plugin->{session}->make_element(
			"br"
	);
	foreach my $format (sort { $#{$files_by_format->{$b}} <=> $#{$files_by_format->{$a}} } keys %{$files_by_format})
	{
		my $count = $#{$files_by_format->{$format}};
		$count++;
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
			$format_code = $format;
			my $natxml = "http://www.nationalarchives.gov.uk/pronom/".$format.".xml";
			my $doc = EPrints::XML::parse_url($natxml);
			my $format_name_node = ($doc->getElementsByTagName( "FormatName" ))[0];
			my $format_version_node = ($doc->getElementsByTagName( "FormatVersion" ))[0];
			$format_name = EPrints::Utils::tree_to_utf8($format_name_node);
			$format_version = EPrints::Utils::tree_to_utf8($format_version_node);
		}
			
		my $format_panel_tr = $plugin->{session}->make_element( 
				"tr", 
				id => $plugin->{prefix}."_".$format );

		my $format_details_td = $plugin->{session}->make_element(
				"td",
				align => "right"
		);
		my $format_count_td = $plugin->{session}->make_element(
				"td",
				align => "left"
		);
		my $pronom_output = $format_name;
		if (trim($format_version) eq "") {
		} else {	
			$pronom_output .= " (Version " . $format_version . ") ";
		}
		#$pronom_output .= " [" . $format_code . "] ";
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
				style => "background-color=red;"
				#value => ""
		);
		my $format_count_bar_tr = $plugin->{session}->make_element(
				"tr"
		);
		my $format_count_bar_td = $plugin->{session}->make_element(
				"td",
				width => $format_bar_width."px",
				style => "background-color: red;"
		);
		my $format_count_bar_td2 = $plugin->{session}->make_element(
				"td",
				style => "padding-left: 2px"
				
		);
		
		$format_count_bar_td->appendText ( "  " );
		$format_count_bar_td2->appendText(" " .$count);
		$format_count_bar_tr->appendChild( $format_count_bar_td ); 
		$format_count_bar_tr->appendChild( $format_count_bar_td2 ); 
		$format_count_bar->appendChild( $format_count_bar_tr );
		$format_details_td->appendText ( $pronom_output );
		$format_count_td->appendChild( $format_count_bar );
		$format_panel_tr->appendChild( $format_details_td );
		$format_panel_tr->appendChild( $format_count_td );
		$format_table->appendChild( $format_panel_tr );

		my $format_users = {};
		my $format_eprints = {};
		foreach my $fileid (@{$files_by_format->{$format}}) {
			my $file = EPrints::DataObj::File->new(
				$plugin->{session},
				$fileid
			);
			my $document = $file->get_parent();
			my $eprint = $document->get_parent();
			my $eprint_id = $eprint->get_value( "eprintid" );
			my $user = $eprint->get_user();
			my $user_id = $user->get_value( "userid" );
			push(@{$format_eprints->{$format}->{$eprint_id}},$fileid);
			push(@{$format_users->{$format}->{$user_id}},$fileid);
		}

		my $table = $plugin->get_user_files($format_users,$format);
		
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
			"tr"
			);
		my $inner_column1 = $plugin->{session}->make_element(
			"td",
			width => "70%"
			);
		my $inner_column2 = $plugin->{session}->make_element(
			"td",
			width => "30%",
			valign => "top"
			);
		my $eprints_table = $plugin->get_eprints_files($format_eprints,$format);
		$inner_column1->appendChild ( $eprints_table );
		$inner_column2->appendChild ( $table );
		$inner_row->appendChild( $inner_column1 );
		$inner_row->appendChild( $inner_column2 );
		$inner_table->appendChild( $inner_row );
		$other_column->appendChild( $inner_table );
		$other_row->appendChild( $other_column );
		$format_table->appendChild( $other_row );

	}
	if ($classified eq "false") {
		my $warning = $plugin->{session}->render_message("warning",
			$unclassified
		);
		#$inner_panel->appendChild($unclassified);
		$inner_panel->appendChild($warning);
	}
	$inner_panel->appendChild($format_table);
	$html->appendChild( $inner_panel );
	
	return $html;
}

sub get_eprints_files
{
	my ( $plugin, $format_eprints, $format ) = @_;
	
	my $block = $plugin->{session}->make_element(
		"div"
		);
	
	my $eprint_ids = %{$format_eprints}->{$format};
	foreach my $eprint_id (keys %{$eprint_ids})
	{
		my $file_ids = %{$format_eprints}->{$format}->{$eprint_id};
		foreach my $file_id (@{$file_ids})
		{
			my $file = EPrints::DataObj::File->new(
                                $plugin->{session},
                                $file_id
                        );

			my $table = $plugin->{session}->make_element(
					"table",
					width => "100%",
					cellpadding => 1,
					cellspacing => 1
                        );
			my $row1 = $plugin->{session}->make_element(
					"tr"
			);			
			my $col1 = $plugin->{session}->make_element(
					"td",
					style => "border: 1px dashed black;",
					colspan => 2
			);
			my $bold = $plugin->{session}->make_element(
					"b"
			);
			$bold->appendText( $file->get_value("filename") );	
			$col1->appendChild( $bold );
			$col1->appendText( " (" . EPrints::Utils::human_filesize($file->get_value("filesize")) . ")");
			$row1->appendChild( $col1 );
			$table->appendChild ( $row1 );
			my $row2 = $plugin->{session}->make_element(
					"tr"
			);			
			my $col2 = $plugin->{session}->make_element(
					"td",
					style => "border-right: 1px dashed black; border-left: 1px dashed black;",
					colspan => 2
			);			
			$col2->appendText( "URL: " . $file->get_parent()->get_url());
			$row2->appendChild( $col2 );
			$table->appendChild ( $row2 );
			my $row3 = $plugin->{session}->make_element(
					"tr"
			);			
			my $col3a = $plugin->{session}->make_element(
					"td",
					style => "border: 1px dashed black;"
			);			
			$col3a->appendText( "EPrint ID: " . $file->get_parent()->get_parent()->get_value( "eprintid" ));
			my $col3b = $plugin->{session}->make_element(
					"td",
					style => "border-right: 1px dashed black; border-top: 1px dashed black; border-bottom: 1px dashed black;"
			);
			$col3b->appendText( "User: " . EPrints::Utils::tree_to_utf8($file->get_parent()->get_parent()->get_user()->render_description()));
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
	$user_format_count_th1->appendText( "User" );
	$user_format_count_th2->appendText( "No of Files" );
	$user_format_count_htr->appendChild( $user_format_count_th1 );
	$user_format_count_htr->appendChild( $user_format_count_th2 );
	
	$user_format_count_table->appendChild( $user_format_count_htr );
	
	my $max_width=120;
	my $max_count = 0;

	my $user_ids = %{$format_users}->{$format};
	foreach my $user_id (sort { $#{$user_ids->{$b}} <=> $#{$user_ids->{$a}} } keys %{$user_ids})
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
		my $user = EPrints::DataObj::User->new(
				$plugin->{session},
				$user_id
				);
		$user_format_count_td1->appendText( EPrints::Utils::tree_to_utf8($user->render_description()) );
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
		my $file_bar_width = ($count / $max_count) * $max_width;
		if ($file_bar_width < 10) {
			$file_bar_width = 10;
		}
		my $file_count_bar_div = $plugin->{session}->make_element(
				"div",
				style => "width=".$file_bar_width."px; height: 10px; background-color: blue;"
				);
		#$file_count_bar_div->appendText ("1");
		my $file_count_bar_td2 = $plugin->{session}->make_element(
				"td",
				style => "padding-left: 2px;font-size: 0.8em;"
				);
		$file_count_bar_td1->appendChild( $file_count_bar_div );
		$file_count_bar_td2->appendText( $count );
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
