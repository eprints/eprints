=head1 NAME

EPrints::Plugin::Export::OldXML

=cut

package EPrints::Plugin::Export::OldXML;

# eprint needs magic documents field

# documents needs magic files field

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "XML (eprints 2.3 style)";
	$self->{accept} = [ 'list/*', 'dataobj/*' ];
	$self->{visible} = "";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";

	return $self;
}





sub output_list
{
	my( $plugin, %opts ) = @_;

	my $type = $opts{list}->get_dataset->confid;
	my $toplevel = $type."s";

	my $r = [];

	my $part;
	$part = '<?xml version="1.0" encoding="utf-8" ?><eprintsdata xmlns="http://eprints.org/ep2/data">'."\n";
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}

	$opts{list}->map( sub {
		my( $session, $dataset, $item ) = @_;

		my $part = $plugin->output_dataobj( $item, %opts );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	} );

	$part= "</eprintsdata>\n";
	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}


	if( defined $opts{fh} )
	{
		return;
	}

	return join( '', @{$r} );
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $itemtype = $dataobj->get_dataset->confid;

	my $xml = $plugin->xml_dataobj( $dataobj );

	EPrints::XML::tidy( $xml, {}, 1 );

	return "  " . EPrints::XML::to_string( $xml ) . "\n";
}

sub xml_dataobj
{
	my( $plugin, $dataobj ) = @_;

	return $dataobj->to_xml( version=>1, no_xmlns=>1 );
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

