=head1 NAME

EPrints::Plugin::Screen::Admin::EPM::Available

=cut

package EPrints::Plugin::Screen::Admin::EPM::Available;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ install /];
		
	$self->{appears} = [
		{ 
			place => "admin_epm_tabs", 
			position => 200, 
		},
	];

	$self->{expensive} = 1;

	return $self;
}

sub can_be_viewed { shift->EPrints::Plugin::Screen::Admin::EPM::can_be_viewed( @_ ) }
sub allow_install { shift->can_be_viewed( @_ ) }

sub properties_from
{
	shift->EPrints::Plugin::Screen::Admin::EPM::properties_from();
}

sub action_install
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::EPM";

	my $repo = $self->{repository};
	my $basename = $self->get_subtype;

	my $ffname = $basename."_file";
	my $filename = $repo->param( $ffname );
	if( defined $filename )
	{
		return $self->action_upload;
	}
}

sub action_upload
{
	my( $self ) = @_;

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

	my $xml;
	while(sysread($fh,$xml,65536,length($xml)))
	{
		if(length($xml) > 2097152) # sanity-check
		{
			$self->{processor}->add_message( "error", $self->html_phrase( "error:upload" ) );
			return;
		}
	}

	my $epm = $repo->dataset( "epm" )->dataobj_class->new_from_xml( $repo, $xml );
	if( !defined $epm )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "error:corrupted" ) );
		return;
	}

	return if !$epm->install( $self->{processor} );

	$self->{processor}->{dataobj} = $epm;
	my $controller = $epm->control_screen( processor => $self->{processor} );

	# load the add-on classes post-install
	$controller->reload_config;

	$self->{processor}->add_message( "message", $self->html_phrase( "installed",
		epm => $epm->render_citation( "brief" ),
	) );

	$controller->action_enable;
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $basename = $self->get_subtype;

	my $frag = $xml->create_document_fragment;

	my $ffname = $basename."_file";
	my $form = $self->render_form;
	my $file_button = $xml->create_element( "input",
			name => $ffname,
			id => $ffname,
			type => "file",
			size=> 40,
			maxlength=>40,
	);
	$form->appendChild( $file_button );
	$form->appendChild( $repo->render_action_buttons(
		install => $self->phrase( "action_install" ),
	) );
	$frag->appendChild( $self->html_phrase( "upload_form",
		form => $form,
		) );

	return $frag;
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

