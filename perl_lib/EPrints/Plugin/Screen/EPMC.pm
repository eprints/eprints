=head1 NAME

EPrints::Plugin::Screen::EPMC - Package manager controller

=head1 DESCRIPTION

This screen is a controller for installed packages. It allows the user to enable, disable or configure an installed package.

Configuration is the default view for this screen.

=cut

package EPrints::Plugin::Screen::EPMC;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{actions} = [qw( enable disable )];

	return $self;
}

sub reload_config
{
	my( $self ) = @_;

	my $plugin = $self->{repository}->plugin( "Screen::Admin::Reload",
		processor => $self->{processor}
	);
	if( defined $plugin )
	{
		local $self->{processor}->{screenid};
		$plugin->action_reload_config;
	}
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "repository/epm" );
}
sub allow_enable { shift->can_be_viewed( @_ ) }
sub allow_disable { shift->can_be_viewed( @_ ) }
sub allow_uninstall { shift->can_be_viewed( @_ ) }

sub properties_from
{
	shift->EPrints::Plugin::Screen::Admin::EPM::properties_from();
}

sub hidden_bits
{
	my( $self ) = @_;

	return(
		$self->SUPER::hidden_bits,
		epm => $self->{processor}->{dataobj}->id,
	);
}

=item $screen->action_enable( [ SKIP_RELOAD ] )

Enable the L<EPrints::DataObj::EPM> for the current repository.

If SKIP_RELOAD is true will not reload the repository configuration.

=cut

sub action_enable
{
	my( $self, $skip_reload ) = @_;

	my $repo = $self->{repository};
	my $epm = $self->{processor}->{dataobj};

	my $base_path = $repo->config( "archiveroot" ) . '/cfg/cfg.d';

	$self->{processor}->{screenid} = "Admin::EPM";

	$epm->enable( $self->{processor} );

	# restore any backed-up files
	foreach my $file ($epm->config_files)
	{
		my $filename = $file->value( "filename" );
		$filename =~ s/^.*\///;
		my $filepath = "$base_path/$filename";
		next if !-f $filepath;
		next if !-f "$filepath.epmsave";
		rename($filepath, "$filepath.epmnew");
		rename("$filepath.epmsave", $filepath);
		$self->{processor}->add_message( "warning", $repo->html_phrase( "Plugin/Screen/EPMC:restored",
			filename => $repo->xml->create_text_node( $filepath ),
			saved => $repo->xml->create_text_node( "$filepath.epmnew" ),
		) );
	}

	$self->reload_config if !$skip_reload;
}

=item $screen->action_disable( [ SKIP_RELOAD ] )

Disable the L<EPrints::DataObj::EPM> for the current repository.

If SKIP_RELOAD is true will not reload the repository configuration.

=cut

sub action_disable
{
	my( $self, $skip_reload ) = @_;

	my $repo = $self->{repository};
	my $epm = $self->{processor}->{dataobj};

	my $base_path = $repo->config( "archiveroot" ) . '/cfg/cfg.d';

	# backup any changed files
	foreach my $file ($epm->config_files)
	{
		next if !$file->is_set( "hash" );
		my $filename = $file->value( "filename" );
		$filename =~ s/^.*\///;
		my $filepath = "$base_path/$filename";
		next if !-f $filepath;
		my $data;
		if( open(my $fh, "<", $filepath) )
		{
			sysread($fh, $data, -s $fh);
			close($fh);
		}
		next if Digest::MD5::md5_hex( $data ) eq $file->value( "hash" );
		if( open(my $fh, ">", "$filepath.epmsave") )
		{
			syswrite($fh, $data);
			close($fh);
		}
		$self->{processor}->add_message( "warning", $repo->html_phrase( "Plugin/Screen/EPMC:saved",
			filename => $repo->xml->create_text_node( $filepath ),
			saved => $repo->xml->create_text_node( "$filepath.epmsave" ),
		) );
	}

	$self->{processor}->{screenid} = "Admin::EPM";

	$epm->disable( $self->{processor} );

	$self->reload_config if !$skip_reload;
}

sub render_action_link
{
	my( $self ) = @_;

	return $self->{repository}->xml->create_document_fragment;
}

sub render
{
	my( $self ) = @_;

	return $self->{repository}->xml->create_document_fragment;
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

