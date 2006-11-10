######################################################################
#
# EPrints::MetaField::Pagerange;
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

B<EPrints::MetaField::Pagerange> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Pagerange;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Int );
}

use EPrints::MetaField::Text;

sub get_sql_type
{
	my( $self, $notnull ) = @_;

	return $self->get_sql_name()." INTEGER".($notnull?" NOT NULL":"");
}

sub get_max_input_size
{
	my( $self ) = @_;

	return $EPrints::MetaField::VARCHAR_SIZE;
}

# note that this renders pages ranges differently from
# eprints 2.2
sub render_single_value
{
	my( $self, $session, $value ) = @_;

	unless( $value =~ m/^(\d+)-(\d+)$/ )
	{
		# value not in expected form. Ah, well. Muddle through.
		return $session->make_text( $value );
	}

	my( $a, $b ) = ( $1, $2 );

	# possibly there could be a non-breaking space after p.?

	if( $a == $b )
	{
		my $frag = $session->make_doc_fragment();
		$frag->appendChild( $session->make_text( "p." ) );
		$frag->appendChild( $session->render_nbsp );
		$frag->appendChild( $session->make_text( $a ) );
	}

#	consider compressing pageranges so that
#	207-209 is rendered as 207-9
#
#       if( length $a == length $b )
#       {
#       }

	my $frag = $session->make_doc_fragment();
	$frag->appendChild( $session->make_text( "pp." ) );
	$frag->appendChild( $session->render_nbsp );
	$frag->appendChild( $session->make_text( $a.'-'.$b ) );

	return $frag;
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	my @pages = split /-/, $value if( defined $value );
 	my $fromid = $basename."_from";
 	my $toid = $basename."_to";
		
	my $frag = $session->make_doc_fragment;

	$frag->appendChild( $session->render_noenter_input_field(
		class => "ep_form_text",
		name => $fromid,
		id => $fromid,
		value => $pages[0],
		size => 6,
		maxlength => 120 ) );

	$frag->appendChild( $session->make_text(" ") );
	$frag->appendChild( $session->html_phrase( 
		"lib/metafield:to" ) );
	$frag->appendChild( $session->make_text(" ") );

	$frag->appendChild( $session->render_noenter_input_field(
		class => "ep_form_text",
		name => $toid,
		id => $toid,
		value => $pages[1],
		size => 6,
		maxlength => 120 ) );

	return [ [ { el=>$frag } ] ];
}

sub get_basic_input_ids
{
	my( $self, $session, $basename, $staff, $obj ) = @_;

	return( $basename."_from", $basename."_to" );
}

sub is_browsable
{
	return( 1 );
}

sub form_value_basic
{
	my( $self, $session, $basename ) = @_;
	
	my $from = $session->param( $basename."_from" );
	my $to = $session->param( $basename."_to" );

	if( !defined $to || $to eq "" )
	{
		return( $from );
	}
		
	return( $from . "-" . $to );
}


######################################################################
1;
