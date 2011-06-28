=head1 NAME

EPrints::Plugin::Screen::Admin::EPM

=cut

package EPrints::Plugin::Screen::Admin::EPM;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

our $previous = undef;
our $store_state = {};

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ remove_package install_package handle_upload install_cached_package remove_cached_package install_bazaar_package update_bazaar_package edit_config submit_to_bazaar update_package_cache search/]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions_system", 
			position => 1450, 
		},
	];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $processor = $self->{processor};

	my $dataset = $processor->{dataset} = $repo->dataset( "epm" );

	my $epmid = $repo->param( "dataobj" );
	if( defined $epmid )
	{
		$processor->{dataobj} = $dataset->dataobj( $epmid );
	}

	$processor->{sources} = $repo->config( "epm", "sources" );
	$processor->{sources} = [
		{ name => "EPrints Bazaar", base_url => "http://bazaar.eprints.org/" },
	] if !defined $processor->{sources};
}

sub wishes_to_export { shift->{repository}->param( "ajax" ) }

sub export_mime_type { "text/html;charset=utf-8" }

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

sub allow_update_package_cache 
{
	my( $self ) = @_;

	return $self->allow( "repository/epm" );
}

sub allow_search 
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

sub allow_submit_to_bazaar
{
	my( $self ) = @_;

	return $self->allow( "repository/epm-submit" );
}

sub action_update_package_cache
{
	my ( $self ) = @_;

	my $repo = $self->{repository};
	
	EPrints::EPM::retrieve_available_epms( $repo, undef, undef, 1 );

	$self->{processor}->add_message( "message", $self->html_phrase( "package_cache_updated" ) );

	my $screen_id = "Admin::Bazaar";
	my $redirect_url = $repo->current_url() . "?screen=" . $screen_id;
	$repo->redirect( $redirect_url );
	
	return;
}

sub action_submit_to_bazaar
{
	my ( $self ) = @_;

	my $repo = $self->{repository};
        
	my $config_file = $repo->param( "configfile" );
	my $store_url = $repo->param( "store_url" );
	my $username = $repo->param( "store_user" );
	my $password = $repo->param( "store_pass" );
        
	my $package = $repo->param( "package" );

	if (!defined $store_url || !defined $username || !defined $password) 
	{
		my $action_url = URI::http->new;
		$action_url->query_form(
			screen => $self->{processor}->{screenid},
			action => "submit_to_bazaar",
			package => $package,
		);

		my $show_url = $action_url->clone;
		$repo->redirect($action_url);	
		exit();
	}
	my $archive_root = $repo->get_conf("archiveroot");
        my $epm_path = $archive_root . "/var/epm/cache/";
	my $package_path = $epm_path . $package;
	if (!defined $package) 
	{
		$self->{processor}->add_message( "error", $repo->html_phrase( "epm_error_no_package" ) );
		return;
	}
	unless ( -e $package_path )
	{
		$self->{processor}->add_message( "error", $repo->html_phrase( "epm_error_no_package" ) );
		return;
	}

	my $uri = EPrints::EPM::submit_to_store($repo,$store_url,$username,$password,$package_path);

	my $phrase = $repo->make_doc_fragment();
	$phrase->appendChild($self->html_phrase( "submitted" ));
	$phrase->appendChild($repo->make_text( " @ "));
	my $a = $repo->make_element( "a", href=>$uri );
	$a->appendChild($repo->make_text($uri));
	$phrase->appendChild($a);

	$self->{processor}->add_message( "message", $phrase );
	
	return;

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
		exit();
	} else {
		$screen_id = $config_file;
		$self->{processor}->{screenid} = $screen_id;
	}
}

sub action_update_bazaar_package
{
	my ( $self ) = @_;

	$previous = "updates";

	$self->action_install_bazaar_package();
}

