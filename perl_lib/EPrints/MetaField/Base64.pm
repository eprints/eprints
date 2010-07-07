######################################################################
#
# EPrints::MetaField::Base64;
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

B<EPrints::MetaField::Base64> - Base 64 encoded data

=head1 DESCRIPTION

=over 4

=cut

package EPrints::MetaField::Base64;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Longtext );
}

use EPrints::MetaField::Longtext;

sub to_sax
{
	my( $self, $value, %opts ) = @_;

	# MetaField::Compound relies on testing this specific attribute
	return if defined $self->{parent_name};

	return if !$opts{show_empty} && !EPrints::Utils::is_set( $value );

	my $handler = $opts{Handler};
	my $name = $self->name;

	my $enc_attr = {
		Prefix => '',
		LocalName => 'encoding',
		Name => 'encoding',
		NamespaceURI => '',
		Value => 'base64',
	};

	if( ref($value) eq "ARRAY" )
	{
		$handler->start_element( {
			Prefix => '',
			LocalName => $name,
			Name => $name,
			NamespaceURI => EPrints::Const::EP_NS_DATA,
			Attributes => {},
		});

		foreach my $v (@$value)
		{
			$handler->start_element( {
				Prefix => '',
				LocalName => "item",
				Name => "item",
				NamespaceURI => EPrints::Const::EP_NS_DATA,
				Attributes => {
					'{}encoding' => $enc_attr,
				},
			});
			$self->to_sax_basic( $v, %opts );
			$handler->end_element( {
				Prefix => '',
				LocalName => "item",
				Name => "item",
				NamespaceURI => EPrints::Const::EP_NS_DATA,
			});
		}
	}
	else
	{
		$handler->start_element( {
			Prefix => '',
			LocalName => $name,
			Name => $name,
			NamespaceURI => EPrints::Const::EP_NS_DATA,
			Attributes => {
				'{}encoding' => $enc_attr,
			},
		});

		$self->to_sax_basic( $value, %opts );
	}

	$handler->end_element( {
		Prefix => '',
		LocalName => $name,
		Name => $name,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
}

######################################################################
1;
