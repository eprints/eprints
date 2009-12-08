######################################################################
#
# EPrints::DataObj::Import::XML
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::DataObj::Import::XML;

# This is a utility module for importing existing eprints from an XML file

use EPrints;

use strict;

use EPrints::Plugin::Import::XML;

our @ISA = qw( EPrints::Plugin::Import::XML );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{import} = $params{import};
	$self->{id} = "Import::XML"; # hack to make phrases work

	return $self;
}

sub epdata_to_dataobj
{
	my( $self, $dataset, $epdata ) = @_;

	my $dataobj = $self->{import}->epdata_to_dataobj( $dataset, $epdata );

	$self->handler->parsed( $epdata ); # TODO: parse-only import?
	$self->handler->object( $dataset, $dataobj );

	return $dataobj;
}

# suppress warnings, in particular that various imported fields don't exist
# in our repository
sub warning {}

1;

__END__

