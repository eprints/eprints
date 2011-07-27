=head1 NAME

EPrints::Plugin::Screen::Admin::EPM::Available

=cut

package EPrints::Plugin::Screen::Admin::EPM::Available;

@ISA = ( 'EPrints::Plugin::Screen::Admin::EPM' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ install upload upgrade search /];
		
	$self->{appears} = [
		{ 
			place => "admin_epm_tabs", 
			position => 200, 
		},
	];

	$self->{expensive} = 1;

	return $self;
}

sub allow_install { shift->can_be_viewed( @_ ) }
sub allow_upgrade { shift->can_be_viewed( @_ ) }
sub allow_upload { shift->can_be_viewed( @_ ) }
sub allow_search { shift->can_be_viewed( @_ ) }

sub wishes_to_export { shift->{repository}->param( "ajax" ) }
sub export_mimetype { "text/html; charset=utf-8" }

sub action_upload
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::EPM";

	my $repo = $self->{repository};
	my $basename = $self->get_subtype;

	my $ffname = $basename."_file";
	my $filename = $repo->param( $ffname );
	my $fh = $repo->get_query->upload( $ffname );

	if( !defined $fh )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "error:upload" ) );
		return;
	}

	# CGI's file handles don't work with event_parse()
	my $tmpfile = File::Temp->new;
	while(sysread($fh, my $buffer, 4092))
	{
		syswrite($tmpfile, $buffer);
	}
	sysseek($tmpfile, 0, 0);
	my $epm = $repo->dataset( "epm" )->dataobj_class->new_from_file( $repo, $tmpfile );

	if( !defined $epm )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "error:corrupted" ) );
		return;
	}

	$self->_install( $epm );
}

sub action_install
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	$self->{processor}->{screenid} = "Admin::EPM";

	my $base_url = $repo->param( "base_url" );
	my $eprintid = $repo->param( "eprintid" );

	my $source;
	EPrints::EPM::Source->map( $repo, sub {
		$source = $_[1] if $_[1]->{base_url} eq $base_url;
	});
	EPrints->abort( "Source not found" ) if !defined $source;

	# retrieve from repository
	my $epm = $source->epm_by_eprintid( $eprintid );
	EPrints->abort( "EPM not found: $source->{err}" ) if !defined $epm;

	$self->_install( $epm );
}

sub _install
{
	my( $self, $epm ) = @_;

	my $repo = $self->{repository};

	$self->{processor}->{dataobj} = $epm;

	# don't clobber an existing epm
	if( defined $repo->dataset( "epm" )->dataobj( $epm->value( "epmid" ) ) )
	{
		$self->{processor}->add_message( 
			$self->html_phrase( "exists",
				epm => $epm->render_citation
		) );
		return;	
	}

	# install
	return if !$epm->install( $self->{processor} );

	# validate
	my( $rc, $err ) = $repo->test_config;

	# uninstall on failure
	if( $rc != 0 )
	{
		$self->{processor}->add_message( "error",
			$repo->html_phrase( "Plugin/Screen/Admin/Reload:reload_bad_config",
				output => $repo->xml->create_text_node( $err )
		) );
		$epm->uninstall( $self->{processor} );
		return;
	}

	$repo->load_config;

	my $controller = $epm->control_screen( processor => $self->{processor} );
	# enable if not already enabled
	$controller->action_enable( 1 ) if !$epm->is_enabled;

	# now trigger a reload for everyone
	$repo->reload_config;

	$self->{processor}->add_message( "message", $self->html_phrase( "installed",
		epm => $epm->render_citation
	) );

	return 1;
}

sub action_upgrade
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::EPM";

	my $repo = $self->{repository};

	my $base_url = $repo->param( "base_url" );
	my $eprintid = $repo->param( "eprintid" );

	my $source;
	EPrints::EPM::Source->map( $repo, sub {
		$source = $_[1] if $_[1]->{base_url} eq $base_url;
	});
	EPrints->abort( "Source not found" ) if !defined $source;

	# retrieve from repository
	my $epm = $source->epm_by_eprintid( $eprintid );
	EPrints->abort( "EPM not found: $source->{err}" ) if !defined $epm;

	my $iepm = $repo->dataset( "epm" )->dataobj( $epm->value( "epmid" ) );
	EPrints->abort( "Installed EPM not found" ) if !defined $iepm;

	return if !$iepm->uninstall( $self->{processor} );

	if( !$self->_install( $epm ) )
	{
		return $iepm->install( $self->{processor} );
	}
}

