######################################################################
#
# EPrints::MetaField::Subject;
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

sub render_single_value
{
	my( $self, $session, $value ) = @_;

	my $subject = new EPrints::DataObj::Subject( $session, $value );
	if( !defined $subject )
	{
		return $session->make_text( "?? $value ??" );
	}

	return $subject->render_with_path(
		$session,
		$self->get_property( "top" ) );
}

sub render_option
{
	my( $self, $session, $option ) = @_;

	if( defined $self->get_property("render_option") )
	{
		return $self->call_property( "render_option", $session, $option );
	}

	if( !defined $option )
	{
		return $self->SUPER::render_option( $session, $option );
	}

	my $subject = new EPrints::DataObj::Subject( $session, $option );

	return $subject->render_description;
}

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

sub render_set_input
{
	my( $self, $session, $default, $required, $obj, $basename ) = @_;


	my $topsubj = $self->get_top_subject( $session );

	my ( $pairs ) = $topsubj->get_subjects( 
		!($self->{showall}), 
		$self->{showtop},
		0,
		($self->{input_style} eq "short"?1:0) );

	if( !$self->get_property( "multiple" ) && 
		!$required )
	{
		# If it's not multiple and not required there 
		# must be a way to unselect it.
		my $unspec = $session->phrase( 
			"lib/metafield:unspecified_selection" ) ;
		$pairs = [ [ "", $unspec ], @{$pairs} ];
	}

	return $session->render_option_list(
		pairs => $pairs,
		defaults_at_top => 1,
		name => $basename,
		id => $basename,
		default => $default,
		multiple => $self->{multiple},
		height => $self->{input_rows}  );

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

sub get_value_label
{
	my( $self, $session, $value ) = @_;

	my $subj = EPrints::DataObj::Subject->new( $session, $value );
	if( !defined $subj )
	{
		return $session->make_text( 
			"?? Bad Subject: ".$value." ??" );
	}
	return $subj->render_description();
}

sub render_search_set_input
{
	my( $self, $session, $searchfield ) = @_;

	my $prefix = $searchfield->get_form_prefix;
	my $value = $searchfield->get_value;
	
	my $topsubj = $self->get_top_subject( $session );

	my( $subjectmap, $rmap ) = EPrints::DataObj::Subject::get_all( $session );

	my $pairs = traverse_subjects( $topsubj, 1,$subjectmap, $rmap, "");

	my $max_rows =  $self->get_property( "search_rows" );

	#splice( @{$pairs}, 0, 0, [ "NONE", "(Any)" ] ); #cjg

	my $height = scalar @$pairs;
	$height = $max_rows if( $height > $max_rows );

	my @defaults = ();
	# Do we have any values already?
	if( defined $value && $value ne "" )
	{
		@defaults = split /\s/, $value;
	}

	return $session->render_option_list( 
		name => $prefix,
		defaults_at_top => 1,
		default => \@defaults,
		multiple => 1,
		pairs => $pairs,
		height => $height );
}	

sub traverse_subjects
{
	my( $subject, $hidenode, $subjectmap, $rmap, $prefix) = @_; 
	
	my $id = $subject->get_value( "subjectid" );

	my $desc = $subject->render_description;
	my $label = EPrints::Utils::tree_to_utf8( $desc );
	EPrints::XML::dispose( $desc );

	my $subpairs = [];
	unless( $hidenode )
	{
		push @{$subpairs},[ $id,$prefix.$label ];
		$prefix .= "....";
	}
	$prefix = "" if( $hidenode );
	foreach my $kid ( @{$rmap->{$id}} )
	{
		my $kidmap = traverse_subjects( $kid,0, $subjectmap, $rmap, $prefix );
		push @{$subpairs}, @{$kidmap};
	}

	return $subpairs;
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
	$defaults{input_style} = 0;
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
