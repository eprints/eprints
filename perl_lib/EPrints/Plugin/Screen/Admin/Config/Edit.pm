=head1 NAME

EPrints::Plugin::Screen::Admin::Config::Edit

=cut

##WARNING - There are lots of system() calls in this file, these need to be removed post haste!



package EPrints::Plugin::Screen::Admin::Config::Edit;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

my $node_collection = {};
my @node_list;
unshift(@node_list,"template");
$node_collection->{"template"} = '<?xml version="1.0" standalone="no" ?>' . "\n" . 
	'<!DOCTYPE html SYSTEM "entities.dtd" >'. "\n\n" . 
	'<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epc="http://eprints.org/ep3/control">';

our %CODEMIRROR_MODES = (
	pl => {
		js => [qw( mode/perl/perl.js )],
		mode => "perl",
	},
	xml => {
		js => [qw( mode/xml/xml.js )],
		mode => "xml",
	},
	xsl => {
		js => [qw( mode/xml/xml.js )],
		mode => "xml",
	},
	xhtml => {
		js => [qw( mode/xml/xml.js )],
		mode => "xml",
	},
	css => {
		js => [qw( mode/css/css.js )],
		mode => "css",
	},
	js => {
		js => [qw( mode/javascript/javascript.js )],
		mode => "javascript",
	},
);

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [ "save_config", "revert_config", "download_full_file", "process_upload", "process_image_upload", "reload_config" ];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{configfile} = $self->{session}->param( "configfile" );
	$self->{processor}->{configfilepath} = $self->{session}->get_repository->get_conf( "config_path" )."/".$self->{processor}->{configfile};

	if( $self->{processor}->{configfile} =~ m/\/\./ )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", $self->{session}->html_phrase(
			"Plugin/Screen/Admin/Config/Edit:bad_filename",
			filename=>$self->{session}->make_text( $self->{processor}->{configfile} ) ) );
		return;
	}
	if( !-e $self->{processor}->{configfilepath} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", $self->{session}->html_phrase(
			"Plugin/Screen/Admin/Config/Edit:no_such_file",
			filename=>$self->{session}->make_text( $self->{processor}->{configfilepath} ) ) );
		return;
	}

	$self->SUPER::properties_from;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0; # needs to be subclassed
}
sub allow_save_config
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}
sub allow_revert_config
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_download_full_file
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}
sub allow_process_upload
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_process_image_upload
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_reload_config
{
	my( $self ) = @_;

	return $self->allow( "config/reload" );
}

# return an array of DOM explanations of issues with this file
# empty array if it's OK
# this does not test in context, just validates XML etc.
sub validate_config_file
{
	my( $self, $data ) = @_;

	return( );
}

sub save_broken
{
	my( $self, $data ) = @_;

	my $fn = $self->{processor}->{configfilepath}.".broken";
	unless( open( DATA, ">$fn" ) )
	{
		$self->{processor}->add_message( 
			"error", 
			$self->html_phrase( "could_not_write", 
				error_msg=>$self->{session}->make_text($!), 
				filename=>$self->{session}->make_text( $fn )));
		return;
	}
	print DATA $data;
	close DATA;
}

sub action_reload_config
{
	my ( $self ) = @_;
	
	my $repository = $self->{repository};
	
	$repository->reload_config();
	
	$self->{processor}->add_message(
			"message",
			$self->{session}->html_phrase( "Plugin/Screen/Admin/Reload:reloaded" )
			);
}

sub action_revert_config
{
	my( $self ) = @_;

	my $fn = $self->{processor}->{configfilepath}.".broken";

	return if( !-e $fn );

	unlink( $fn );

	$self->{processor}->add_message( 
		"message", 
		$self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:reverted" )
	);
		
}

sub action_save_config
{
	my( $self ) = @_;

	my $data = $self->{session}->param( "data" );
	
	# de-dos da data
	$data =~ s/\r\n/\n/g;	

	if( !defined $data )
	{
		$self->{processor}->add_message( 
			"error", 
			$self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:no_data" )
		);
		return;
	}

	# first check our file in RAM 
	my @file_problems = $self->validate_config_file( $data );
	if( scalar @file_problems )
	{
		# -- if it fails: report an error and save it to a .broken file then abort
		$self->{processor}->add_message( 
			"error", 
			$self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:did_not_install" )
		);
		foreach my $problem ( @file_problems )
		{
			$self->{processor}->add_message( "warning", $problem );
		}
		$self->save_broken( $data );
		return;
	}

	my $fn = $self->{processor}->{configfilepath};

	# copy the current (probably good) file to .backup

	rename( $fn, "$fn.backup" );	

	# install the new file
	unless( open( DATA, ">$fn" ) )
	{
		$self->{processor}->add_message( 
			"error", 
			$self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:could_not_write", 
				error_msg=>$self->{session}->make_text($!), 
				filename=>$self->{session}->make_text( $self->{processor}->{configfilepath} ) ) );
		return;
	}
	binmode( DATA, ":utf8" );
	print DATA $data;
	close DATA;

	# then test using epadmin

	my( $result, $msg ) = $self->{session}->get_repository->test_config;

	if( $result != 0 )
	{
		# -- if it fails: move the old file back, report an error and save new file to a .broken file then abort
		rename( $fn, "$fn.broken" );
		rename( "$fn.backup", $fn );

		$self->{processor}->add_message( 
			"error", 
			$self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:did_not_install" )
		);
		my $pre = $self->{session}->make_element( "pre" );
		$pre->appendChild( $self->{session}->make_text( $msg ) );
		$self->{processor}->add_message( "warning", $pre );
		return;
	}


	unlink( "$fn.broken" ) if( -e "$fn.broken" );
	unlink( "$fn.backup" ) if( -e "$fn.backup" );

	$self->{processor}->add_message( 
		"message", 
		$self->{session}->html_phrase( 
			"Plugin/Screen/Admin/Config/Edit:file_saved",
			filename=>$self->{session}->make_text( $self->{processor}->{configfilepath} ) ) );
}

