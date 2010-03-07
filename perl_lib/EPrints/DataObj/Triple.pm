######################################################################
#
# EPrints::DataObj::Triple
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2010 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=head1 NAME

B<EPrints::DataObj::Triple> - RDF Triple

=head1 DESCRIPTION

Inherits from L<EPrints::DataObj>.

=head1 CORE FIELDS

=over 4

=item tripleid

Unique id for the triple.

=item primary_resource

The local URI of the EPrint that this data comes from.

=item secondary_resource

The URI of the other resource, if any, this data belongs to. Eg. the x-event 

=item subject, predicate, object, type, lang

The parts of the triple.

=back

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::Triple;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;

=item $thing = EPrints::DataObj::Triple->get_system_field_info

Core fields contained in a Web access.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"tripleid", type=>"counter", required=>1, can_clone=>0,
			sql_counter=>"tripleid" },

		{ name=>"primary_resource", type=>"text", required=>1, text_index=>0, sql_index=>1 },
		{ name=>"secondary_resource", type=>"text", required=>0, text_index=>0, sql_index=>1 },

		{ name=>"subject",   type=>"longtext", required=>1, text_index=>0, },
		{ name=>"predicate", type=>"longtext", required=>1, text_index=>0, },
		{ name=>"object",    type=>"longtext", required=>1, text_index=>0, },
		{ name=>"type",      type=>"longtext", required=>1, text_index=>0, },
		{ name=>"lang",      type=>"longtext", required=>1, text_index=>0, },
	);
}

######################################################################

=back

=head2 Class Methods

=over 4

=cut

######################################################################

######################################################################
=pod

=item $dataset = EPrints::DataObj::Triple->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "triple";
}

######################################################################

=head2 Object Methods

=cut

######################################################################

=item $dataobj->get_referent_id()

Return the fully qualified referent id.

=cut


1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut

