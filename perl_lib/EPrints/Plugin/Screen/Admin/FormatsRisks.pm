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
##This is how you do it
	
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
				style => "width: ".$format_bar_width."px; background-color=red;"
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
	# do something with	$files_by_format->{format};

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

sub redirect_to_me_url
{
	my( $plugin ) = @_;

	return undef;
}

1;
