######################################################################
#
# EPrints::Plugin::Screen::Admin::Bazaar
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

package EPrints::Plugin::Screen::Admin::Bazaar;

@ISA = ( 'EPrints::Plugin::Screen' );

use XML::LibXML::SAX;
use XML::Simple;

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ remove_package install_package handle_upload install_cached_package remove_cached_package install_bazaar_package update_bazaar_package edit_config /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions", 
			position => 1247, 
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "repository/epm" );
}

sub allow_remove_package 
{
	my( $self ) = @_;

	return $self->allow( "repository/epm" );
}

sub allow_install_package 
{
	my( $self ) = @_;

	return $self->allow( "repository/epm" );
}

sub allow_install_cached_package 
{
	my( $self ) = @_;

	return $self->allow_install_package();
}

sub allow_install_bazaar_package 
{
	my( $self ) = @_;

	return $self->allow_install_package();
}

sub allow_update_bazaar_package
{
	my ( $self ) = @_;

	return $self->allow_install_package();
}

sub allow_remove_cached_package 
{
	my( $self ) = @_;

	return $self->allow_remove_package();
}

sub allow_handle_upload
{
	my( $self ) = @_;
		
	return $self->allow( "repository/epm" );
}

sub allow_edit_config
{
	my( $self ) = @_;
		
	return $self->allow( "repository/epm" );
}

sub action_edit_config 
{
	my ( $self ) = @_;
        
	my $session = $self->{session};

        my $config_file = $self->{session}->param( "configfile" );
	my $screen_id;

	if ((substr $config_file, 0,9) eq "cfg/cfg.d") {
		$config_file = substr $config_file, 4;
		$screen_id = "Admin::Config::View::Perl";
		my $redirect_url = $session->current_url() . "?screen=" . $screen_id . "&configfile=" . $config_file;
		$session->redirect( $redirect_url );
	} else {
		$screen_id = $config_file;
		$self->{processor}->{screenid} = $screen_id;
	}

}

sub action_update_bazaar_package
{
	my ( $self ) = @_;

	$self->action_install_bazaar_package();
}

sub action_install_bazaar_package
{
	my ( $self ) = @_;
	
	my $session = $self->{session};

        my $url_in = $self->{session}->param( "package" );

	my ($tmpdir,$epm_file) = EPrints::EPM::download_package($session,$url_in);
	
	my $type = "message";
	my ( $rc, $message);



	if (defined ${$epm_file}) {
		( $rc, $message ) = EPrints::EPM::install($session,${$epm_file});	
		if ( $rc > 0 ) {
			$type = "error";
		}
	} else {
		$type = "error";
		$message = "FAILED";
	}

	$self->{processor}->add_message(
			$type,
			$session->make_text($message)
			);

}

sub action_handle_upload
{
	my ( $self ) = @_;

	my $session = $self->{session};

	my $fname = $self->{prefix}."_first_file";

	my $fh = $session->get_query->upload( $fname );

	my $tmpfile = File::Temp->new( SUFFIX => ".zip" );

	if( defined( $fh ) ) 
	{
		binmode($fh);
		use bytes;

		while(sysread($fh,my $buffer, 4096)) {
			syswrite($tmpfile,$buffer);
		}

		my ($rc, $message) = EPrints::EPM::cache_package($session, $tmpfile);

		my $type = "message";
	
		if ( $rc > 0 ) {
			$type = "error";
		}
	
		$self->{processor}->{screenid} = "Admin::Bazaar";
		
		$self->{processor}->add_message(
			$type,
			$session->make_text($message)
			);

	}
}

sub action_install_cached_package
{
	my ( $self ) = @_;
        
	my $session = $self->{session};

        my $package = $self->{session}->param( "package" );

	if (!defined $package) {
		$self->{processor}->add_message(
			"error",
			$session->make_text("No package specified")
			);
		return; 
	}
	my $archive_root = $self->{session}->get_conf("archiveroot");
        my $epm_path = $archive_root . "/var/epm/cache/";
	$package = $epm_path . $package;

	my ( $rc, $message ) = EPrints::EPM::install($session,$package);
	
	my $type = "message";

	if ( $rc > 0 ) {
		$type = "error";
	}

	$self->{processor}->add_message(
			$type,
			$session->make_text($message)
			);
	
}

