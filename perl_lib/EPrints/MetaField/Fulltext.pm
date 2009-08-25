######################################################################
#
# EPrints::MetaField::Longtext;
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Fulltext> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Fulltext;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;

sub is_browsable
{
	return( 0 );
}

sub get_value
{
	my( $self, $object ) = @_;
	my @docs = $object->get_all_documents;
	my $r = [];
	foreach my $doc ( @docs )
	{
		push @{$r}, "_FULLTEXT_:".$doc->get_id;
	}
	return $r;
}

sub get_index_codes_basic
{
	my( $self, $handle, $value ) = @_;

	if( $value !~ s/^_FULLTEXT_:// )
	{
		return $self->SUPER::get_index_codes_basic( $handle, $value );
	}

	my $doc = $handle->get_document( $value );
	return( [], [], [] ) unless defined $doc->get_main;

	my $main_file = $doc->get_stored_file( $doc->get_main );
	return( [], [], [] ) unless defined $main_file;

	my( $indexcodes_doc ) = @{($doc->get_related_objects(
			EPrints::Utils::make_relation( "hasIndexCodesVersion" )
		))};
	my $indexcodes_file;
	if( defined $indexcodes_doc )
	{
		$indexcodes_file = $indexcodes_doc->get_stored_file( "indexcodes.txt" );
	}

	# (re)generate indexcodes if it doesn't exist or is out of date
	if( !defined( $indexcodes_doc ) ||
		$main_file->get_datestamp() gt $indexcodes_file->get_datestamp() )
	{
		$indexcodes_doc = $doc->make_indexcodes();
		if( defined( $indexcodes_doc ) )
		{
			$indexcodes_file = $indexcodes_doc->get_stored_file( "indexcodes.txt" );
		}
	}

	return( [], [], [] ) unless defined $indexcodes_doc;

	my $data = "";
	$indexcodes_file->get_file(sub {
		$data .= $_[0];
	});
	my @codes = split /\n/, $data;

	return( \@codes, [], [] );
}


######################################################################
1;