sub action_install_bazaar_package
{
	my ( $self ) = @_;
	
	my $repo = $self->{session};

	$previous = "available" if (!defined $previous);

        my $package_name = $repo->param( "package" );
	my $app = EPrints::EPM::retrieve_available_epms($repo,undef,$package_name);
	my $url = $app->{epm};

	my $epm_file = EPrints::EPM::download_package($repo,$url);
	
	my $message;

	if (!defined $epm_file) {
		$self->{processor}->add_message( "error", $repo->html_phrase( "epm_error_no_package" ) );
		return;
	}

	my $others = EPrints::EPM::installed_on_other_repository($repo,$app);

	my $error_flag = undef;
	foreach my $repo_id(keys %$others) {
		next if (defined $message and substr($message,0,length("epm_error_")));
		$message = undef;
		my $other_repo = new EPrints::Session( 1, $repo_id );	
		$message = EPrints::EPM::install($other_repo, $epm_file);
		if (defined $message) {	
			$error_flag = 1 if (defined $message and substr($message,0,length("epm_error_")));
			$message =~ /epm_([^_]*)/;
			if (substr($message,0,length("epm_warning_custom_")) eq "epm_warning_custom_" || substr($message,0,length("epm_error_custom_")) eq "epm_error_custom_") 
			{
				$message = substr($message,index($message,"custom_")+7,length($message));
				$self->{processor}->add_message( $1, $repo->make_text($message) );
			}
		 	else 
			{
				$self->{processor}->add_message( $1, $repo->html_phrase($message) );
			}
		}
	}

	$message = undef;
	unless($error_flag) 
	{
		$message = EPrints::EPM::install($repo, $epm_file);
	}
	else 
	{
		return;
	}

	if(!defined $message)
	{
		$message = 'epm_message_install_successful';
		my $plugin = $repo->plugin( "Screen::Admin::Reload",
			processor => $self->{processor}
			);
		if( defined $plugin )
		{
			local $self->{processor}->{screenid};
			$plugin->action_reload_config;
		}
	}

	$message =~ /epm_([^_]*)/;
	if (substr($message,0,length("epm_warning_custom_")) eq "epm_warning_custom_" || substr($message,0,length("epm_error_custom_")) eq "epm_error_custom_") 
	{
		$message = substr($message,index($message,"custom_")+7,length($message));
		$self->{processor}->add_message( $1, $repo->make_text($message) );
	}
 	else 
	{
		$self->{processor}->add_message( $1, $repo->html_phrase($message) );
	}

}

sub action_handle_upload
{
	my ( $self ) = @_;

	$previous = "custom";

	my $repo = $self->{session};

	my $fname = "_first_file";

	my $fh = $repo->get_query->upload( $fname );

	if( !defined( $fh ) ) 
	{
		$self->{processor}->add_message(
			'error',
			$repo->html_phrase('epm_error_failed_to_cache_package')
			);
	}

	binmode($fh);
	use bytes;

	my $tmpfile = File::Temp->new( SUFFIX => ".zip" );

	while(sysread($fh,my $buffer, 4096)) {
		syswrite($tmpfile,$buffer);
	}

	my $message = EPrints::EPM::cache_package($repo, $tmpfile);

	$self->{processor}->{screenid} = "Admin::Bazaar";

	if ( $message ) {
		$self->{processor}->add_message(
			'error',
			$repo->html_phrase($message)
			);
		return();
	}

	
	$self->{processor}->add_message(
		'message',
		$repo->html_phrase('epm_message_package_cached')
		);

}

sub action_install_cached_package
{
	my ( $self ) = @_;
        
	my $repo = $self->{session};

	$previous = "custom";

        my $package = $repo->param( "package" );

	if (!defined $package) {
		$self->{processor}->add_message(
			"error",
			$repo->make_text("No package specified")
			);
		return; 
	}
	
	my $others = EPrints::EPM::installed_on_other_repository($repo,undef,$package);
	
	my $archive_root = $repo->get_conf("archiveroot");
        my $epm_path = $archive_root . "/var/epm/cache/";
	$package = $epm_path . $package;
	
	my $message;

	if (!defined $package) {
		$self->{processor}->add_message( "error", $repo->html_phrase( "epm_error_no_package" ) );
		return;
	}

	my $error_flag = undef;
	foreach my $repo_id(keys %$others) {
		next if (defined $message and substr($message,0,length("epm_error_")));
		$message = undef;
		my $other_repo = new EPrints::Session( 1, $repo_id );	
		$message = EPrints::EPM::install($other_repo, $package);
		if (defined $message) {	
			$error_flag = 1 if (defined $message and substr($message,0,length("epm_error_")));
			$message =~ /epm_([^_]*)/;
			if (substr($message,0,length("epm_warning_custom_")) eq "epm_warning_custom_" || substr($message,0,length("epm_error_custom_")) eq "epm_error_custom_") 
			{
				$message = substr($message,index($message,"custom_")+7,length($message));
				$self->{processor}->add_message( $1, $repo->make_text($message) );
			}
		 	else 
			{
				$self->{processor}->add_message( $1, $repo->html_phrase($message) );
			}
		}
	}

	$message = undef;
	unless($error_flag) 
	{
		$message = EPrints::EPM::install($repo, $package);
	}
	else 
	{
		return;
	}

	if(!defined $message)
	{
		$message = 'epm_message_install_successful';
		my $plugin = $repo->plugin( "Screen::Admin::Reload",
			processor => $self->{processor}
			);
		if( defined $plugin )
		{
			local $self->{processor}->{screenid};
			$plugin->action_reload_config;
		}
	}

	$message =~ /epm_([^_]*)/;
	if (substr($message,0,length("epm_warning_custom_")) eq "epm_warning_custom_" || substr($message,0,length("epm_error_custom_")) eq "epm_error_custom_") 
	{
		$message = substr($message,index($message,"custom_")+7,length($message));
		$self->{processor}->add_message( $1, $repo->make_text($message) );
	}
 	else 
	{
		$self->{processor}->add_message( $1, $repo->html_phrase($message) );
	}
	
}

sub action_remove_package
{
        my ( $self ) = @_;

	$previous = "installed";

        my $repo = $self->{session};

        my $package = $repo->param( "package" );
	
	my $message = EPrints::EPM::remove($repo,$package);
	
	if( $message =~ /epm_([^_]*)/ )
	{
		if (substr($message,0,7) eq "custom_") 
		{
			$self->{processor}->add_message( $1, $message );
		}
		else 
		{
			$self->{processor}->add_message( $1, $repo->html_phrase($message) );
		}
		return if ($1 == "error");

	}

	my $plugin = $repo->plugin( "Screen::Admin::Reload",
		processor => $self->{processor}
		);

	if( defined $plugin )
	{
		local $self->{processor}->{screenid};
		$plugin->action_reload_config;
	}

	$self->{processor}->add_message(
			'message',
			$repo->html_phrase('epm_message_package_removed')
			);

	return;

}

sub action_remove_cached_package 
{
	my ( $self ) = @_;

        my $repo = $self->{session};

	$previous = "custom";

        my $package = $repo->param( "package" );
	
	my $message = EPrints::EPM::remove_cache_package($repo,$package);
	
	if ( $message ) {
		$self->{processor}->add_message(
				'error',
				$repo->html_phrase($message)
				);
		return;
	}

	$self->{processor}->add_message(
			'message',
			$repo->html_phrase('epm_message_cached_package_removed')
			);


}

sub action_search
{
	my ( $self, $no_warning ) = @_;
	
        my $repo = $self->{repository};

	my $search = $repo->param( "search" );
	
	return if ((!defined $search or $search eq "") and $no_warning);

	if (!defined $search or $search eq "")
	{
		$self->{processor}->add_message(
			'warning',
			$self->html_phrase('epm_warning_no_search_defined')
			);

		return $repo->make_doc_fragment();
	}

	my $ret_apps = EPrints::EPM::search( $repo, $search );

	my $count = 0;
	foreach my $app(@$ret_apps){
		$count++;
	}
	
	return if ((!defined $ret_apps or $count < 1) and $no_warning);

	if (!defined $ret_apps or $count < 1) 
	{
		$self->{processor}->add_message(
			'warning',
			$self->html_phrase('epm_warning_no_search_matches')
			);

		return $repo->make_doc_fragment();
	}

	my $table = $repo->make_element("table");
	my $tr = $repo->make_element("tr");
	my $td = $repo->make_element("td", align=>"center", width=>"100%", colspan=>"2");
	my $h2 = $repo->make_element("h2");
	$h2->appendChild($self->html_phrase("epm_search_results"));
	$td->appendChild($h2);
	$tr->appendChild($td);
	$table->appendChild($tr);

	foreach my $app(@$ret_apps){
		my $tr = $repo->make_element("tr");
		my $td = $repo->make_element("td", align=>"center", width=>"100%", colspan=>"2");
		$td->appendChild($repo->make_text("-----------------------"));
		$tr->appendChild($td);
		$table->appendChild($tr);
		$table->appendChild($self->render_app_row($app));
	}
	
	my $toolbox = $repo->render_toolbox(
			$repo->make_text(""),
			$table
			);

	return $toolbox;

}

