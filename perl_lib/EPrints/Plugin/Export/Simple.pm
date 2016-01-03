=head1 NAME

EPrints::Plugin::Export::Simple

=cut

package EPrints::Plugin::Export::Simple;

use EPrints::Plugin::Export::TextFile;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Simple Metadata";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "all";

	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $r = "";
	foreach( @{$data} )
	{
		next unless defined( $_->[1] );
		$r.=$_->[0].": ".$_->[1]."\n";
	}
	$r.="\n";
	return $r;
}

sub dataobj_to_html_header
{
	my( $plugin, $dataobj ) = @_;

	my $links = $plugin->{session}->make_doc_fragment;

	my $epdata = $plugin->convert_dataobj( $dataobj );
	foreach( @{$epdata} )
	{
		next unless $_->[1];
		$links->appendChild( $plugin->{session}->make_element(
			"meta",
			name => "eprints.".$_->[0],
			content => $_->[1],
			%{ $_->[2] || {} } ) );
		$links->appendChild( $plugin->{session}->make_text( "\n" ));
	}
	return $links;
}

sub convert_dataobj
{
	my( $plugin, $eprint ) = @_;

	my @epdata = ();
	my $dataset = $eprint->get_dataset;

	foreach my $field ( $dataset->fields )
	{
		my $fieldname = $field->name;

		next if( !$field->property( 'export_as_xml' ) ); 

		# export "creators_name" but not "creators"
		next if( $field->is_virtual && !$field->isa( "EPrints::MetaField::Multilang" ) ); 
	
		# export "title" but not "title_text"
		next if( UNIVERSAL::isa( $field->property('parent'), 'EPrints::MetaField::Multilang' ) );
	
		next unless $eprint->is_set( $fieldname );
		my $field = $dataset->get_field( $fieldname );
		my $value = $eprint->get_value( $fieldname );

		if( $field->isa( "EPrints::MetaField::Multilang" ) )
		{
			my( $values, $langs ) =
				map { $_->get_value( $eprint ) }
				@{$field->property( "fields_cache" )};

			$values = [$values] if ref($values) ne "ARRAY";
			$langs = [$langs] if ref($values) ne "ARRAY";
			foreach my $i (0..$#$values)
			{
				push @epdata, [ $fieldname, $values->[$i], { 'xml:lang' => $langs->[$i] } ];
			}
		}
		elsif( $field->get_property( "multiple" ) )
		{
			foreach my $item ( @{$value} )
			{
				if( $field->is_type( "name" ) )
				{
					push @epdata, [ $fieldname, ($item->{family}||"").", ".($item->{given}||"") ];
				}
				else
				{
					push @epdata, [ $fieldname, $item ];
				}
			}
		}
		else
		{
			push @epdata, [ $fieldname, $value ];
		}
	}

	# The citation for this eprint
	push @epdata, [ "citation",
		EPrints::Utils::tree_to_utf8( $eprint->render_citation() ) ];

	foreach my $doc ( $eprint->get_all_documents )
	{
		push @epdata, [ "document_url", $doc->get_url() ];
	}

	return \@epdata;
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