sub action_process_image_upload 
{
	my( $self ) = @_;
	
	my $session = $self->{session};

	my $max_img_count = $session->param("image_count");
	my $img_count;
	for (my $int=0;$int<=$max_img_count;$int++) 
	{
		if ($session->param("image_" . $int)) {
			$img_count = $int;
		}	
	}
	my $image_location = $session->param("image_path_" . $img_count);
	my $fname = "image_" . $img_count;
	
	my $url = $self->{session}->get_repository->get_conf("base_url");
	$image_location =~ s/$url//g;
	$image_location = $session->config( "config_path" ) . "/static" . $image_location;
	
	my $fh = $session->get_query->upload( $fname );

	if( defined( $fh ) )
	{
		binmode($fh);
		my $tmpfile = File::Temp->new( SUFFIX => ".tmp" );
		binmode($tmpfile);

		use bytes;
		while(sysread($fh,my $buffer,4096)) {
			syswrite($tmpfile,$buffer);
		}
		seek($tmpfile, 0, 0);
		
		EPrints::Utils::copy($tmpfile,$image_location);
		
		$self->{processor}->add_message( 
			"message", 
			$self->{session}->make_text("Image uploaded."));
	
	} else {
		$self->{processor}->add_message( 
			"warning", 
			$self->{session}->make_text("No image uploaded."));
	}
}

sub action_process_upload 
{
	my( $self ) = @_;
	
	my $session = $self->{session};

	my $fname = $self->{prefix}."_first_file";
	
	my $fh = $session->get_query->upload( $fname );

	if( defined( $fh ) )
	{
		binmode($fh);
		my $tmpfile = File::Temp->new( SUFFIX => ".html" );
		binmode($tmpfile);

		use bytes;
		while(sysread($fh,my $buffer,4096)) {
			syswrite($tmpfile,$buffer);
		}
		seek($tmpfile, 0, 0);
		
		my $tmpfile2 = File::Temp->new( SUFFIX => ".html" );
		binmode ($tmpfile2);


		open (FH,$tmpfile);
		while (my $line = <FH>) {
			#chomp $line;
			#print "$line\n";
			#print "\n-----BUFFER------\n\n";
			#$line =~ s/\n/ \n/g;
			#$line =~ s/\s+/ /g;
			$line =~ s/-->/-->\n/g;
			$line =~ s/<!--/\n<!--/g;
			$line =~ s/</\n</g;
			#$line =~ s/></>\n</g;
			#$line =~ s/> </>\n</g;
			syswrite($tmpfile2,$line);
		}
	
		close (FH);
			
		
		open (FH,$tmpfile2);
		while (my $line = <FH>) {
			chomp $line;
			$self->process_line($line);
		}
		close (FH);
		


		#my $doc = $session->get_repository->parse_xml( $tmpfile );
		
		#my $html = $doc->documentElement;
		#$self->process_nodes($html);
		#use Data::Dumper;
		#print Dumper $node_collection;
		#my $template = $node_collection->{"template"};
		
	}
	foreach my $doc ( keys %{$node_collection} )  {
		$doc = trim($doc);
		if ($node_collection->{$doc}) {
			#print $node_collection->{$doc} . "\n\n";
			my $parse;
			my $instring; 
			if (!($doc eq "template")) {
				$instring = '<div>' . $node_collection->{$doc} . '</div>';
				#$instring = $node_collection->{$doc};
			} else {
				$instring = $node_collection->{$doc};
				$instring = substr $instring, index($instring,"<head>"), length($instring);
				$instring = '<?xml version="1.0" standalone="no" ?>' . "\n" . 
	'<!DOCTYPE html SYSTEM "entities.dtd" >'. "\n\n" . 
	'<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epc="http://eprints.org/ep3/control">' . "\n" . $instring;
			}
			eval { $parse = EPrints::XML::parse_xml_string ( $instring )};
			#print "=====" . $instring . "======\n\n\n\n";
			if ($@) {
				$self->{processor}->add_message( 
					"warning", 
					$self->{session}->make_text("$doc: Page failed to parse - not updated.\n".$@."\n".$@[0]) );
				#print ($@);
				#print ($@[0]);
				#print "$doc: bad";	
			} else {
				foreach my $img_tag ( $parse->getElementsByTagName( "img" ) ) {
					my $src = $img_tag->getAttribute("src");
					my $url = $self->{session}->get_repository->get_conf("base_url");
					if (index($src,$url) < 0) {
						my $filename = substr $src,rindex($src,"/")+1,length($src);
						$src = $url . "/images/" . $filename;
						$img_tag->setAttribute("src",$src);
					}			
				}
				$instring = EPrints::XML::to_string($parse);
				my $check = '<?xml version="1.0" encoding="utf-8"?>';
				if (substr($instring,0,length($check)) == $check) {
					$instring = trim(substr($instring,length($check),length($instring)));
				}
				$instring = $self->replace_urls($instring);
				if (!($doc eq "template")) {
					$instring = substr($instring,5,length($instring));
					$instring = substr($instring,0,length($instring)-6);
					$instring = trim($instring);
				} else {
					$instring = substr $instring, index($instring,"<head>"), length($instring);
					$instring = '<?xml version="1.0" standalone="no" ?>' . "\n" . 
							'<!DOCTYPE html SYSTEM "entities.dtd" >'. "\n\n" . 
					'<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epc="http://eprints.org/ep3/control">' . "\n" . $instring;
				}
				my $original = "";
				my $string = $self->{processor}->{configfile};
				if ($doc eq "page") {
					$original = $session->config( "config_path" ) . "/" . $string;
					open (FH,$original);
					my $tmpfile = File::Temp->new( SUFFIX => ".txt" );
					binmode($tmpfile);
					my $flag = 0;
					while (my $line = <FH>) {
						$line = trim($line);
						if ($line eq "</xpage:body>") {
							$flag = 0;	
						}
						if ($line eq "<xpage:body>") {
							#print "trying!!!! \n\n";
							syswrite($tmpfile,$line . "\n\n");
							syswrite($tmpfile,$instring . "\n\n");
							$flag = 1;	
						}
						if (!($line eq "<xpage:body>") && ($flag == 0)) {
							syswrite($tmpfile,$line . "\n");
						}
					}
					

					rename($tmpfile,$original); 

					$self->{processor}->add_message( 
						"message", 
						$self->{session}->make_text("$original: Page updated.") );
				} elsif ($doc eq "template") {
					my $lang = substr $string,0,rindex($string,"/");
					$lang = substr $lang,0,rindex($lang,"/");
					$original = $session->config( "config_path" ) . "/" . $lang . "/templates/default.xml";
					#print $node_collection->{$doc};	
					#exit;
					my $tmpfile = File::Temp->new( SUFFIX => ".txt" );
					binmode($tmpfile);
					syswrite($tmpfile,$instring);
					rename($tmpfile,$original); 
					$self->{processor}->add_message( 
						"message", 
						$self->{session}->make_text("$original: Page updated.") );
				} else {
					$self->{processor}->add_message( 
						"message", 
						$self->{session}->make_text("$doc: Page will update when code is written..") );
				}
				#print "$doc: good";
			}
		}
	}
	
	$self->{processor}->add_message( 
		"message", 
		$self->{session}->html_phrase("Plugin/Screen/Admin/Config/Edit/XPage:phrases_updated") );
}