sub update_store_states
{
	my( $self ) = @_;

	my $repository = $self->{repository};
	
	my $sources = $repository->config( "epm_sources" );
	$sources = [] if !defined $sources;

	my @offlines;

	SOURCE: foreach my $epm_source (@$sources) {
		
		my $lstore_state = EPrints::EPM::store_online($epm_source->{base_url});
		$store_state->{$epm_source->{base_url}} = $lstore_state;
		push @offlines, $epm_source->{name} if (!$lstore_state);
	
	}

	return \@offlines;

}

sub export
{
	my( $self ) = @_;

	my $current = $self->{repository}->param( "ep_tabs_current" );
	$current = 0 if !defined $current;

	my @screens;

	foreach my $item ($self->list_items( "admin_epm_tabs" ))
	{
		next if !$item->{screen}->can_be_viewed;
		push @screens, $item->{screen};
	}

	return if !defined $screens[$current];

	my $content = $screens[$current]->render;
	binmode(STDOUT, ":utf8");
	print $self->{repository}->xhtml->to_xhtml( $content );
	$self->{repository}->xml->dispose( $content );
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $frag = $xml->create_document_fragment;

	my $current = $repo->param( "ep_tabs_current" );
	$current = 0 if !defined $current;

	my @labels;
	my @tabs;
	my @expensive;

	my $i = 0;
	foreach my $item ($self->list_items( "admin_epm_tabs" ))
	{
		next if !$item->{screen}->can_be_viewed;
		my $screen = $item->{screen};

		push @labels, $screen->render_title;
		if( $i != $current && $screen->param( "expensive" ) )
		{
			push @tabs, $repo->html_phrase( "cgi/users/edit_eprint:loading" );
			push @expensive, $i;
		}
		else
		{
			push @tabs, $screen->render;
		}
		++$i;
	}

	return $xhtml->tabs( \@labels, \@tabs,
		current => $current,
		expensive => \@expensive,
	);
}

sub _render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $dom = $session->make_doc_fragment;

	my $offlines = $self->update_store_states();
	my $warning_list = $session->make_element("ul");

	foreach my $store(@$offlines) {
		my $offline_element = $session->make_element("li");
		$offline_element->appendChild($session->make_text($store));
		$warning_list->appendChild($offline_element);
	}

	if (scalar(@$offlines) > 0) {
		my $warning_content = $session->make_doc_fragment;
		$warning_content->appendChild($self->html_phrase("no_store"));
		$warning_content->appendChild($warning_list);
		my $package_warning = $session->render_message(
			"warning",
			$warning_content);
		$dom->appendChild( $package_warning );
	}
	
	my $action = $session->param( "action" ) || "";
	if ($action eq "" and $session->param("_action_search")) {
		$action = "search";
	}

	if( $action eq "showapp" )
	{
		$dom->appendChild( $self->render_app( $session->param( "appid" ) ) );
	} 
	elsif ($action eq "submit_to_bazaar")
	{
		$dom->appendChild( $self->submission_properties( $session->param( "package" ) ) );
	}
	elsif ($action eq "update_package_cache")
	{
		$self->action_update_package_cache();
		$dom->appendChild( $self->render_app_menu );
	}
	elsif ($action eq "search") 
	{
		my $ret = $self->action_search(1);
		$dom->appendChild( $ret ) if (defined $ret);
		$dom->appendChild( $self->render_app_menu ) if (!defined $ret);
	}
	else
	{
		$dom->appendChild( $self->render_app_menu );
	}

	return $dom;
}

