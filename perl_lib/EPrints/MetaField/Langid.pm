######################################################################
#
# EPrints::MetaField::Langid;
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

B<EPrints::MetaField::Langid> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Langid;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Set );
}

use EPrints::MetaField::Set;


sub get_sql_type
{
	my( $self, $session ) = @_;

	return $session->get_database->get_column_type(
		$self->get_sql_name(),
		EPrints::Database::SQL_VARCHAR,
		!$self->get_property( "allow_null" ),
		16,
		undef,
		$self->get_sql_properties,
	);
}


sub render_option
{
	my( $self, $session, $option ) = @_;

	$option = "" if !defined $option;

	my $phrasename = "languages_typename_".$option;

	# if the option is empty, and no explicit phrase is defined, print 
	# UNDEFINED rather than an error phrase.
	if( $option eq "" && !$session->get_lang->has_phrase( $phrasename, $session ) )
	{
		$phrasename = "lib/metafield:unspecified";
	}

	return $session->html_phrase( $phrasename );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_style} = "short";
	return %defaults;
}

######################################################################
1;
