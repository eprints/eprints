=head1 NAME

EPrints::Plugin::Issues::XMLConfig

=cut

package EPrints::Plugin::Issues::XMLConfig;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Issues" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Issues XML Config File";

	return $self;
}

sub config_file
{
	my( $plugin ) = @_;

	return $plugin->{session}->get_repository->get_conf( "config_path" )."/issues.xml";
}

sub get_config
{
	my( $plugin ) = @_;

	if( !defined $plugin->{issuesconfig} )
	{
		my $file = $plugin->config_file;
		my $doc = $plugin->{session}->get_repository->parse_xml( $file , 1 );
		if( !defined $doc )
		{
			$plugin->{session}->get_repository->log( "Error parsing $file\n" );
			return;
		}
	
		$plugin->{issuesconfig} = ($doc->getElementsByTagName( "issues" ))[0];
		if( !defined $plugin->{issuesconfig} )
		{
			$plugin->{session}->get_repository->log(  "Missing <issues> tag in $file\n" );
			EPrints::XML::dispose( $doc );
			return;
		}
	}
	
	return $plugin->{issuesconfig};
}

sub is_available
{
	my( $plugin ) = @_;

	return( -e $plugin->config_file );
}

# return an array of issues. Issues should be of the type
# { description=>XHTML String, type=>string }
# if one item can have multiple occurrences of the same issue type then add
# an id field too. This only need to be unique within the item.
sub item_issues
{
	my( $plugin, $dataobj ) = @_;
	
	my %params = ();
	$params{item} = $dataobj;
	$params{current_user} = $plugin->{session}->current_user;
	$params{session} = $plugin->{session};
	my $issues = EPrints::XML::EPC::process( $plugin->get_config, %params );

	my @issues_list = ();
	foreach my $child ( $issues->getChildNodes )
	{
		next unless( $child->nodeName eq "issue" );
		my $issue = {};
		$issue->{description} = EPrints::XML::contents_of( $child );
		$issue->{type} = $child->getAttribute( "type" );
		$issue->{id} = $child->getAttribute( "issue_id" );
		push @issues_list, $issue;
	}

	return @issues_list;
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