sub action_remove_package
{
        my ( $self ) = @_;

        my $session = $self->{session};

        my $package = $self->{session}->param( "package" );
	
	my ( $rc, $message ) = EPrints::EPM::remove($session,$package);
	
	my $type = "message";

	if ( $rc > 0 ) {
		$type = "error";
	}

	$self->{processor}->add_message(
			$type,
			$session->make_text($message)
			);
	
}

sub action_remove_cached_package 
{
	my ( $self ) = @_;

        my $session = $self->{session};

        my $package = $self->{session}->param( "package" );
	
	my ( $rc, $message ) = EPrints::EPM::remove_cache_package($session,$package);
	
	my $type = "message";

	if ( $rc > 0 ) {
		$type = "error";
	}

	$self->{processor}->add_message(
			$type,
			$session->make_text($message)
			);

}


sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $action = $session->param( "action" ) || "";
	
	if( $action eq "showapp" )
	{
		return $self->render_app( $session->param( "appid" ) );
	}
	else
	{
		return $self->render_app_menu;
	}
}

sub render_app
{
	my( $self, $appid ) = @_;

	my $session = $self->{session};

	my( $html, $div, $h2, $h3 );

	$html = $session->make_doc_fragment;

	my $app = EPrints::EPM::retrieve_available_epms( $session, $appid );
	
	my $installed_epms = EPrints::EPM::get_installed_epms($session);
	my $action = "install_bazaar_package";

	foreach my $installed_app (@$installed_epms) {
		if ("$installed_app->{package}" eq "$app->{package}") {
			if ($app->{version} gt $installed_app->{version}) {
				$action = "update_bazaar_package";
			} else {
				$action = undef;
			}
		}
	}

	my $table = $session->make_element("table");

	my $tr = $session->make_element("tr");
	$table->appendChild($tr);

	my $td_img = $session->make_element("td", width => "120px", style=> "padding:1em; ");
	$tr->appendChild($td_img);

	my $img = $session->make_element( "img", width=>"96px", src => $app->{preview} );
	$td_img->appendChild( $img );

	my $td_main = $session->make_element("td");
	$tr->appendChild($td_main);

	my $package_title;

	if (defined $app->{title}) {
		$package_title = $app->{title};
	} else {
		$package_title = $app->{package};
	}

	$h2 = $session->make_element("h2");
	$h2->appendChild($session->make_text($package_title));
	$td_main->appendChild($h2);

	my $screen_id = "Screen::".$self->{processor}->{screenid};
	my $screen = $session->plugin( $screen_id, processor => $self->{processor} );

	if (defined $action) {
		my $install_button = $screen->render_action_button({
			action => $action,
			screen => $screen,
			screen_id => $screen_id,
			hidden => {
			package => $app->{epm},
			},
		});
		$td_main->appendChild($install_button);
	} else {
		my $b = $session->make_element("b");
		$b->appendChild($self->html_phrase("package_installed"));
		$td_main->appendChild($b);
	}
	
	$td_main->appendChild($session->make_element("br"));
	$td_main->appendChild($session->make_element("br"));

	my $version = $self->html_phrase("version");
	my $b = $session->make_element("b");
	$b->appendChild($version);
	my $rest = $session->make_text(": " . $app->{version});
	$td_main->appendChild($b);
	$td_main->appendChild($rest);
	$td_main->appendChild($session->make_element("br"));

	$td_main->appendChild($session->make_text($app->{description}));

	my $toolbox = $session->render_toolbox(
			$session->make_text(""),
			$table
			);

	return $toolbox;


}