sub submission_properties
{
	my( $self, $package ) = @_;

	my $repo = $self->{repository};
	
	my $archive_root = $repo->get_conf("archiveroot");
        my $epm_path = $archive_root . "/var/epm/cache/";
	my $package_path = $epm_path . $package;
	unless ( -e $package_path )
	{
		$self->{processor}->add_message( "error", $repo->html_phrase( "epm_error_no_package" ) );
		return;
	}

	my $html = $repo->make_doc_fragment;

	my $p = $repo->make_element("p");
	$html->appendChild($p);
	$p->appendChild($self->html_phrase("bazaar_submission_text"));
	
	my $screen_id = "Screen::".$self->{processor}->{screenid};
	my $screen = $repo->plugin( $screen_id, processor => $self->{processor} );

	my $form = $screen->render_form("POST");
	$html->appendChild($form);

	my $sources = $repo->config( "epm_sources" );
	$sources = [] if !defined $sources;

	unless (defined $sources) {
		$self->{processor}->add_message( "error", $repo->html_phrase( "epm_error_no_stores" ) );
		return;
	}

	$form->appendChild($self->html_phrase("select_store"));
	my $select = $form->appendChild( $repo->xml->create_element( "select",
				name => 'store_url'
				));
	SOURCE: foreach my $epm_source (@$sources) 
	{
		my $option = $repo->xml->create_element( "option",
				value => $epm_source->{base_url},
				);
		$option->appendChild($repo->make_text($epm_source->{name}));
		$select->appendChild($option);
	}	
	$form->appendChild($repo->make_element("br"));
	
	my $user_field = $repo->make_element(
				"input",
				name=>"store_user",
				type=>"text"
				);
	my $pass_field = $repo->make_element(
				"input",
				name=>"store_pass",
				type=>"password"
				);
	$form->appendChild($repo->html_phrase("user_fieldname_username"));
	$form->appendChild($user_field);
	$form->appendChild($repo->make_element("br"));
	$form->appendChild($repo->html_phrase("user_fieldname_password"));
	$form->appendChild($pass_field);
	$form->appendChild($repo->make_element("br"));
	$form->appendChild($repo->make_element("br"));

	my $submit_to_bazaar_button = $screen->render_action_button({
		action => "submit_to_bazaar",
		screen => $screen,
		screen_id => $screen_id,
		hidden => {
			package => $package,
		},
	} );
	$form->appendChild($submit_to_bazaar_button);
	

	return $html;
}

sub render_app
{
	my( $self, $appid ) = @_;

	my $session = $self->{session};

	my( $html );

	$html = $session->make_doc_fragment;

	my $app = EPrints::EPM::retrieve_available_epms( $session, $appid );
	
	my $table = $session->make_element("table");
	
	$table->appendChild($self->render_app_row($app));
	
	my $toolbox = $session->render_toolbox(
			$session->make_text(""),
			$table
			);

	return $toolbox;
	
}

