=head1 NAME

EPrints::Apache::Conf

=cut

package EPrints::Apache::Conf;

=item $conf = EPrints::Apache::Conf::generate( $repo )

Generate and return the <VirtualHost> declaration for this repository.

=cut

sub generate
{
	my( $repo ) = @_;

	my $id = $repo->get_id;
	my $adminemail = $repo->config( "adminemail" );
	my $host = $repo->config( "host" );
	my $port = $repo->config( "port" );
	$port = 80 if !defined $port;
	my $hostport = $host;
	if( $port != 80 ) { $hostport.=":$port"; }
	my $http_root = $repo->config( "http_root" );
	my $virtualhost = $repo->config( "virtualhost" );
	$virtualhost = "*" if !EPrints::Utils::is_set( $virtualhost );

	my $conf = <<EOC;
#
# apache.conf include file for $id
#
# Any changes made here will be lost if you run generate_apacheconf
# with the --replace option
#
EOC

	my $aliasinfo;
	my $aliases = "";
	foreach $aliasinfo ( @{$repo->config( "aliases" ) || []} )
	{
		if( $aliasinfo->{redirect} )
		{
			my $vname = $aliasinfo->{name};
			$conf .= <<EOC;

# Redirect to the correct hostname
<VirtualHost $virtualhost:$port>
  ServerName $vname
  Redirect / http://$hostport/
</VirtualHost>
EOC
		}
		else
		{
			$aliases.="  ServerAlias ".$aliasinfo->{name}."\n";
		}
	}

		$conf .= <<EOC;

# The main virtual host for this repository
<VirtualHost $virtualhost:$port>
  ServerName $host
$aliases
  ServerAdmin $adminemail

  <Location "$http_root">
    PerlSetVar EPrints_ArchiveID $id

    Options +ExecCGI
    Order allow,deny
    Allow from all
  </Location>

EOC

	# backwards compatibility
	my $apachevhost = $repo->config( "config_path" )."/apachevhost.conf";
	if( -e $apachevhost )
	{
		$conf .= "  # Include any legacy directives\n";
		$conf .= "  Include $apachevhost\n\n";
	}

	$conf .= <<EOC;

  # Note that PerlTransHandler can't go inside
  # a "Location" block as it occurs before the
  # Location is known.
  PerlTransHandler +EPrints::Apache::Handler
  
</VirtualHost>

EOC

	return $conf;
}

sub generate_secure
{
	my( $repo ) = @_;

	my $id = $repo->get_id;
	my $https_root = $repo->config( "https_root" );

	return <<EOC
#
# secure.conf include file for $id
#
# Any changes made here will be lost if you run generate_apacheconf
# with the --replace option
#

  <Location "$https_root">
    PerlSetVar EPrints_ArchiveID $id
    PerlSetVar EPrints_Secure yes

    Options +ExecCGI
    Order allow,deny 
    Allow from all
  </Location>
EOC
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