sub render_app_menu
{
	my( $self ) = @_;

	my $session = $self->{session};

	my( $html, $div, $h2, $h3 );

	$html = $session->make_doc_fragment;

	my $installed_epms = EPrints::EPM::get_installed_epms($session);

	my $store_epms = EPrints::EPM::retrieve_available_epms($session);
	
	my $update_epms = EPrints::EPM::get_epm_updates($installed_epms, $store_epms);

	my @titles;
	my @contents;
	my $title;

	my ($count, $content) = tab_grid_epms($self, $update_epms );
        $title = $session->make_doc_fragment();
        $title->appendChild($self->html_phrase("updates"));
        $title->appendChild($session->make_text(" ($count)"));
	if (defined $content) {
		push @titles, $title;
		push @contents, $content;
	}

	($count, $content) = tab_list_epms($self, $installed_epms );
        $title = $session->make_doc_fragment();
        $title->appendChild($self->html_phrase("installed"));
        $title->appendChild($session->make_text(" ($count)"));
	if (defined $content) {
		push @titles, $title;
		push @contents, $content;
	}

	($count, $content) = tab_grid_epms($self, $store_epms );
        $title = $session->make_doc_fragment();
        $title->appendChild($self->html_phrase("available"));
        $title->appendChild($session->make_text(" ($count)"));
	if (defined $content) {
		push @titles, $title;
		push @contents, $content;
	}

	($count, $content) = tab_upload_epm($self);
        $title = $session->make_doc_fragment();
        $title->appendChild($self->html_phrase("custom"));
        $title->appendChild($session->make_text(" ($count)"));
	push @titles, $title;
	push @contents, $content;

	my $content2 = $session->xhtml->tabs(\@titles, \@contents);

	$content2->appendChild($session->make_element("br"));
	
	my $bazaar_config_div = $session->make_element("div", align=>"right");
	$content2->appendChild($bazaar_config_div);

	my $bazaar_config_link = $session->make_element("a", href=>"?screen=Admin::Config::View::Perl&configfile=cfg.d/epm.pl");
	$bazaar_config_div->appendChild($bazaar_config_link);
	$bazaar_config_link->appendChild($self->html_phrase("edit_bazaar_config"));
	

	return $content2;

}

sub tab_upload_epm
{
	my ( $self ) = @_;

	my $session = $self->{session};
	
	my $inner_div = $session->make_element("div", align=>"center");
	
	my $p = $session->make_element(
			"p",
			style => "font-weight: bold;"
			);
	$p->appendChild($self->html_phrase("upload_epm_title"));
	$inner_div->appendChild($p);
	
	$p = $session->make_element(
			"p",
			);
	$p->appendChild($self->html_phrase("upload_epm_help"));
	$inner_div->appendChild($p);
	
	my $screen_id = "Screen::".$self->{processor}->{screenid};
	my $screen = $session->plugin( $screen_id, processor => $self->{processor} );
	
	my $upload_form = $screen->render_form("POST");
	$inner_div->appendChild($upload_form);

	my $ffname = $self->{prefix}."_first_file";

	my $file_button = $session->make_element( "input",
			name => $ffname,
			id => $ffname,
			type => "file",
			size=> 40,
			maxlength=>40,
			);
	my $upload_progress_url = $session->get_url( path => "cgi" ) . "/users/ajax/upload_progress";
	my $onclick = "return startEmbeddedProgressBar(this.form,{'url':".EPrints::Utils::js_string( $upload_progress_url )."});";
	my $add_format_button = $session->render_button(
			value => $session->phrase( "Plugin/InputForm/Component/Upload:add_format" ),
			class => "ep_form_internal_button",
			name => "_action_handle_upload",
			onclick => $onclick );
	$upload_form->appendChild( $file_button );
	$upload_form->appendChild( $session->make_element( "br" ));
	$upload_form->appendChild( $add_format_button );
	my $progress_bar = $session->make_element( "div", id => "progress" );
	$upload_form->appendChild( $progress_bar );
	my $script = $session->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($session->phrase("Plugin/InputForm/Component/Upload:really_next"))." ); } return true; } );" );
	$upload_form->appendChild( $script);
	$upload_form->appendChild( $session->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
	$upload_form->appendChild( $session->render_hidden_field( "_action_handle_upload", "Upload" ) );
	$inner_div->appendChild($upload_form);
	
	my $cached_epms = EPrints::EPM::get_cached_epms($session);
	my ($count, $cached_content) = tab_cached_epms($self, $cached_epms );

	if (defined $cached_content) {
		$inner_div->appendChild($session->make_element("br"));
		my $cache_h2 = $session->make_element("h2");
		$cache_h2->appendChild($self->html_phrase("cached_packages"));
		$inner_div->appendChild($cache_h2);
		$inner_div->appendChild($cached_content);
	}

	return ($count, $inner_div);

}