sub render_app_row
{
	my ( $self, $app ) = @_;
	
	my $session = $self->{session};

	my $action = "install_bazaar_package";

	my $package_warning;
	my $others = EPrints::EPM::installed_on_other_repository($session,$app);

	my $other_version;
	if (defined $others) {
		foreach my $key(keys %$others) {
			$other_version = $others->{$key};
		}
	}

	my $repo_text = undef;
	if (($app->{version} gt $other_version) and (defined($other_version))) {
		$repo_text = $session->make_doc_fragment();
		$repo_text->appendChild($self->html_phrase("gt_install_warning"));
	}
	if (($app->{version} lt $other_version) and (defined($other_version))) {
		$repo_text = $session->make_doc_fragment();
		$repo_text->appendChild($self->html_phrase("lt_install_warning"));
	}
	if (defined $repo_text) 
	{
		my $text;
		foreach my $key(keys %$others) {
			$text .= $key . ", ";
		}
		if (defined $text) {
			$text = substr($text,0,length($text)-2);
			$repo_text->appendChild($session->make_text($text));
		}

		$package_warning = $session->render_message(
				"warning",
				$repo_text);
	}

	my $installed_epms = EPrints::EPM::get_installed_epms($session);
	foreach my $installed_app (@$installed_epms) {
		if ("$installed_app->{package}" eq "$app->{package}") {
			if ($app->{version} gt $installed_app->{version}) {
				$action = "update_bazaar_package";
			} else {
				$action = undef;
			}
		}
	}

	my $tr = $session->make_element("tr");

	my $td_img = $session->make_element("td", width => "120px", style=> "padding:1em; ");
	$tr->appendChild($td_img);

	my $thumbnail = $app->{icon_url} || "http://files.eprints.org/style/images/fileicons/other.png";
	my $img = $session->make_element( "img", width=>"96px", src => $thumbnail );
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

	$td_main->appendChild($package_warning) if defined($package_warning);

	my $screen_id = "Screen::".$self->{processor}->{screenid};
	my $screen = $session->plugin( $screen_id, processor => $self->{processor} );

	if (defined $action) {
		my $install_button = $screen->render_action_button({
			action => $action,
			screen => $screen,
			screen_id => $screen_id,
			hidden => {
			package => $app->{package},
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
	$td_main->appendChild($session->make_element("br"));

	my $link = $app->{uri};
	my $a = $session->make_element("a", href=>$link, target => "_blank");
	$a->appendChild($session->make_text($link));
	$td_main->appendChild($a);

	return $tr;

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

	my $tab_count = 0;
	my $current = 0;

	my ($count, $content) = tab_grid_epms($self, $update_epms );
        $title = $session->make_doc_fragment();
        $title->appendChild($self->html_phrase("updates"));
        $title->appendChild($session->make_text(" ($count)"));
	if (defined $content) {
		push @titles, $title;
		push @contents, $content;
		$current = $tab_count if ($previous eq "updates");
		$tab_count++;
	}

	($count, $content) = tab_list_epms($self, $installed_epms );
        $title = $session->make_doc_fragment();
        $title->appendChild($self->html_phrase("installed"));
        $title->appendChild($session->make_text(" ($count)"));
	if (defined $content) {
		push @titles, $title;
		push @contents, $content;
		$current = $tab_count if ($previous eq "installed");
		$tab_count++;
	}

	($count, $content) = tab_grid_epms($self, $store_epms );
        $title = $session->make_doc_fragment();
        $title->appendChild($self->html_phrase("available"));
        $title->appendChild($session->make_text(" ($count)"));
	if (defined $content) {
		push @titles, $title;
		push @contents, $content;
		$current = $tab_count if ($previous eq "available");
		$tab_count++;
	}

	($count, $content) = tab_upload_epm($self);
        $title = $session->make_doc_fragment();
        $title->appendChild($self->html_phrase("custom"));
        $title->appendChild($session->make_text(" ($count)"));
	push @titles, $title;
	push @contents, $content;
	$current = $tab_count if ($previous eq "custom");
	
	my $screen_id = "Screen::".$self->{processor}->{screenid};
	my $screen = $session->plugin( $screen_id, processor => $self->{processor} );

	my $content2 = $session->xhtml->tabs(\@titles, \@contents,current=>$current);

	$content2->appendChild($session->make_element("br"));

	my $bazaar_bottom_table = $session->make_element("table", width=>"100%");
	$content2->appendChild($bazaar_bottom_table);

	my $tr = $session->make_element("tr");
	$bazaar_bottom_table->appendChild($tr);

	my $search_td = $session->make_element("td");
	my $form = $screen->render_form();
	$form->setAttribute( method => "get" );
	$form->appendChild( $session->make_element( "input",
			name => "search",
			id => "search",
			type => "text",
			size=> 40,
			maxlength=>40,
	));
	$form->appendChild( $session->render_button(
		name => "_action_search",
		value => $session->phrase( "lib/searchexpression:action_search" )
	));
	$search_td->appendChild($form);
	$tr->appendChild($search_td);

	my $td2 = $session->make_element("td");
	$tr->appendChild($td2);
	
	my $bazaar_config_div = $session->make_element("div", align=>"right");
	$td2->appendChild($bazaar_config_div);
	
	my $update_packages_link = $session->make_element("a", href=>"?screen=Admin::Bazaar&action=update_package_cache");
	$bazaar_config_div->appendChild($update_packages_link);
	$update_packages_link->appendChild($self->html_phrase("update_bazaar_packages"));
	$bazaar_config_div->appendChild($session->make_element("br"));

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

	my $ffname = "_first_file";

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


		my $include_button = 0;
		if (defined $app->{configuration_file} and !((substr $app->{configuration_file}, 0,9) eq "cfg/cfg.d"))
		{
			my $other_screen = $session->plugin("Screen::".$app->{configuration_file}, processor=>$self->{processor});
			eval { $other_screen->can_be_viewed() }; 
			if (!$@ && $other_screen->can_be_viewed()){ $include_button = 1; } 
		}
		if (((substr $app->{configuration_file}, 0,9) eq "cfg/cfg.d") or $include_button > 0) 
		{
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

		my $package_warning;
		my $others = EPrints::EPM::installed_on_other_repository($session,$app);

		my $other_version;
		if (defined $others) {
			foreach my $key(keys %$others) {
				$other_version = $others->{$key};
			}
		}

		my $repo_text = undef;
		if (($app->{version} gt $other_version) and (defined($other_version))) {
			$repo_text = $session->make_doc_fragment();
			$repo_text->appendChild($self->html_phrase("gt_install_warning"));
		}
		if (($app->{version} lt $other_version) and (defined($other_version))) {
			$repo_text = $session->make_doc_fragment();
			$repo_text->appendChild($self->html_phrase("lt_install_warning"));
		}
		if (defined $repo_text) 
		{
			my $text;
			foreach my $key(keys %$others) {
				$text .= $key . ", ";
			}
			if (defined $text) {
				$text = substr($text,0,length($text)-2);
				$repo_text->appendChild($session->make_text($text));
			}

			$package_warning = $session->render_message(
					"warning",
					$repo_text);
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
	
		$td_main->appendChild($package_warning) if defined($package_warning);
	
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
			$td_main->appendChild($session->make_element("br"));
			my $submit_to_bazaar_button = $screen->render_action_button({
				action => "submit_to_bazaar",
				screen => $screen,
				screen_id => $screen_id,
				hidden => {
					package => $app->{package},
				},
			} );
			$td_main->appendChild($submit_to_bazaar_button);
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

	#my $vinette_url = $session->config( "rel_path" )."/images/thumbnail_surround.png";

	my $total = 0;
	foreach my $app (@$store_epms)
	{
		$count++;
		my $show_url = $action_url->clone;
		$show_url->query_form( $show_url->query_form, appid => $app->{id} );
		my $td = $session->make_element( "td", width=>"130px", style=>"padding-bottom: 15px; padding-top: 15px;", align => "center", valign => "top" );
		$tr->appendChild( $td );
		#$td->appendChild( $session->make_element( "img", src => $vinette_url, style => "position: absolute; z-index: 10" ) );
		my $link = $session->make_element( "a", href => $show_url, title => $app->{title} );
		
		my $thumbnail = $app->{icon_url} || "http://files.eprints.org/style/images/fileicons/other.png";
		$link->appendChild( $session->make_element( "img", src => $thumbnail, style => "border: none; height: 100px; width: 100px; z-index: 0" ) );
		$td->appendChild( $link );
		my $title_div = $session->make_element( "div" );
		$td->appendChild( $title_div );
		$title_div->appendChild( $session->make_text( $app->{title} ) );

		if( (++$total) % 5 == 0 )
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

#sub redirect_to_me_url
#{
#	my( $plugin ) = @_;
#
#	return $plugin->SUPER::redirect_to_me_url;
#}

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