sub replace_urls 
{
	my ($self, $instring) = @_;
	my %map_url = (
		$self->{session}->get_repository->get_conf("http_url") => '$config{rel_path}',
		$self->{session}->get_repository->get_conf("https_url") => '$config{rel_path}',
		$self->{session}->get_repository->get_conf("http_cgiurl") => '$config{rel_cgipath}',
		$self->{session}->get_repository->get_conf("https_cgiurl") => '$config{rel_cgipath}'
	);
	my $frontpage = $self->{session}->get_repository->get_conf("frontpage");	
	$instring =~ s/$frontpage\"/\{\$config\{frontpage\}\}"/g;
	
	$frontpage = substr $frontpage, 0, length($frontpage)-1;
	$instring =~ s/$frontpage\"/\{\$config\{frontpage\}\}"/g;

	foreach my $http (sort{length($map_url{$a})<=>length($map_url{$b})} keys %map_url) {	
		$instring =~ s/["']$http([^"']+)/\"\{$map_url{$http}\}$1/gi;
		$instring =~ s/$http/\<epc:print expr\=\"$map_url{$http}"\/\>/g;
	}
	return $instring;

}


my $phrase_text = "";
my $phrase_open = "";
my $ignor = 0;
my $old_values = {};
sub process_line 
{
	my ( $self, $line ) = @_;
	$line = trim($line);
	if (index($line,"EPEDIT:START:IGNORE") == 5){
		$ignor = 1;
	}
	if (index($line,"EPEDIT:END:IGNORE") > 0 && $ignor > 0){
		$line = substr $line, index($line,"EPEDIT:END:IGNORE")+21;
		$ignor = 0;
	}
	if ($ignor < 1) {
		#print ("\n\nProcessing $line width INDEX ".index($line,"EPEDIT:END:")."\n\n");
		if (index($line,"EPEDIT:START:") == 5){
			if (index($line,"PIN") > 0) {
				my $node_value = substr $line, index($line,"PIN")+3, length($line);
				$node_value = trim($node_value);
				$node_value = substr $node_value,0,index($node_value,"-->");	
				$node_value = trim($node_value);
				#print '<epc:pin ref="'.trim($node_value).'" />' . "\n";
				#print "\n\nBEGIN NODE" . $node_value . "\n\n";
				$line = '<epc:pin ref="'.$node_value.'"/>';
				$node_collection->{$node_list[0]} = $node_collection->{$node_list[0]} ."\n". trim($line); 
				unshift(@node_list,$node_value);
				$line = "";
			} elsif (index($line,"PHRASE") > 0) {
				my $node_value = substr $line, index($line,"PHRASE")+6, length($line);
				$node_value = trim($node_value);
				$node_value = substr $node_value,0,index($node_value,"-->");	
				$phrase_open = trim($node_value);
			}
			if (index($line,"-->") > 0) { 
				$line = substr($line,index($line,"-->")+3,length($line));
			}
			#if (index($line,"EPEDIT:END:") == 5){
			#	if (index($line,"PIN") > 0) {
			#		print "\n\nEND NODE \n\n";
			#	} elsif (index($line,"PHRASE") > 0) {
			#		print "\n\nEND PHRASE: \n\n";
			#	}
			#	$line = substr($line,index($line,"-->")+3,length($line));
			#}
		} elsif (index($line,"EPEDIT:END:") == 5){
			if (index($line,"PIN") > 0) {
				shift(@node_list);
				$line= "";
				#print "\n\nEND NODE \n\n";
			} elsif (index($line,"PHRASE") > 0) {
				my $node_value = $phrase_open;
				#print '<epc:phrase ref="'.trim($node_value).'" />' . "\n";
				#print "\n\nBEGIN PHRASE: " . $node_value . "\n\n";
				my $fn = $self->{processor}->{configfilepath};
				$fn = substr $fn, 0, index($fn,"static/");
  				$fn = $fn . "phrases/";
				#my $tmpfile3 = File::Temp->new( SUFFIX => ".txt" );
				#system('grep \'id="' . trim($node_value). '"\' '.$fn . ' > ' . $tmpfile3);
				#open (FH3,$tmpfile3);
				#my $fline = <FH3>;
				#close(FH3);
				#$fline = substr $fline,0,index($fline,":");
				#in out, overwrite, finished phrases;

				#HOW TO FIX
				# GET old phrase for page by querying eprints.
				# If it has changed update or add it zz_webcfg.

				my $old_phrase_node = $self->{session}->html_phrase(trim($node_value));
				my $old_phrase = "";
				for($old_phrase_node->childNodes)
				{
					$old_phrase .= EPrints::XML::to_string($_, undef, 1);
				}
				
				my $new_phrase_doc = EPrints::XML::parse_xml_string("<phrase>".trim($phrase_text)."</phrase>");
				my $new_phrase = $new_phrase_doc->documentElement;
				$phrase_text = "";
				for($new_phrase->childNodes)
				{
					$phrase_text .= EPrints::XML::to_string($_, undef, 1);
				}
				
				$node_value = trim($node_value);
				
				#print STDERR $node_value . "\n";
				#print STDERR "COMPARING new =|" . $phrase_text . "| and old =|" . $old_phrase . "|\n";

				if (!($phrase_text eq $old_phrase)) {
					#my $newchunk = $self->{session}->make_doc_fragment;
					my $newchild = $self->{session}->make_element( "epp:phrase", id => $node_value );
					$new_phrase->setOwnerDocument( $newchild->ownerDocument );
					for($new_phrase->childNodes)
					{
						$newchild->appendChild( $_ );
					}
					my $fline = $fn . "zz_webcfg.xml";
				
					my $doc = EPrints::XML::parse_xml($fline);
					my $dom = ($doc->getElementsByTagName( "phrases" ))[0];
				
					$newchild->setOwnerDocument( $doc );

					my $done = 0;
					for my $child ($dom->getChildNodes()) 
					{
						next unless EPrints::XML::is_dom( $child, "Element" );
						next unless $child->getAttribute( "id" ) eq $node_value;
						#print STDERR ("Replacing Children, new value = " . $phrase_text . "\n");	
						$dom->replaceChild($newchild,$child);
						$done = 1;
					
					}
					if ($done < 1) {
						#print STDERR ("Node not found adding " . $phrase_text . "\n");	
						$dom->appendChild($newchild);
					}
					open(my $FH,">",$fline);
					print $FH $doc->toString();
					close($FH);

				}

				
#
#				my $tmpfile3 = File::Temp->new( SUFFIX => ".txt" );
#				binmode($tmpfile3);
#				my $found = 0;
#				my $changed = 0;
#				open (FH3,$fline);
#				while (my $phrase_line = <FH3>) {
#					if (index($phrase_line,'id="' . trim($node_value). '"') > 0) {
#						$found = 1;
#						if ($changed > 0) {
#							syswrite($tmpfile3,"\t" . '<epp:phrase id="' . trim($node_value) . '">' . trim($phrase_text) . '</epp:phrase>' ."\n");
#						} else {
#							syswrite($tmpfile3,$phrase_line);
#						}
#					} else {
#						syswrite($tmpfile3,$phrase_line);
#					}
#				}
#				if ($found < 1) {
#					syswrite($tmpfile3,"\t" . '<epp:phrase id="' . trim($node_value) . '">' . trim($phrase_text) . '</epp:phrase>' ."\n");
#				}
#				close FH3;				
#				
#				rename($tmpfile3,$fline);
				
 				$line = '<epc:phrase ref="'.trim($node_value).'"/>';
				#print "\n\nEND PHRASE: \n\n";
				$phrase_open = "";
				$phrase_text = "";
			} 
		}
		$line =~ s/<br>/<br\/>/g;
		$line =~ s/ahref/a href/g;

#		
#		if ((substr $line, 0, 4) eq "<img") {
#			if (!(substr $line, length($line)-2,length($line) eq "/>")) {
#				$line = substr($line , 0 , length($line)-1) . "/>"; 
#			}
#		}
#		if ((substr $line, 0, 5) eq "<link") {
#			if (!(substr $line, length($line)-2,length($line) eq "/>")) {
#				$line = substr($line , 0 , length($line)-1) . "/>"; 
#			}
#		}
#		if ((substr $line, 0, 6) eq "<input") {
#			if (!(substr $line, length($line)-2,length($line) eq "/>")) {
#				$line = substr($line , 0 , length($line)-1) . "/>"; 
#			}
#		}
		if (!($phrase_open eq "")) {
			$phrase_text = $phrase_text . " " . $line;
		} elsif (!($line eq "<html>") && !($line eq "") && !(index($line,"!DOCTYPE")>0)) {
			$node_collection->{$node_list[0]} = $node_collection->{$node_list[0]} . "\n" . trim($line); 
			#print "\n\n". @node_list[0] ."Appending : $line\n\n";
		}
	}

	#elsif (index($node_name,"comment") > 0 && index($node_value,"EPEDIT:END:") > 0) {
	#	if (index($node_value,"PIN") > 0) {
	#		shift(@node_list);
#print "RETURN TO " . $node_list[0] . "\n";	
	#	}
	#}
	
}


sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub action_download_full_file {
	my ( $self ) = @_;

	my $session = $self->{session};

	
	my $string = $self->{processor}->{configfile};
	my $char = "/";
	my $index = rindex($string,$char);
	$char = ".";
	my $index2 = rindex($string,$char);
	my $length = $index2 - $index;

	my $filename = substr $string, $index+1, $length;

	my $from = $session->config( "config_path" ) . "/" . $string;
	my $doc = $session->get_repository->parse_xml( $from );

	if( !defined $doc )
	{
		$session->get_repository->log( "Could not load file: $from" );
		return;
	}

	my $html = $doc->documentElement;
	my $page_parts = {};
	foreach my $node ( $html->getChildNodes )
	{
		my $part = $node->nodeName;


		$part =~ s/^.*://;
		next unless( $part eq "body" || $part eq "title" || $part eq "template" );

		$page_parts->{$part} = $session->make_doc_fragment;

		foreach my $kid ( $node->getChildNodes )
		{
			my $post_edit_exp_kid = edit_expand( $doc, $kid );
			my $post_epc_kid = EPrints::XML::EPC::process( 
					$post_edit_exp_kid,
					in => $from,
					session => $session ); 
			$page_parts->{$part}->appendChild( $post_epc_kid );
		}
	}

	foreach my $part ( qw/ title body / )
	{
		if( !$page_parts->{$part} )
		{
			#dang some error?
			#$session->get_repository->log( "Error: no $part element in ".$from );
			#EPrints::XML::dispose( $doc );
			#return;
		}
	}

	$page_parts->{page} = delete $page_parts->{body};


	#print EPrints::XML::to_string( $page_parts->{title} );
	#print "\n--\n\n";
	#print EPrints::XML::to_string( $page_parts->{page} );

	my $template = "default";
	if( defined $page_parts->{template} )
	{
		$template = $session->xml->text_contents_of( $page_parts->{template} );
	}

	my $template_parts = $session->template( $template )->parts;
	####
	#print join( "\n\n*****\n\n", @{$template_parts} )."\n";
	my @output = ();
	my $is_html = 0;

	my $done = {};
	push @output, $session->xhtml->doc_type;


	foreach my $bit ( @{$template_parts} )
	{
		#print STDERR "BIT " . $bit . " \n\n\n";
		$is_html = !$is_html;

		if( $is_html )
		{
			push @output, $bit;
			next;
		}



	# either 
	#  print:epscript-expr
	#  pin:id-of-a-pin
	#  pin:id-of-a-pin.textonly
	#  phrase:id-of-a-phrase
		my( @parts ) = split( ":", $bit );
		my $type = shift @parts;
		if( $type eq "print" )
		{
			my $expr = join "", @parts;
			#push @output, "<!-- EPEDIT:START:TEMPLATE:PRINT $expr -->";
			if ( $expr eq '$config{rel_path}') {
				my $temp = '$config{base_url}';
				my $result = EPrints::XML::to_string( EPrints::Script::print( $temp, { session=>$session } ), undef, 1 );
				push @output,$result;
			}
			my $result = EPrints::XML::to_string( EPrints::Script::print( $expr, { session=>$session } ), undef, 1 );
			#push @output, "<!-- EPEDIT:END:TEMPLATE:PRINT -->";
			push @output, $result;
			next;
		}

		if( $type eq "phrase" )
		{	
			my $phraseid = join "", @parts;
			push @output, "<!-- EPEDIT:START:TEMPLATE:PHRASE $phraseid -->";
			push @output, EPrints::XML::to_string( $session->html_phrase( $phraseid ), undef, 1 );
			push @output, "<!-- EPEDIT:END:TEMPLATE:PHRASE -->";
			next;
		}

		if( $type eq "pin" )
		{	
			my $pinid = shift @parts;
			my $modifier = shift @parts;
			if( defined $modifier && $modifier eq "textonly" )
			{
				if( defined $page_parts->{$pinid} )
				{
					# don't convert href's to <http://...>'s
					push @output, EPrints::Utils::tree_to_utf8( $page_parts->{$pinid}, undef, undef, undef, 1 ); 
				}

				next;
			}

			my $color = "green";
			if( $done->{$pinid} ) { $color = "red"; }
			if( $pinid eq "title" || $pinid eq "page" )
			{
				push @output, "<!-- EPEDIT:START:IGNORE -->";
				push @output, "<div><div style='text-align: left;'><table cellpadding='0' cellspacing='0' border='0'><tr><td style='padding: 2px; font-size: 10pt; background-color: $color; color: white'>$pinid</td></tr></table></div><div style='border: dashed 1px $color; padding: 2px;'>";
				push @output, "<!-- EPEDIT:END:IGNORE -->";
			}

			push @output, "<!-- EPEDIT:START:TEMPLATE:PIN $pinid -->";
			if( !defined $page_parts->{$pinid} )
			{
				if( $pinid eq "title" || $pinid eq "page" )
				{
					push @output, "no $pinid defined";
				}
			}
			else
			{
				push @output, EPrints::XML::to_string( $page_parts->{$pinid}, undef, 1 );	
			}
			push @output, "<!-- EPEDIT:END:TEMPLATE:PIN -->";

			if( $pinid eq "title" || $pinid eq "page" )
			{
				push @output, "<!-- EPEDIT:START:IGNORE -->";
				push @output, "</div></div>";
				push @output, "<!-- EPEDIT:END:IGNORE -->";
			}
			$done->{$pinid} = 1;
		}
	}

	EPrints::XML::dispose( $doc );
	my @final_output;
	foreach my $fragment(@output) {
		push @final_output,$self->insert_url($fragment);
	}
	@output = @final_output;
	$session->send_http_header( content_type=>"text/html" );
	EPrints::Apache::AnApache::header_out(
			$self->{session}->get_request,
			"Content-Disposition: attachment; filename=".$filename."html;"
			);
	print join( "", @output )."\n";
	exit;

}

sub insert_url
{
	my( $self, $inside_tag ) = @_;

	my $url = $self->{session}->get_repository->get_conf("base_url");
	$inside_tag =~ s!(=\s*['"])/!$1$url/!g;

	return $inside_tag;
}
#print "\n\n\n!!!!!\n\n";
#print join( "\n\n*****\n\n", @output )."\n";



sub edit_expand
{
	my( $doc, $node ) = @_;

	if( !EPrints::XML::is_dom( $node, "Element" ) )
	{
		return $node;
	}

	if(0&& $node->getTagName() eq "epc:phrase" )
	{
		my $s = $doc->createDocumentFragment();
		$s->appendChild( $doc->createComment( "EPEDIT:START:PAGE:PHRASE ".$node->getAttribute( "ref" ) ) );
		$s->appendChild( $node );
		$s->appendChild( $doc->createComment( "EPEDIT:END:PAGE:PHRASE" ) );
		return $s;
	}
	my $s = EPrints::XML::clone_and_own( $node, $doc, 0 );
	foreach my $kid ( $node->getChildNodes )
	{
		$s->appendChild( edit_expand( $doc, $kid ) );
	}

	return $s;
}

sub render_title
{
	my( $self ) = @_;

	my $f = $self->{session}->make_doc_fragment;
	$f->appendChild( $self->html_phrase( "page_title", file=>$self->{session}->make_text( $self->{processor}->{configfile} ) ) );
	return $f;
}

sub render
{
	my( $self ) = @_;

	# we trust the filename by this point
	
	my $path = $self->{session}->get_repository->get_conf( "config_path" );

	my $page = $self->{session}->make_doc_fragment;

	$page->appendChild( $self->html_phrase( "intro" ));

	my %buttons;
       	
	push @{$buttons{_order}}, "reload_config";
       	$buttons{reload_config} = $self->{session}->phrase( "Plugin/Screen/Admin/Reload:title" );
	
	my $form = $self->render_form;
	$form->appendChild( $self->{session}->render_action_buttons( %buttons ) );

	$page->appendChild( $form ) if ($self->allow( "config/reload" ));

	$self->{processor}->{screenid}=~m/::Edit::(.*)$/;
	my $type = $1;
	my $doc_link = $self->{session}->render_link("http://eprints.org/d/?keyword=${1}ConfigFile&filename=".$self->{processor}->{configfile});
	$page->appendChild( $self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:documentation", link=>$doc_link ));
	
	$form = $self->render_form;
	if( $type eq "XPage" )
	{
	$page->appendChild( $self->html_edit($form) );
	}
	$page->appendChild( $self->config_edit($form,$type) );
	if( $type eq "XPage" )
	{
	$page->appendChild( $self->image_edit($form) );
	}

	return $page;
}

sub config_edit
{
	my ($self, $form, $type) = @_;

	my $fn = $self->{processor}->{configfilepath};
	my $broken = 0;
	if( -e "$fn.broken" )
	{
		$broken = 1;
		$fn = "$fn.broken";
		$self->{processor}->add_message( 
			"warning", 
			$self->{session}->html_phrase( "Plugin/Screen/Admin/Config/Edit:broken" ) );
	}
	$form = $self->render_form;

	my $textarea = $self->{session}->make_element( "textarea", id=>"code", width=>"100%", name=>"data", rows=>"25", cols=>"80" );
	open( CONFIGFILE, $fn );
	while( my $line = <CONFIGFILE> ) { $textarea->appendChild( $self->{session}->make_text( $line) ); }
	close CONFIGFILE;
	$form->appendChild( $textarea );

	my %buttons;

       	push @{$buttons{_order}}, "save_config";
       	$buttons{save_config} = $self->{session}->phrase( "Plugin/Screen/Admin/Config/Edit:save_config_button" );
       	
	if( $broken )
	{
        	push @{$buttons{_order}}, "revert_config";
        	$buttons{revert_config} = $self->{session}->phrase( "Plugin/Screen/Admin/Config/Edit:revert_config_button" );
	}

	$form->appendChild( $self->{session}->render_action_buttons( %buttons ) );
	my $div = $self->{session}->make_element( "div", align => "center" );
	$div->appendChild($form);

	if( $fn =~ /\.([^\.]+)$/ && exists $CODEMIRROR_MODES{$1} )
	{
		my $mode = $CODEMIRROR_MODES{$1};

		$div->appendChild( $self->{session}->make_javascript(<<"EOJ") );
Event.observe (window, "load", function() {
	var editor = CodeMirror.fromTextArea(\$('code'), {
			mode: '$mode->{mode}',
			theme: 'neat',
			continuousScanning: 500,
			lineNumbers: true
		});
});
EOJ
	}
	
	my $box;
	my $phrase;
	if ($self->{session}->get_lang->has_phrase($self->html_phrase_id("inline_edit_title"),$self->{session})) {
		$phrase = $self->html_phrase("inline_edit_title");
	} else {
		$phrase = $self->{session}->html_phrase("Plugin/Screen/Admin/Config/Edit/Config:inline_edit_title");
	}
		
	if( $type eq "XPage" )
	{
		$box = EPrints::Box::render(
			id => "inline_edit",
			session => $self->{session},
			title => $phrase,
			collapsed => "true",
			content => $div
		);
	} else {
		$box = EPrints::Box::render(
			id => "inline_edit",
			session => $self->{session},
			title => $phrase,
			content => $div
		);
	}
	#$page->appendChild( $form );
}

sub image_edit 
{
	my ($self,$form) = @_;

	my @images = $self->get_images();
	$form = $self->render_form;
	my $div = $self->{session}->make_element( "div", align => "center" );
	my $br = $self->{session}->make_element( "br" );

	my $done = {};
	my $img_count = 0;
	foreach my $image(@images) 
	{
		if (!($done->{$image})) 
		{
			my $img_node = $self->{session}->make_element(
				"img",
				border => 1,
				style => "max-width: 200px;",
				src => $image
			);
			$done->{$image} = 1;

			my $table = $self->{session}->make_element(
				"table",
				width => "100%"
			);
			my $tr = $self->{session}->make_element(
				"tr"
			);
			my $td_img = $self->{session}->make_element(
				"td",
				height => "80px",
				align => "center"
			);
			$td_img->appendChild($img_node);
			my $td_text = $self->{session}->make_element(
				"td",
				width => "400px",
				valign => "center"
			);
			my $image_name = substr $image, rindex($image,"/")+1, length($image);
			my $bold = $self->{session}->make_element( "b" );
			$bold->appendChild($self->{session}->make_text($image_name));
			$td_text->appendChild($bold);
			my $hidden = $self->{session}->make_element(
				"input",
				type => "hidden",
				name => "image_path_" . $img_count,
				value => $image
			);
			$td_text->appendChild($hidden);
			$td_text->appendChild($br);
			

			my $inner_panel = $self->{session}->make_element( 
					"div", 
					id => $self->{prefix}."_upload" );

			$inner_panel->appendChild( $self->html_phrase( "change_image" ) );

			my $ffname = "image_" . $img_count;
			$img_count++;
			my $file_button = $self->{session}->make_element( "input",
					name => $ffname,
					id => $ffname,
					type => "file",
					);
			my $upload_progress_url = $self->{session}->get_url( path => "cgi" ) . "/users/ajax/upload_progress";
			my $onclick = "this.parentNode.insertBefore( \$('progress'), this.nextSibling); return startEmbeddedProgressBar(this.form,{'url':".EPrints::Utils::js_string( $upload_progress_url )."});";
			my $upload_button = $self->{session}->render_button(
					value => $self->phrase( "upload" ), 
					class => "ep_form_internal_button",
					name => "_action_process_image_upload",
					onclick => $onclick );
			$inner_panel->appendChild( $file_button );
			$inner_panel->appendChild( $self->{session}->make_text( " " ) );
			$inner_panel->appendChild( $upload_button );
			#my $progress_bar = $self->{session}->make_element( "div", id => "progress_image_" . $img_count );
			#$inner_panel->appendChild( $progress_bar );


			my $script = $self->{session}->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($self->phrase("really_next"))." ); } return true; } );" );
			$inner_panel->appendChild( $script);

			$inner_panel->appendChild( $self->{session}->render_hidden_field( "screen", $self->{processor}->{screenid} ) );

			$td_text->appendChild($inner_panel);
				
	
			$tr->appendChild($td_img);
			$tr->appendChild($td_text);
			$table->appendChild($tr);
			$div->appendChild($table);
		}
	}
	my $hidden = $self->{session}->make_element(
		"input",
		type => "hidden",
		name => "image_count",
		value => $img_count
	);
	$div->appendChild($hidden);
	$form->appendChild($div);
	my $box = EPrints::Box::render(
                id => "image_edit",
                session => $self->{session},
                title => $self->html_phrase("image_editor"),
                content => $form
        );	
}

sub html_edit 
{
	my ( $self, $form ) = @_;

	## Start offline page edit code
	my $table = $self->{session}->make_element(
		"table",
		width=>"82%"
		);
	my $tr = $self->{session}->make_element(
		"tr",
		);
	
	my $div = $self->{session}->make_element ( 
		"td",
		align=>"center",
		);

	my $p = $self->{session}->make_element (
		"p"
	);
	$p->appendChild($self->html_phrase("external_edit_description"));
	$div->appendChild($p);
	my %buttons1;

       	push @{$buttons1{_order}}, "download_full_file";
       	$buttons1{download_full_file} = $self->{session}->phrase( "Plugin/Screen/Admin/Config/Edit:download_full_file" );

	$div->appendChild( $self->{session}->render_action_buttons( %buttons1 ) );
	
	my $br = $self->{session}->make_element ( "br" );	
	$div->appendChild($br);

	my $inner_panel = $self->{session}->make_element( 
			"div", 
			id => $self->{prefix}."_upload_panel_file" );

	$inner_panel->appendChild( $self->html_phrase( "upload_html" ) );

	my $ffname = $self->{prefix}."_first_file";	
	my $file_button = $self->{session}->make_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		);
	my $upload_progress_url = $self->{session}->get_url( path => "cgi" ) . "/users/ajax/upload_progress";
	my $onclick = "return startEmbeddedProgressBar(this.form,{'url':".EPrints::Utils::js_string( $upload_progress_url )."});";
	my $upload_button = $self->{session}->render_button(
		value => $self->phrase( "upload" ), 
		class => "ep_form_internal_button",
		name => "_action_process_upload",
		onclick => $onclick );
	$inner_panel->appendChild( $file_button );
	$inner_panel->appendChild( $self->{session}->make_text( " " ) );
	$inner_panel->appendChild( $upload_button );
	my $progress_bar = $self->{session}->make_element( "div", id => "progress" );
	$inner_panel->appendChild( $progress_bar );

	
	my $script = $self->{session}->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($self->phrase("really_next"))." ); } return true; } );" );
	$inner_panel->appendChild( $script);
	
	$inner_panel->appendChild( $self->{session}->render_hidden_field( "screen", $self->{processor}->{screenid} ) );

	$div->appendChild($inner_panel);
	
	$tr->appendChild($div);
	$table->appendChild($tr);
	$form->appendChild($table);
	$div = $self->{session}->make_element( "div", align => "center" );
	$div->appendChild($form);

	my $box = EPrints::Box::render(
		id => "external_edit",
		session => $self->{session},
		title => $self->html_phrase("external_edit_title"), 
		content => $div
	);
	
	return $box;
}

sub get_images 
{
	my ( $self ) = @_;
	
	my $session = $self->{session};

	my $string = $self->{processor}->{configfile};
	my $char = "/";
	my $index = rindex($string,$char);
	$char = ".";
	my $index2 = rindex($string,$char);
	my $length = $index2 - $index;

	my $filename = substr $string, $index+1, $length;

	my $from = $session->config( "config_path" ) . "/" . $string;

	my $doc = $session->get_repository->parse_xml( $from );

	if( !defined $doc )
	{
		$session->get_repository->log( "Could not load file: $from" );
		return;
	}

	my $html = $doc->documentElement;
	my $page_parts = {};
	foreach my $node ( $html->getChildNodes )
	{
		my $part = $node->nodeName;
		
		$part =~ s/^.*://;
		next unless( $part eq "body" || $part eq "title" || $part eq "template" );

		$page_parts->{$part} = $session->make_doc_fragment;

		foreach my $kid ( $node->getChildNodes )
		{
			my $post_edit_exp_kid = edit_expand( $doc, $kid );
			my $post_epc_kid = EPrints::XML::EPC::process( 
					$post_edit_exp_kid,
					in => $from,
					session => $session ); 
			$page_parts->{$part}->appendChild( $post_epc_kid );
		}
	}

	foreach my $part ( qw/ title body / )
	{
		if( !$page_parts->{$part} )
		{
			#dang some error?
			#$session->get_repository->log( "Error: no $part element in ".$from );
			#EPrints::XML::dispose( $doc );
			#return;
		}
	}

	$page_parts->{page} = delete $page_parts->{body};


	#print EPrints::XML::to_string( $page_parts->{title} );
	#print "\n--\n\n";
	#print EPrints::XML::to_string( $page_parts->{page} );

	my $template = "default";
	if( defined $page_parts->{template} )
	{
		$template = $session->xml->text_contents_of( $page_parts->{template} );
	}

	####
	my $template_parts = $session->template( $template )->parts;
	#print join( "\n\n*****\n\n", @{$template_parts} )."\n";
	my @output = ();
	my $is_html = 0;

	my $done = {};
	push @output, $session->xhtml->doc_type;


	foreach my $bit ( @{$template_parts} )
	{
		#print STDERR "BIT " . $bit . " \n\n\n";
		$is_html = !$is_html;

		if( $is_html )
		{
			push @output, $bit;
			next;
		}



	# either 
	#  print:epscript-expr
	#  pin:id-of-a-pin
	#  pin:id-of-a-pin.textonly
	#  phrase:id-of-a-phrase
		my( @parts ) = split( ":", $bit );
		my $type = shift @parts;
		if( $type eq "print" )
		{
			my $expr = join "", @parts;
			#push @output, "<!-- EPEDIT:START:TEMPLATE:PRINT $expr -->";
			if ( $expr eq '$config{rel_path}') {
				my $temp = '$config{base_url}';
				my $result = EPrints::XML::to_string( EPrints::Script::print( $temp, { session=>$session } ), undef, 1 );
				push @output,$result;
			}
			my $result = EPrints::XML::to_string( EPrints::Script::print( $expr, { session=>$session } ), undef, 1 );
			#push @output, "<!-- EPEDIT:END:TEMPLATE:PRINT -->";
			push @output, $result;
			next;
		}

		if( $type eq "phrase" )
		{	
			my $phraseid = join "", @parts;
			push @output, "<!-- EPEDIT:START:TEMPLATE:PHRASE $phraseid -->";
			push @output, EPrints::XML::to_string( $session->html_phrase( $phraseid ), undef, 1 );
			push @output, "<!-- EPEDIT:END:TEMPLATE:PHRASE -->";
			next;
		}

		if( $type eq "pin" )
		{	
			my $pinid = shift @parts;
			my $modifier = shift @parts;
			if( defined $modifier && $modifier eq "textonly" )
			{
				if( defined $page_parts->{$pinid} )
				{
					# don't convert href's to <http://...>'s
					push @output, EPrints::Utils::tree_to_utf8( $page_parts->{$pinid}, undef, undef, undef, 1 ); 
				}

				next;
			}

			my $color = "green";
			if( $done->{$pinid} ) { $color = "red"; }
			if( $pinid eq "title" || $pinid eq "page" )
			{
				push @output, "<!-- EPEDIT:START:IGNORE -->";
				push @output, "<div><div style='text-align: left;'><table cellpadding='0' cellspacing='0' border='0'><tr><td style='padding: 2px; font-size: 10pt; background-color: $color; color: white'>$pinid</td></tr></table></div><div style='border: dashed 1px $color; padding: 2px;'>";
				push @output, "<!-- EPEDIT:END:IGNORE -->";
			}

			push @output, "<!-- EPEDIT:START:TEMPLATE:PIN $pinid -->";
			if( !defined $page_parts->{$pinid} )
			{
				if( $pinid eq "title" || $pinid eq "page" )
				{
					push @output, "no $pinid defined";
				}
			}
			else
			{
				push @output, EPrints::XML::to_string( $page_parts->{$pinid}, undef, 1 );	
			}
			push @output, "<!-- EPEDIT:END:TEMPLATE:PIN -->";

			if( $pinid eq "title" || $pinid eq "page" )
			{
				push @output, "<!-- EPEDIT:START:IGNORE -->";
				push @output, "</div></div>";
				push @output, "<!-- EPEDIT:END:IGNORE -->";
			}
			$done->{$pinid} = 1;
		}
	}

	EPrints::XML::dispose( $doc );
	my $final_output = join "", @output;

	my @images;
	while($final_output =~ /(?:<img [^>]*src=["']([^"']+)["'])/g)
	{
		push @images, $1;
	}

	return @images;
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;
	$chunk->appendChild( $self->{session}->render_hidden_field( "configfile", $self->{processor}->{configfile} ) );
	$chunk->appendChild( $self->SUPER::render_hidden_bits );

	return $chunk;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url."&configfile=".$self->{processor}->{configfile};
}

sub render_links 
{
	my ( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $xml->create_text_node( "\n\t" ) );
	$frag->appendChild( $repo->make_javascript( undef,
			src => $repo->get_url( path => "static", "codemirror/lib/codemirror.js" ),
		) );
	$frag->appendChild( $xml->create_text_node( "\n\t" ) );
	$frag->appendChild( $xml->create_element( "link",
			rel => "stylesheet",
			type => "text/css",
			href => $repo->get_url( path => "static", "codemirror/lib/codemirror.css" ),
		) );
	# load modes
	my %loaded;
	foreach my $mode (values %CODEMIRROR_MODES)
	{
		for(@{$mode->{js}})
		{
			next if $loaded{$_}++;
			$frag->appendChild( $xml->create_text_node( "\n\t" ) );
			$frag->appendChild( $repo->make_javascript( undef,
					src => $repo->get_url( path => "static", "codemirror/$_" ),
				) );
		}
	}
	# load theme
	$frag->appendChild( $xml->create_text_node( "\n\t" ) );
	$frag->appendChild( $xml->create_element( "link",
			rel => "stylesheet",
			type => "text/css",
			href => $repo->get_url( path => "static", "codemirror/theme/neat.css" ),
		) );
	
	$frag->appendChild( $self->{session}->xml->create_data_element( "style", $self->{session}->make_text( <<EOS ), type=>"text/css" ) );
	.CodeMirror {
		text-align: left;
		background-color: #fff;
		font-size: 10pt;
	}
EOS

	return $frag;
}

sub register_furniture
{
	my( $self ) = @_;

	$self->SUPER::register_furniture;

	my $link = $self->{session}->render_link( "?screen=Admin::Config" );

	$self->{processor}->before_messages( $self->{session}->html_phrase( 
		"Plugin/Screen/Admin/Config:back_to_config",
		link=>$link ) );
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

