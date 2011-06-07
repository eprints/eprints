######################################################################
#
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