sub action_search
{
	my( $self ) = @_;

	$self->{processor}->{notes}->{$self->get_subtype."_q"} =
		$self->{repository}->param($self->get_subtype."_q");
	$self->{processor}->{notes}->{ep_tabs_current} = $self->get_subtype;

	$self->{processor}->{screenid} = "Admin::EPM";
}

sub render_links
{
	my( $self ) = @_;

	return $self->{repository}->make_javascript( undef,
		src => $self->{repository}->current_url( path => "static", "javascript/screen_admin_epm_available.js" ),
	);
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $basename = $self->get_subtype;

	my $frag = $xml->create_document_fragment;

	my $prefix = $self->get_subtype;

	my $div = $frag->appendChild( $xml->create_element( "div", class => "ep_block" ) );

	my $form = $div->appendChild( $self->render_form );
	$form->appendChild( $xhtml->hidden_field( "ep_tabs_current", $self->get_subtype ) );
	$form->appendChild( $xhtml->input_field(
		"${prefix}_q" => scalar($repo->param( "${prefix}_q" )),
		id => "${prefix}_q",
	) );
	$form->appendChild( $xhtml->input_field(
		"_action_search" => $repo->phrase( "lib/searchexpression:action_search" ),
		type => "submit",
		class => "ep_form_action_button",
	) );

	$frag->appendChild( $xml->create_data_element( "div",
		$self->render_results,
		id => "${prefix}_results"
	) );

	my $ffname = $basename."_file";
	$form = $self->render_form;
	my $file_button = $xml->create_element( "input",
			name => $ffname,
			id => $ffname,
			type => "file",
			size=> 40,
			maxlength=>40,
	);
	$form->appendChild( $file_button );
	$form->appendChild( $repo->render_action_buttons(
		upload => $self->phrase( "action_install" ),
	) );
	$frag->appendChild( $self->html_phrase( "upload_form",
		form => $form,
		) );

	return $frag;
}

sub render_results
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $frag = $xml->create_document_fragment;

	my %installed;

	$repo->dataset( "epm" )->dataobj_class->map( $repo, sub {
		my( undef, undef, $epm ) = @_;

		$installed{$epm->id} = $epm;
	});

	EPrints::EPM::Source->map( $repo, sub {
		my( undef, $source ) = @_;

		my $epms = $source->query( scalar($repo->param( $self->get_subtype."_q" )) );
		if( !defined $epms )
		{
			$self->{processor}->add_message( "warning", $self->html_phrase( "source_error",
				name => $xml->create_text_node( $source->{name} ),
				base_url => $xml->create_text_node( $source->{base_url} ),
				error => $xml->create_text_node( $source->{err} ),
			) );
			return;
		}

		foreach my $epm (@$epms)
		{
			my $iepm = $installed{$epm->id};
			next if defined($iepm) && !($epm->version gt $iepm->version);

			my $form = $self->render_form;
			$form->appendChild( $xhtml->hidden_field(
				"base_url",
				$source->{base_url}
			) );
			$form->appendChild( $xhtml->hidden_field(
				"eprintid",
				$epm->value( "eprintid" )
			) );
			$form->appendChild( $repo->render_action_buttons(
				(defined($iepm) ?
						(upgrade => $self->phrase( "action_upgrade" )) :
						(install => $self->phrase( "action_install" )))
			) );
			$frag->appendChild( $epm->render_citation( "control",
				url => $epm->value( "uri" ),
				target => "_blank",
				pindata => { inserts => {
					actions => $form,
				} },
			) );
		}
	});

	return $frag;
}

sub export
{
	my( $self ) = @_;

	binmode(STDOUT, ":utf8");
	my $xhtml = $self->render_results;
	print $self->{repository}->xhtml->to_xhtml( $xhtml );
	$self->{repository}->xml->dispose( $xhtml );
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

