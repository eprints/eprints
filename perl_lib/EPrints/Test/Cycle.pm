######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::Test::Cycle;

=head1 NAME

EPrints::Test::Cycles - test for memory cycles

=head1 DESCRIPTION

Using this module will add various hooks around EPrints to check for memory cycles, that will cause memory leaks if not correctly cleaned up.

This will slow down EPrints considerably if used.

=head2 What to do if cycles are detected?

Memory cycles can be avoided by using L<Scalar::Util>::weaken.

=cut

use EPrints::Test;

use Devel::Cycle;

BEGIN
{
EPrints::Test::init( __PACKAGE__ );
}

sub EPrints::Session::DESTROY
{
	find_cycle( $_[0], \&report_object_cycle );
}

sub EPrints::MetaField::DESTROY
{
	find_cycle( $_[0], \&report_object_cycle );
}

sub EPrints::DataObj::DESTROY
{
	find_cycle( $_[0], \&report_object_cycle );
}

sub report_object_cycle
{
	my( $cycles ) = @_;

	my( $root, @edges ) = @$cycles;

	print STDERR "Cycle on ".ref($root->[2])." destruction:\n";

	&do_report( \@edges );
}

sub do_report
{
	my( $cycles ) = @_;

	for(@$cycles)
	{
		my( $type, $index, $ref, $value, $is_weak ) = @$_;
		print STDERR sprintf("\t%30s => %-30s\n",($is_weak ? 'w-> ' : '').Devel::Cycle::_format_reference($type,$index,$ref,0),Devel::Cycle::_format_reference(undef,undef,$value,1));
	}
}

1;
