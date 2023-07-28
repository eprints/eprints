=head1 NAME

EPrints::Plugin::Export::XML

=cut

package EPrints::Plugin::Export::XML;

use EPrints::Plugin::Export::XMLFile;

@ISA = ( "EPrints::Plugin::Export::XMLFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "EP3 XML";
	$self->{accept} = [ 'list/*', 'dataobj/*' ];
	$self->{visible} = "all";
	$self->{xmlns} = EPrints::Const::EP_NS_DATA;
	$self->{qs} = 0.8;
	$self->{mimetype} = 'application/vnd.eprints.data+xml; charset=utf-8';
	$self->{arguments}->{hide_volatile} = 1;

	return $self;
}

sub output_list
{
	my( $self, %opts ) = @_;

	my $type = $opts{list}->get_dataset->confid;
	my $toplevel = $type."s";
	
	my $output = "";

	my $wr = EPrints::XML::SAX::PrettyPrint->new(
		Handler => EPrints::XML::SAX::Writer->new(
			Output => defined $opts{fh} ? $opts{fh} : \$output
	));

	$wr->start_document({});
	if( !$opts{omit_declaration} )
	{
		$wr->xml_decl({
			Version => '1.0',
			Encoding => 'utf-8',
		});
	}
	$wr->start_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});

	if( !$opts{omit_root} )
	{
		$wr->start_element({
			Prefix => '',
			LocalName => $toplevel,
			Name => $toplevel,
			NamespaceURI => EPrints::Const::EP_NS_DATA,
			Attributes => {},
		});
	}
	$opts{list}->map( sub {
		my( undef, undef, $item ) = @_;

		$self->output_dataobj( $item, %opts, Handler => $wr );
	});

	if( !$opts{omit_root} )
	{
		$wr->end_element({
			Prefix => '',
			LocalName => $toplevel,
			Name => $toplevel,
			NamespaceURI => EPrints::Const::EP_NS_DATA,
		});
	}
	$wr->end_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	$wr->end_document({});

	return $output;
}

sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	$opts{hide_volatile} //= 1;

	if( $opts{Handler} )
	{
		return $dataobj->to_sax( %opts );
	}

	my $output = "";

	my $type = $dataobj->get_dataset->base_id;
	my $toplevel = $type."s";
	
	my $wr = EPrints::XML::SAX::PrettyPrint->new(
		Handler => EPrints::XML::SAX::Writer->new(
			Output => defined $opts{fh} ? $opts{fh} : \$output
	));


	$wr->start_document({});
	if( !$opts{omit_declaration} )
	{
		$wr->xml_decl({
			Version => '1.0',
			Encoding => 'utf-8',
		});
	}
	$wr->start_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	if( !$opts{omit_root} )
	{
		$wr->start_element({
			Prefix => '',
			LocalName => $toplevel,
			Name => $toplevel,
			NamespaceURI => EPrints::Const::EP_NS_DATA,
			Attributes => {},
		});
	}
	$dataobj->to_sax( %opts, Handler => $wr );
	if( !$opts{omit_root} )
	{
		$wr->end_element({
			Prefix => '',
			LocalName => $toplevel,
			Name => $toplevel,
			NamespaceURI => EPrints::Const::EP_NS_DATA,
		});
	}
	$wr->end_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	$wr->end_document({});

	return $output;
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

