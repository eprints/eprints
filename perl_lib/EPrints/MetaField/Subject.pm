######################################################################
#
# EPrints::MetaField::Subject;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Subject> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

# top

package EPrints::MetaField::Subject;

use strict;
use warnings;

BEGIN
{
	our( @ISA );
	
	@ISA = qw( EPrints::MetaField::Set );
}

use EPrints::MetaField::Set;

######################################################################
=pod

=item $subject = $field->get_top_subject( $session )

Return the top EPrints::DataObj::Subject object for this field. Only meaningful
for "subject" type fields.

=cut
######################################################################

sub get_top_subject
{
	my( $self, $session ) = @_;

	my $topid = $self->get_property( "top" );
	if( !defined $topid )
	{
		$session->render_error( $session->make_text( 
			'Subject field name "'.$self->get_name().'" has '.
			'no "top" property.' ) );
		exit;
	}
		
	my $topsubject = EPrints::DataObj::Subject->new( $session, $topid );

	if( !defined $topsubject )
	{
		$session->render_error( $session->make_text( 
			'The top level subject (id='.$topid.') for field '.
			'"'.$self->get_name().'" does not exist. The '.
			'site admin probably has not run import_subjects. '.
			'See the documentation for more information.' ) );
		exit;
	}
	
	return $topsubject;
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my $topsubj = $self->get_top_subject( $session );
	my ( $pairs ) = $topsubj->get_subjects( 
		0 , 
		!$opts{hidetoplevel} , 
		$opts{nestids} );
	my $pair;
	my $v = [];
	foreach $pair ( @{$pairs} )
	{
		push @{$v}, $pair->[0];
	}
	return $v;
}

sub ordervalue_basic
{
        my( $self , $value , $session , $langid ) = @_;

        return "" unless( EPrints::Utils::is_set( $value ) );

	return $self->get_value_label_as_string( $session, $value, $langid );
}

# sf2 added method - awful name and function :)
sub get_value_label_as_string
{
	my( $self, $session, $value, $langid ) = @_;

	my $subj = $session->dataset( 'subject' )->dataobj( $value );
	if( !defined $subj )
	{
		return "[Error] Invalid subject code: ".$value;
	}
return $value;
	my $name = $subj->dataset->field( 'name' );
	return $name->lang_value( $langid, [$value] );
}

sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	return EPrints::Search::Condition->new( 
		'in_subject', 
		$dataset,
		$self, 
		$search_value );
}

sub get_search_group { return 'subject'; }

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{showall} = 0;
	$defaults{showtop} = 0;
	$defaults{nestids} = 1;
	$defaults{top} = "subjects";
	delete $defaults{options}; # inherrited but unwanted
	return %defaults;
}

sub get_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my $topsubj = $self->get_top_subject( $session );
	my ( $pairs ) = $topsubj->get_subjects(
		0,
		1,
		0 );
	my @outvalues;
	my $seen = {};
	foreach my $pair ( @{$pairs} )
	{
		next if( $seen->{$pair->[0]} );
		push @outvalues, $pair->[0];
		$seen->{$pair->[0]} = 1;
	}
	return \@outvalues;
}

sub tags
{
	my( $self, $session ) = @_;

	return @{$self->get_values( $session )};
}

######################################################################
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