sub tab_list_epms 
{
	
	my ($self, $installed_epms) = @_;
	
	my $session = $self->{session};

	my $count = 0;
	
	my $table = $session->make_element("table", width=>"95%", style=>"margin: 2em");
	
	foreach my $app (@$installed_epms)
	{
		$count++;
		my $tr = $session->make_element("tr");
		$table->appendChild($tr);
		
		my $td_img = $session->make_element("td", width => "120px", style=> "padding:1em;");
		$tr->appendChild($td_img);
	
		my $icon_path = "packages/" . $app->{package} . "/" . $app->{icon};
		print STDERR "icon_path : " . $icon_path . "\n\n";
		my $img = $session->make_element( "img", width=>"96px", src => $session->get_conf("http_cgiroot") . "/epm_icon?image=" . $icon_path );
		$td_img->appendChild( $img );

		my $td_main = $session->make_element("td");
		$tr->appendChild($td_main);

		my $package_title;

		if (defined $app->{title}) {
			$package_title = $app->{title};
		} else {
			$package_title = $app->{package};
		}

		my $h2 = $session->make_element("h2");
		$h2->appendChild($session->make_text($package_title));
		$td_main->appendChild($h2);

		my $screen_id = "Screen::".$self->{processor}->{screenid};
		my $screen = $session->plugin( $screen_id, processor => $self->{processor} );
		
		my $remove_button = $screen->render_action_button(
				{
				action => "remove_package",
				screen => $screen,
				screen_id => $screen_id,
				hidden => {
					package => $app->{package},
				}
		});
		$td_main->appendChild($remove_button);

		if (defined $app->{configuration_file}) {
			my $edit_button = $screen->render_action_button(
					{
					action => "edit_config",
					screen => $screen,
					screen_id => $screen_id,
					hidden => {
						configfile => $app->{configuration_file},
					}
					});
			$td_main->appendChild($edit_button);
		}

		
		$td_main->appendChild($session->make_element("br"));
		$td_main->appendChild($session->make_element("br"));

		my $version = $self->html_phrase("version");
		my $b = $session->make_element("b");
		$b->appendChild($version);
		my $rest = $session->make_text(": " . $app->{version});
		$td_main->appendChild($b);
		$td_main->appendChild($rest);
		$td_main->appendChild($session->make_element("br"));

		$td_main->appendChild($session->make_text($app->{description}));
		
	}

	if ($count < 1) {
		$table = undef;
	}
	return ( $count, $table );

}

