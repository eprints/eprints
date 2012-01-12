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
	$self->{accept} = [qw( dataobj/eprint )];

	return $self;
}

sub config_file
{
	my( $self ) = @_;

	return $self->{session}->config( "config_path" )."/issues.xml";
}

sub get_config
{
	my( $self ) = @_;

	if( !defined $self->{issuesconfig} )
	{
		my $file = $self->config_file;
		my $doc = $self->{session}->parse_xml( $file , 1 );
		if( !defined $doc )
		{
			$self->{session}->log( "Error parsing $file\n" );
			return;
		}
	
		$self->{issuesconfig} = ($doc->getElementsByTagName( "issues" ))[0];
		if( !defined $self->{issuesconfig} )
		{
			$self->{session}->log(  "Missing <issues> tag in $file\n" );
			EPrints::XML::dispose( $doc );
			return;
		}
	}
	
	return $self->{issuesconfig};
}

sub process_dataobj
{
	my( $self, $dataobj, %opts ) = @_;
	
	my $issues = EPrints::XML::EPC::process( $self->get_config,
			item => $dataobj,
			current_user => $self->{session}->current_user,
			session => $self->{session},
		);

	foreach my $child ( $issues->childNodes )
	{
		next unless( $child->nodeName eq "issue" );
		my $desc = EPrints::XML::contents_of( $child );
		$desc = $self->{session}->xhtml->to_xhtml( $desc );
		$self->create_issue( $dataobj, {
				type => $self->get_subtype . ":" . $child->getAttribute( "type" ),
				description => $desc,
			}, %opts);
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

