=head1 NAME

EPrints::Plugin::Screen::Admin::EPM::Installed

=cut

package EPrints::Plugin::Screen::Admin::EPM::Installed;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ configure enable disable uninstall confirm cancel /];
		
	$self->{appears} = [
		{ 
			place => "admin_epm_tabs", 
			position => 100, 
		},
	];

	return $self;
}

sub can_be_viewed { shift->EPrints::Plugin::Screen::Admin::EPM::can_be_viewed( @_ ) }
sub allow_configure { shift->can_be_viewed( @_ ) }
sub allow_enable { shift->can_be_viewed( @_ ) }
sub allow_disable { shift->can_be_viewed( @_ ) }
sub allow_uninstall { shift->can_be_viewed( @_ ) }
sub allow_confirm { shift->can_be_viewed( @_ ) }
sub allow_cancel { shift->can_be_viewed( @_ ) }

sub properties_from
{
	shift->EPrints::Plugin::Screen::Admin::EPM::properties_from();
}

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::EPM";
}

sub action_configure
{
	my( $self ) = @_;

	my $epm = $self->{processor}->{dataobj};
	return if !defined $epm;

	my $controller = $epm->control_screen(
		processor => $self->{processor}
	);

	$controller->action_configure;
}

sub action_enable
{
	my( $self ) = @_;

	my $epm = $self->{processor}->{dataobj};
	return if !defined $epm;

	my $controller = $epm->control_screen(
		processor => $self->{processor}
	);

	$controller->action_enable;
}

sub action_disable
{
	my( $self ) = @_;

	my $epm = $self->{processor}->{dataobj};
	return if !defined $epm;

	my $controller = $epm->control_screen(
		processor => $self->{processor}
	);

	$controller->action_disable;
}

sub action_uninstall
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::EPM";

	my $epm = $self->{processor}->{dataobj};
	return if !defined $epm;

	my $repo = $self->{repository};

	my @repoids = $epm->repositories;
	if( @repoids > 1 || (@repoids == 1 && $repoids[0] ne $repo->get_id) )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "error:enabled",
			repoids => $repo->xml->create_text_node( join(', ', @repoids ) ),
		) );
		return;
	}

	my $actions = $self->render_form;
	$actions->appendChild( $repo->xhtml->hidden_field(
		dataobj => $epm->id,
	) );
	$actions->appendChild( $repo->render_action_buttons(
		confirm => $self->phrase( "action_confirm" ),
		cancel => $self->phrase( "action_cancel" ),
	) );

	$self->{processor}->add_message( "warning", $self->html_phrase( "confirm",
		actions => $actions,
	) );
}

sub action_confirm
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Admin::EPM";

	my $epm = $self->{processor}->{dataobj};
	return if !defined $epm;

	my $repo = $self->{repository};

	my @repoids = $epm->repositories;
	if( @repoids > 1 || (@repoids == 1 && $repoids[0] ne $repo->get_id) )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "error:enabled",
			repoids => $repo->xml->create_text_node( join(', ', @repoids ) ) ) );
		return;
	}
	elsif( @repoids )
	{
		my $controller = $epm->control_screen(
			processor => $self->{processor}
		);

		return if !$controller->action_disable;
	}

	# save a copy of the extension in case the user is developing this and
	# doesn't mean to nuke it
	my $path = $repo->config( "base_path" ) . "/var/cache/epm";
	EPrints->system->mkdir( $path );
	my $filepath = $path . "/" . $epm->package_filename;
	for('', map { ".$_" } 0 .. 5)
	{
		($filepath .= $_), last if !-f "$filepath$_";
	}
	open(my $fh, ">", $filepath)
		or die "Can't write to $path: $!";
	syswrite($fh, $epm->serialise( 1 ));
	close($fh);

	if( $epm->uninstall( $self->{processor} ) )
	{
		$self->{processor}->add_message( "message", $self->html_phrase( "uninstalled", filename => $repo->xml->create_text_node( $filepath ) ) );
	}
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $frag = $xml->create_document_fragment;

	$repo->dataset( "epm" )->dataobj_class->map( $repo, sub {
		my( undef, undef, $epm ) = @_;

		local $self->{processor}->{dataobj} = $epm;

		my @buttons;

		my $form = $self->render_form;
		$form->appendChild( $xhtml->hidden_field( 
			dataobj => $epm->id,
		) );

		my $controller = $epm->control_screen(
			processor => $self->{processor}
		);
		if( $epm->is_enabled )
		{
			if( $controller->can( "action_configure" ) )
			{
				push @buttons, "configure";
			}
			push @buttons, "disable";
		}
		else
		{
			push @buttons, "enable";
		}
		push @buttons, "uninstall";

		$form->appendChild( $repo->render_action_buttons(
			(map { $_ => $self->phrase( "action_$_" ) } @buttons),
			_order => \@buttons,
		) );

		$frag->appendChild( $epm->render_citation( "control",
			pindata => { inserts => {
				actions => $form,
			} },
		) );
	});

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