sub tab_cached_epms 
{
	
	my ($self, $cached_epms) = @_;
	
	my $session = $self->{session};

	my $count = 0;
	
	my $element = $session->make_doc_fragment();

	foreach my $app (@$cached_epms)
	{
	
		my ($verified,$message) = EPrints::EPM::verify_app($app);

		$count++;
	
		my ($message_type, $message_content);

		if ($verified) {
			$message_type = "message";
			$message_content = $self->html_phrase("package_verified");
		} else {
			$message_type = "error";
			$message_content = $session->make_doc_fragment();
			$message_content->appendChild($self->html_phrase("package_verification_failed"));
			$message_content->appendChild($session->make_element("br"));
			$message_content->appendChild($self->html_phrase("package_verification_missing_fields"));
			$message_content->appendChild($session->make_text(" [ " . $message . " ]"));
		}	

		my $table = $session->make_element("table");
		
		my $tr = $session->make_element("tr");
		$table->appendChild($tr);
		
		my $td_img = $session->make_element("td", width => "120px", style=> "padding:1em; ");
		$tr->appendChild($td_img);
		
		my $icon_path = "cache/" . $app->{package} . "/" . $app->{icon};
		my $img = $session->make_element( "img", width=>"96px", src => $session->get_conf("http_cgiroot") . "/epm_icon?image=" . $icon_path );
		$td_img->appendChild( $img );

		my $td_main = $session->make_element("td");
		$tr->appendChild($td_main);

		my $package_title;

		if (defined $app->{title}) {
			$package_title = $app->{title};
		} else {
			$package_title = $app->{package};
		}

		my $h2 = $session->make_element("h2");
		$h2->appendChild($session->make_text($package_title));
		$td_main->appendChild($h2);
	
		my $screen_id = "Screen::".$self->{processor}->{screenid};
		my $screen = $session->plugin( $screen_id, processor => $self->{processor} );
	
		my $remove_button = $screen->render_action_button({
			action => "remove_cached_package",
			screen => $screen,
			screen_id => $screen_id,
			hidden => {
				package => $app->{package},
			}
		});
		$td_main->appendChild($remove_button);
		if ($verified) 
		{
			$td_main->appendChild($session->make_element("br"));

			my $install_button = $screen->render_action_button({
				action => "install_cached_package",
				screen => $screen,
				screen_id => $screen_id,
				hidden => {
					package => $app->{package},
				},
			});
			$td_main->appendChild($install_button);
			#$td_main->appendChild($session->make_element("br"));
			my $submit_to_bazaar_button = $screen->render_action_button({
				action => "submit_to_bazaar",
				screen => $screen,
				screen_id => $screen_id,
				hidden => {
					package => $app->{package},
				},
			} );
			#$td_main->appendChild($submit_to_bazaar_button);
		}
		$td_main->appendChild($session->make_element("br"));
		$td_main->appendChild($session->make_element("br"));

		my $version = $self->html_phrase("version");
		my $b = $session->make_element("b");
		$b->appendChild($version);
		my $rest = $session->make_text(": " . $app->{version});
		$td_main->appendChild($b);
		$td_main->appendChild($rest);
		$td_main->appendChild($session->make_element("br"));

		$td_main->appendChild($session->make_text($app->{description}));
	
		my $dom_message = $session->render_message(
				$message_type,
				$message_content);
		
		my $app_element=$session->make_doc_fragment();
		$app_element->appendChild($table);
		$app_element->appendChild($dom_message);

		my $toolbox = $session->render_toolbox(
			$session->make_text(""),
			$app_element
		);

		$element->appendChild($toolbox);
		
		
	}
	
	if ($count < 1) {
		return ( $count, undef);
	}
	
	return ( $count, $element );

}

sub tab_grid_epms
{
	my ( $self, $store_epms, $installed_epms ) = @_;
	
	my $session = $self->{session};
	
	my @tabs;

	my $count = 0;

	my $table = $session->make_element( "table" );

	my $tr = $session->make_element( "tr" );
	$table->appendChild( $tr );

	my $action_url = URI::http->new;
	$action_url->query_form(
		screen => $self->{processor}->{screenid},
		action => "showapp",
	);

	my $vinette_url = $session->get_repository->get_conf( "rel_path" )."/images/thumbnail_surround.png";

	my $total = 0;
	foreach my $app (@$store_epms)
	{
		$count++;
		my $show_url = $action_url->clone;
		$show_url->query_form( $show_url->query_form, appid => $app->{id} );
		my $td = $session->make_element( "td", align => "center", valign => "top" );
		$tr->appendChild( $td );
		#$td->appendChild( $session->make_element( "img", src => $vinette_url, style => "position: absolute; z-index: 10" ) );
		my $link = $session->make_element( "a", href => $show_url, title => $app->{title} );
		my $thumbnail = $app->{thumbnail} || "http://files.eprints.org/style/images/fileicons/other.png";
		$link->appendChild( $session->make_element( "img", src => $thumbnail, style => "border: none; height: 100px; width: 100px; z-index: 0" ) );
		$td->appendChild( $link );
		my $title_div = $session->make_element( "div" );
		$td->appendChild( $title_div );
		$title_div->appendChild( $session->make_text( $app->{title} ) );

		if( (++$total) % 6 == 0 )
		{
			$tr = $session->make_element( "tr" );
			$table->appendChild( $tr );
		}
	}
	if ($count < 1) {
		$table = undef;
	}
	return ( $count, $table );

}

sub redirect_to_me_url
{
	my( $plugin ) = @_;

	return undef;
}

1;
