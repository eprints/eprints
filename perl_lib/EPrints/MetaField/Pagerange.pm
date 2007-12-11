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

	return $self->get_sql_name()." VARCHAR($EPrints::MetaField::VARCHAR_SIZE)".($notnull?" NOT NULL":"");
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

	my $frag = $session->make_doc_fragment;

	# If there are leading zeros it's probably electronic (so 'other')
	if( $value =~ /^([1-9]\d*)$/ )
	{
		$frag->appendChild( $session->html_phrase( "lib/metafield/pagerange:from_page",
			from => $session->make_text( $1 ),
			pagerange => $session->make_text( $value ),
		));
	}
	elsif( $value =~ m/^([1-9]\d*)-(\d+)$/ )
	{
		if( $1 == $2 )
		{
			$frag->appendChild( $session->html_phrase( "lib/metafield/pagerange:same_page",
				from => $session->make_text( $1 ),
				to => $session->make_text( $2 ),
				pagerange => $session->make_text( $value ),
			));
		}
		else
		{
			$frag->appendChild( $session->html_phrase( "lib/metafield/pagerange:range",
				from => $session->make_text( $1 ),
				to => $session->make_text( $2 ),
				pagerange => $session->make_text( $value ),
			));
		}
	}
	else
	{
		$frag->appendChild( $session->html_phrase( "lib/metafield/pagerange:other",
			pagerange => $session->make_text( $value )
		));
	}

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

sub ordervalue_basic
{
	my( $self , $value ) = @_;

	unless( EPrints::Utils::is_set( $value ) )
	{
		return "";
	}

	my( $from, $to ) = split /-/, $value;

	$to = $from unless defined $to;

	# remove non digits
	$from =~ s/[^0-9]//g;
	$to =~ s/[^0-9]//g;

	# set to zero if undef
	$from = 0 if $from eq "";
	$to = 0 if $to eq "";

	return sprintf( "%08d-%08d", $from, $to );
}


######################################################################
1;
