=head1 NAME

EPrints::Plugin::Screen::EPMC::Theme - update statics on enable/disable

=head1 DESCRIPTION

This EPM controller will update static files whenever the EPM is enabled/disabled.

=cut

package EPrints::Plugin::Screen::EPMC::Theme;

use EPrints::Plugin::Screen::EPMC;

@ISA = ( 'EPrints::Plugin::Screen::EPMC' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	return $self;
}

sub action_enable
{
	my( $self ) = @_;

	$self->SUPER::action_enable;
	
	$self->_static;
}

sub action_disable
{
	my( $self ) = @_;

	$self->SUPER::action_disable;
	
	$self->_static;
}

sub _static
{
	my( $self ) = @_;

	my $epm = $self->{processor}->{dataobj};

	my $path = $self->{repository}->config( "archiveroot" )."/html";

	FILE: foreach my $file ($epm->installed_files)
	{
		my $filename;
		foreach my $dir ("static/", qr#themes/[^/]+/static/#)
		{
			$filename = $1, last if $file->value( "filename" ) =~ /^$dir(.+)/;
		}
		next FILE if !defined $filename;
		foreach my $langid (@{$self->{repository}->config( "languages" )})
		{
			my $filepath = "$path/$langid/$filename";
			if( -f $filepath ) {
				unlink($filepath);
			}
			if( $filename =~ m#^javascript/auto/# ) {
				unlink("$path/$langid/javascript/auto.js");
				unlink("$path/$langid/javascript/secure_auto.js");
			}
			elsif( $filename =~ m#^style/auto/# ) {
				unlink("$path/$langid/style/auto.css");
			}
			elsif( $filename =~ m/^(.+)\.xpage$/ ) {
				for(qw( html head page title title.textonly ))
				{
					unlink("$path/$langid/$1.$_");
				}
			}
		}
	}
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

